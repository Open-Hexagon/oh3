local packet_handler = require("server.packet_handler")
local packet_types = require("server.packet_types")
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
    local protocol_version, game_version_major, game_version_minor, game_version_micro, packet_type, offset = love.data.unpack(">BBBBB", data, 3)
    if data:sub(1, 2) ~= "oh" then
        return "wrong preamble bytes"
    end
    if protocol_version ~= version.PROTOCOL_VERSION then
        return "wrong protocol version"
    end
    if game_version_major ~= version.GAME_VERSION[1] then
        return "wrong game major version"
    end
    if not game_version_minor then
        return "no minor version"
    end
    if not game_version_micro then
        return "no micro version"
    end
    local str_packet_type = packet_types.client_to_server[packet_type]
    if not str_packet_type then
        return "invalid packet type: " .. packet_type
    end
    packet_handler.process(str_packet_type, data:sub(offset, -1), client)
end

local server = create_server("0.0.0.0", 50505, function(client)
    local client_details = client:getpeername()
    local name = client_details.ip .. ":" .. client_details.port
    local pending_packet_size
    local data = ""
    local client_data = {
        send_packet = function(packet_type, contents)
            contents = contents or ""
            local type_num
            for i = 1, #packet_types.server_to_client do
                if packet_types.server_to_client[i] == packet_type then
                    type_num = i
                    break
                end
            end
            if not type_num then
                print("Attempted to send packet with invalid type: " .. packet_type)
            else
                contents = "oh" .. love.data.pack(
                    "string",
                    ">BBBBB",
                    version.PROTOCOL_VERSION,
                    version.GAME_VERSION[1],
                    version.GAME_VERSION[2],
                    version.GAME_VERSION[3],
                    type_num
                ) .. contents
                local packet = love.data.pack("string", ">I4", #contents) .. contents
                client:write(packet)
            end
        end
    }
    print("Connection from " .. name)
    client:read_start(function(err, chunk)
        if err then
            print("Closing connection from " .. name .. " due to error: ", err)
            client:close()
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
                            print("Closing connection to " .. name .. ". Reason: " .. err)
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
            print("Client from " .. name .. " disconnected")
            client:close()
        end
    end)
end)

print("TCP server listening on port " .. server:getsockname().port)

local signal = uv.new_signal()
signal:start("sigint", function(sig)
    print("got " .. sig .. ", shutting down")
    packet_handler.stop_game()
    database.stop()
    os.exit(1)
end)

database.init()
packet_handler.init(database)
uv.run()
