local packet_types = require("server.packet_types")
local sodium = require("luasodium")

local packet_handler = {}
local server_pk, server_sk = sodium.crypto_kx_keypair()

local function sodium_key_to_string(key)
    local offset = 1
    local string_key = ""
    for _ = 1, #key do
        local part
        part, offset = love.data.unpack(">B", key, offset)
        string_key = string_key .. part
    end
    return string_key
end

local handlers = {
    -- get the public key from the client and send our own after generating receive and transmit keys
    public_key = function(data, client)
        client.key = data
        print("client pub key: " .. sodium_key_to_string(client.key))
        client.receive_key, client.transmit_key = sodium.crypto_kx_server_session_keys(server_pk, server_sk, client.key)
        print("Calculated RT keys:")
        print(sodium_key_to_string(client.receive_key))
        print(sodium_key_to_string(client.transmit_key))
        client.send_packet("public_key", server_pk)
    end,
    -- decrypt an encrypted message from the client and call the packet handler again
    encrypted_msg = function(data, client)
        if client.receive_key then
            local nonce = data:sub(1, 24)
            -- skip reading message and cipher length (both uint64_t) as it's not required
            data = data:sub(1 + 24 + 8 + 8)
            local message = sodium.crypto_secretbox_open_easy(data, nonce, client.receive_key)
            local packet_type = love.data.unpack(">B", message)
            local str_type = packet_types.client_to_server[packet_type]
            if str_type == nil then
                print("Got an invalid packet type: " .. packet_type)
            else
                packet_handler.process(str_type, message:sub(2), client)
            end
        else
            print("Got encoded packet before getting client's RT keys!")
        end
    end,
    heartbeat = function() end,
    disconnect = function() end,
}

function packet_handler.process(packet_type, data, client)
    if handlers[packet_type] then
        handlers[packet_type](data, client)
    else
        print("Unhandled packet type: " .. packet_type)
    end
end

return packet_handler
