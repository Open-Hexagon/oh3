local sqlite = require("extlibs.sqlite")
local strfun = require("extlibs.sqlite.strfun")
local api = {}

local server_path = "server/"
local db_path = love.filesystem.getSaveDirectory() .. "/" .. server_path .. "server.db"
local replay_path = server_path .. "replays/"
if not love.filesystem.getInfo(server_path) then
    love.filesystem.createDirectory(server_path)
end
if not love.filesystem.getInfo(replay_path) then
    love.filesystem.createDirectory(replay_path)
end
local database

---open the database
function api.open()
    database = sqlite({
        uri = db_path,
        users = {
            steam_id = { "text", unique = true, primary = true },
            username = { "text", unique = true },
            password_hash = "text",
        },
        scores = {
            steam_id = "text",
            pack = "text",
            level = "text",
            level_options = "luatable",
            created = { "timestamp", default = strfun.strftime("%s", "now") },
            time = "real",
            score = "real",
            replay_hash = "text",
        },
        login_tokens = {
            steam_id = { "text", unique = true },
            created = { "timestamp", default = strfun.strftime("%s", "now") },
            token = { "text", unique = true, primary = true },
        }
    })
    database:open()
end

---remove all login tokens for a user with the given steam id
---@param steam_id string
function api.remove_login_tokens(steam_id)
    database:delete("login_tokens", { where = { steam_id = steam_id } })
end

---add a login token to the database
---@param steam_id string
---@param token any
function api.add_login_token(steam_id, token)
    token = love.data.encode("string", "base64", token)
    database:insert("login_tokens", { steam_id = steam_id, token = token })
end

---check if a user exists in the database
---@param name string
---@return boolean
function api.user_exists_by_name(name)
    return #database:select("users", { where = { username = name } }) > 0
end

---check if a user exists in the database
---@param steam_id string
---@return boolean
function api.user_exists_by_steam_id(steam_id)
    return #database:select("users", { where = { steam_id = steam_id } }) > 0
end

---get the row of a user in the database
---@param name string
---@param steam_id string
---@return table|nil
function api.get_user(name, steam_id)
    local results = database:select("users", { where = { username = name, steam_id = steam_id} })
    if #results == 0 then
        return
    end
    results[1].password_hash = love.data.decode("string", "base64", results[1].password_hash)
    return results[1]
end

---register a new user in the database (returns true on success)
---@param username string
---@param steam_id integer
---@param password_hash string
---@return boolean
function api.register(username, steam_id, password_hash)
    return database:insert("users", {
        steam_id = steam_id,
        username = username,
        password_hash = love.data.encode("string", "base64", password_hash)
    })
end

---save a score into the database and save the replay
---@param time number
---@param replay Replay
function api.save_score(time, replay, steam_id)
    local hash, data = replay:get_hash()
    local dir = replay_path .. hash:sub(1, 2) .. "/"
    if not love.filesystem.getInfo(dir) then
        love.filesystem.createDirectory(dir)
    end
    local n
    local path = dir .. hash
    -- in case a replay actually has a duplicate hash (which is almost impossible) add some random numbers to it
    if love.filesystem.getInfo(path) then
        path = path .. 0
        n = 0
        while love.filesystem.getInfo(path) do
            n = n + 1
            path = path:sub(1, -2) .. n
        end
        hash = hash .. n
    end
    database:insert("scores", {
        steam_id = steam_id,
        pack = replay.pack_id,
        level = replay.level_id,
        level_options = replay.data.level_settings,
        time = time,
        score = replay.score,
        replay_hash = hash,
    })
    replay:save(path, data)
end

---delete a user with all their scores and replays
---@param steam_id any
function api.delete(steam_id)
    local scores = database:select("scores", { where = { steam_id = steam_id } })
    for i = 1, #scores do
        local score = scores[i]
        local folder = replay_path .. score.replay_hash:sub(1, 2) .. "/"
        local path = folder .. score.replay_hash
        love.filesystem.remove(path)
        if #love.filesystem.getDirectoryItems(folder) == 0 then
            love.filesystem.remove(folder)
        end
    end
    database:delete("scores", { where = { steam_id = steam_id } })
    database:delete("users", { where = { steam_id = steam_id } })
end

---close the database
function api.close()
    database:close()
end

return api
