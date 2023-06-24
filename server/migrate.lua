local msgpack = require("extlibs.msgpack.msgpack")
local database = require("server.database_thread")
local utils = require("compat.game192.utils")
local level_validators, levels = unpack(require("server.game_thread"))
local sqlite = require("extlibs.sqlite")

if levels == nil then
    error("Listing levels failed")
end

local level_validator_to_id = {}
for i = 1, #level_validators do
    level_validator_to_id[level_validators[i]] = {
        pack = levels[i * 3 - 2],
        level = levels[i * 3 - 1],
        difficulty_mult = levels[i * 3],
    }
end

return function(old_db_path)
    local old_database = sqlite({
        uri = old_db_path,
    })
    database.open()
    old_database:open()
    local users = old_database:eval("SELECT cast(steamId as text), name, hex(passwordHash) FROM users")
    for i = 1, #users do
        local user = users[i]
        local hash = love.data.decode("string", "hex", user["hex(passwordHash)"])
        database.register(user.name, user["cast(steamId as text)"], hash)
    end
    local scores = old_database:eval("SELECT cast(userSteamId as text), levelValidator, value, timestamp FROM scores")
    for i = 1, #scores do
        local score = scores[i]
        local actual_level = level_validator_to_id[score.levelValidator]
        if
            actual_level == nil
            or actual_level.pack == nil
            or actual_level.level == nil
            or actual_level.difficulty_mult == nil
        then
            print("Missing '" .. score.levelValidator .. "' for migration")
        else
            print(
                actual_level.pack,
                actual_level.level,
                actual_level.difficulty_mult,
                score.value,
                score["cast(userSteamId as text)"],
                score.timestamp
            )
            local opts = { difficulty_mult = utils.float_round(actual_level.difficulty_mult) }
            database.save_score(
                score.value,
                score["cast(userSteamId as text)"],
                actual_level.pack,
                actual_level.level,
                msgpack.pack(opts),
                score.value
            )
        end
    end
    old_database:close()
    database.close()
end
