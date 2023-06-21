local packet_types = require("server.packet_types")
local sodium = require("luasodium")

local packet_handler = {}
local server_pk, server_sk = sodium.crypto_kx_keypair()
local database

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

local function read_uint64(data, offset)
    local part1, part2
    part1, offset = love.data.unpack(">I4", data, offset)
    part2, offset = love.data.unpack(">I4", data, offset)
    return bit.lshift(part1 * 1ULL, 32) + part2 * 1ULL, offset
end

local function read_str(data, offset)
    local len
    len, offset = love.data.unpack(">I4", data, offset)
    return love.data.unpack(">c" .. len, data, offset)
end

local function write_str(str)
    return love.data.pack("string", ">I4c" .. #str, #str, str)
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
    register = function(data, client)
        local steam_id, offset = read_uint64(data)
        steam_id = tostring(steam_id):sub(1, -4)
        local name, password_hash
        name, offset = read_str(data, offset)
        password_hash, offset = read_str(data, offset)
        local function send_fail(err)
            client.send_packet("registration_failure", write_str(err))
        end
        if #name > 32 then
            send_fail("Name too long, max is 32 characters")
        elseif database.user_exists_by_steam_id(steam_id) then
            send_fail("User with steam id '" .. steam_id .. "' already registered")
        elseif database.user_exists_by_name(name) then
            send_fail("User with name '" .. name .. "' already registered")
        else
            database.register(name, steam_id, password_hash)
            print("Successfully registered new user '" .. name .. "'")
            client.send_packet("registration_success")
        end
    end,
    login = function(data, client)
        local steam_id, offset = read_uint64(data)
        steam_id = tostring(steam_id):sub(1, -4)
        local name, password_hash
        name, offset = read_str(data, offset)
        password_hash, offset = read_str(data, offset)
        local function send_fail(err)
            client.send_packet("login_failure", write_str(err))
        end
        if #name > 32 then
            send_fail("Name too long, max is 32 characters")
        elseif not database.user_exists_by_steam_id(steam_id) then
            send_fail("User with steam id '" .. steam_id .. "' not registered")
        elseif not database.user_exists_by_name(name) then
            send_fail("User with name '" .. name .. "' not registered")
        else
            local user = database.get_user(name, steam_id)
            if user then
                if user.password_hash ~= password_hash then
                    send_fail("Invalid password for user matching '" .. steam_id .. "' and '" .. name .. "'")
                else
                    local login_token = sodium.randombytes_buf(8)
                    database.remove_login_tokens(steam_id)
                    database.add_login_token(steam_id, login_token)
                    client.login_data = {
                        steam_id = steam_id,
                        username = name,
                        password_hash = password_hash,
                        login_token = login_token,
                    }
                    print("Successfully logged in user '" .. name .. "'")
                    client.send_packet("login_success", login_token .. write_str(name))
                end
            else
                send_fail("No user matching '" .. steam_id .. "' and '" .. name .. "' registered")
            end
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

function packet_handler.set_database(db)
    database = db
end

return packet_handler
