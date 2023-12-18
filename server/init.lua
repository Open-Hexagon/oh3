local log_name, is_thread, start_web = ...
start_web = start_web or require("args").web
local log = require("log")(log_name)
local packet_handler21 = require("compat.game21.server.packet_handler")
local packet_types21 = require("compat.game21.server.packet_types")
local database = require("server.database")
local version = require("server.version")
local uv = require("luv")

database.set_identity(0)

local function create_server(host, port, on_connection)
    local server = uv.new_tcp()
    server:bind(host, port)

    server:listen(128, function(err)
        -- Make sure there was no problem setting up listen
        assert(not err, err)

        -- Accept the client
        local client = uv.new_tcp()
        server:accept(client)

        on_connection(client)
    end)

    return server
end

local function process_packet(data, client)
    if #data < 7 then
        return "packet shorter than header"
    end
    local protocol_version, game_version_major, game_version_minor, game_version_micro, packet_type, offset =
        love.data.unpack(">BBBBB", data, 3)
    if data:sub(1, 2) ~= "oh" then
        return "wrong preamble bytes"
    end
    if protocol_version ~= version.COMPAT_PROTOCOL_VERSION and protocol_version ~= version.PROTOCOL_VERSION then
        return "wrong protocol version"
    end
    if game_version_major ~= version.COMPAT_GAME_VERSION[1] and game_version_major ~= version.GAME_VERSION[1] then
        return "wrong game major version"
    end
    if not game_version_minor then
        return "no minor version"
    end
    if not game_version_micro then
        return "no micro version"
    end
    if protocol_version == version.COMPAT_PROTOCOL_VERSION then
        local str_packet_type = packet_types21.client_to_server[packet_type]
        if not str_packet_type then
            return "invalid packet type: " .. packet_type
        end
        packet_handler21.process(str_packet_type, data:sub(offset, -1), client)
    elseif protocol_version == version.PROTOCOL_VERSION then
        -- TODO: new protocol
    end
end

create_server("0.0.0.0", 50505, function(client)
    local client_details = client:getpeername()
    local name = client_details.ip .. ":" .. client_details.port
    local pending_packet_size
    local data = ""
    local client_data = {
        send_packet21 = function(packet_type, contents)
            contents = contents or ""
            local type_num
            for i = 1, #packet_types21.server_to_client do
                if packet_types21.server_to_client[i] == packet_type then
                    type_num = i
                    break
                end
            end
            if not type_num then
                log("Attempted to send packet with invalid type: '" .. packet_type .. "'")
            else
                contents = "oh"
                    .. love.data.pack(
                        "string",
                        ">BBBBB",
                        version.COMPAT_PROTOCOL_VERSION,
                        version.COMPAT_GAME_VERSION[1],
                        version.COMPAT_GAME_VERSION[2],
                        version.COMPAT_GAME_VERSION[3],
                        type_num
                    )
                    .. contents
                local packet = love.data.pack("string", ">I4", #contents) .. contents
                client:write(packet)
            end
        end,
    }
    log("Connection from " .. name)
    client:read_start(function(err, chunk)
        if err then
            log("Closing connection from " .. name .. " due to error: ", err)
            client:close()
            return
        end

        if chunk then
            data = data .. chunk
            local reading = true
            while reading do
                reading = false
                if pending_packet_size then
                    if #data >= pending_packet_size then
                        reading = true
                        err = process_packet(data:sub(1, pending_packet_size), client_data)
                        if err then
                            -- client sends wrong packets (e.g. wrong protocol version)
                            client:close()
                            log("Closing connection to " .. name .. ". Reason: " .. err)
                            return
                        end
                        data = data:sub(pending_packet_size + 1)
                        pending_packet_size = nil
                    end
                elseif #data >= 4 then
                    reading = true
                    pending_packet_size = love.data.unpack(">I4", data)
                    data = data:sub(5)
                end
            end
        else
            log("Client from " .. name .. " disconnected")
            client:close()
        end
    end)
end)

log("listening")

local web_thread
if start_web then
    web_thread = love.thread.newThread("server/web_api.lua")
end

local signal = uv.new_signal()
signal:start("sigint", function(sig)
    log("got " .. sig .. ", shutting down")
    log("waiting for game to stop...")
    packet_handler21.stop_game()
    log("waiting for database to stop...")
    database.stop()
    if start_web and not web_thread:isRunning() then
        log("Error in web thread: " .. web_thread:getError())
    end
    os.exit(1)
end)

database.init()
packet_handler21.init(database, is_thread)
if start_web then
    web_thread:start()
end
uv.run()
