local sqlite = require("extlibs.sqlite")

local profile = {}

local profile_path = "profiles/"
local db_path = love.filesystem.getSaveDirectory() .. "/" .. profile_path
if not love.filesystem.getInfo(profile_path) then
    love.filesystem.createDirectory(profile_path)
end
local replay_path = "replays/"
if not love.filesystem.getInfo(replay_path) then
    love.filesystem.createDirectory(replay_path)
end
local database

---open or create a new profile
---@param name string
function profile.open_or_new(name)
    local path = db_path .. name .. ".db"
    database = sqlite({
        uri = path,
        scores = {
            pack = "text",
            level = "text",
            level_options = "luatable",
            created = { "timestamp", default = sqlite.lib.strftime("%s", "now") },
            time = "real",
            score = "real",
            replay_hash = "text",
        },
        custom_data = {
            pack = { "text", unique = true, primary = true },
            data = "luatable",
        },
    })
end

---save a score into the profile's database and save the replay as well
---@param score number
---@param time number
---@param replay Replay
function profile.save_score(score, time, replay)
    local hash, data = replay:get_hash()
    database:open()
    database:insert("scores", {
        pack = replay.pack_id,
        level = replay.level_id,
        level_options = replay.data.level_settings,
        time = time,
        score = score,
        replay_hash = hash,
    })
    database:close()
    local dir = replay_path .. hash:sub(1, 2) .. "/"
    if not love.filesystem.getInfo(dir) then
        love.filesystem.createDirectory(dir)
    end
    local path = dir .. hash
    replay:save(path, data)
end

return profile
