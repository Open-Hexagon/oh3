local log_name, is_thread, start_web = ...
start_web = start_web or require("args").web
local log = require("log")(log_name)
local packet_handler21 = require("compat.game21.server.packet_handler")
local packet_types21 = require("compat.game21.server.packet_types")
local database = require("server.database")
local version = require("server.version")
local socket = require("socket")

database.set_identity(0)

local function run_server(host, port, on_connection)
    local server = assert(socket.bind(host, port))
    assert(server:settimeout(0, "b"))
    log("listening on", server:getsockname())

    local coroutines = {}
    while true do
        local client = server:accept()
        if client then
            assert(client:setoption("keepalive", true))
            assert(client:settimeout(0, "b"))
            local new_coroutine = coroutine.create(on_connection)
            local index = #coroutines + 1
            coroutines[index] = new_coroutine
            coroutine.resume(new_coroutine, client, server)
        end
        for i = #coroutines, 1, -1 do
            if coroutine.status(coroutines[i]) == "dead" then
                table.remove(coroutines, i)
            else
                coroutine.resume(coroutines[i])
            end
        end
    end
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

local web_thread
if start_web then
    web_thread = love.thread.newThread("server/web_api.lua")
end

database.init()
packet_handler21.init(database, is_thread)
if start_web then
    web_thread:start()
end

local ffi = require("ffi")

ffi.cdef([[
typedef void (*__sighandler_t) (int);
__sighandler_t signal (int __sig, __sighandler_t __handler);
]])

local function handler()
    ffi.C.signal(2, handler)
    log("got interrupt while running server, shutting down")
    log("waiting for game to stop...")
    packet_handler21.stop_game()
    log("waiting for database to stop...")
    database.stop()
    if start_web and not web_thread:isRunning() then
        log("Error in web thread: " .. web_thread:getError())
    end
    os.exit(1)
end
ffi.C.signal(2, handler)

run_server("0.0.0.0", 50505, function(client)
    local client_ip, client_port = client:getpeername()
    local name = client_ip .. ":" .. client_port
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
                local writing = true
                local i = 1
                local timeout_count = 0
                while writing do
                    local written, reason, failed_at = client:send(packet:sub(i))
                    if written then
                        writing = false
                    elseif reason == "wantwrite" then
                    elseif reason == "timeout" then
                        timeout_count = timeout_count + 1
                        if timeout_count > 10000000 then
                            log("Failed sending packet with type '" .. packet_type .. "' to " .. name .. " due to timeout")
                            writing = false
                        end
                    else
                        log("Failed sending packet with type '" .. packet_type .. "' to " .. name)
                        writing = false
                    end
                    if writing then
                        i = i + failed_at
                        coroutine.yield()
                    end
                end
            end
        end,
    }
    log("Connection from " .. name)
    local connected = true
    while connected do
        local chunk, reason = client:receive(1)
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
        end
        if reason == "closed" then
            log("Client " .. name .. " disconnected")
            client:close()
            return
        end
        coroutine.yield()
    end
end)
