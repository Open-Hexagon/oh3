local sqlite = require("extlibs.sqlite")
local strfun = require("extlibs.sqlite.strfun")

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
local current_profile

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
            created = { "timestamp", default = strfun.strftime("%s", "now") },
            time = "real",
            score = "real",
            replay_hash = "text",
        },
        custom_data = {
            pack = { "text", unique = true, primary = true },
            data = "luatable",
        },
    })
    current_profile = name
end

---get all persistent data stored in the database for a pack
---@param pack_id string
---@return table?
function profile.get_data(pack_id)
    local matches = database.custom_data:get({ where = { pack = pack_id } })
    if #matches == 0 then
        return nil
    elseif #matches == 1 then
        return matches[1].data
    else
        error("Found " .. #matches .. " matches for primary key value '" .. pack_id .. "' which should be impossible!")
    end
end

---get all persistent data from the profile (pack_id/data as key/value pairs)
---@return table
function profile.get_all_data()
    local rows = database.custom_data:get()
    local result = {}
    for i = 1, #rows do
        local row = rows[i]
        result[row.pack] = row.data
    end
    return result
end

---store any persistent data for a pack in the database (overwrites data for the pack if it already has some)
---@param pack_id string
---@param data table
function profile.store_data(pack_id, data)
    database:open()
    database:update("custom_data", {
        where = { pack = pack_id },
        set = { data = data },
    })
    database:close()
end

---save a score into the profile's database and save the replay as well
---@param score number
---@param time number
---@param replay Replay
function profile.save_score(score, time, replay)
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
        print("added", n)
    end
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
    replay:save(path, data)
end

---delete the currently selected profile with all its replays
function profile.delete()
    database:open()
    local scores = database:select("scores")
    for i = 1, #scores do
        local score = scores[i]
        local folder = replay_path .. score.replay_hash:sub(1, 2) .. "/"
        local path = folder .. score.replay_hash
        love.filesystem.remove(path)
        if #love.filesystem.getDirectoryItems(folder) == 0 then
            love.filesystem.remove(folder)
        end
    end
    database:close()
    local path = profile_path .. current_profile .. ".db"
    love.filesystem.remove(path)
    database = nil
    current_profile = nil
end

return profile
