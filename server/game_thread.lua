local replay = require("game_handler.replay")
local game_handler = require("game_handler")
local database = require("server.database")
local config = require("config")
local uv = require("luv")

game_handler.init(config)
local level_validators = {}
local packs = game_handler.get_packs()
for j = 1, #packs do
    local pack = packs[j]
    if pack.game_version == 21 then
        for k = 1, pack.level_count do
            local level = pack.levels[k]
            for i = 1, #level.options.difficulty_mult do
                level_validators[#level_validators + 1] = pack.id .. "_" .. level.id .. "_m_" .. level.options.difficulty_mult[i]
            end
        end
    end
end
love.thread.getChannel("ranked_levels"):push(level_validators)

local time_tolerance = 3
local max_processing_time = 10

local function verify_replay(compressed_replay, time, steam_id)
    local start = uv.hrtime()
    local decoded_replay = replay:new_from_data(compressed_replay)
    game_handler.replay_start(decoded_replay)
    game_handler.run_until_death(function()
        if uv.hrtime() - start > max_processing_time * 1000000000 then
            print("exceeded max processing time")
            return true
        end
        return false
    end)
    local score = game_handler.get_score()
    if score == decoded_replay.score then
        if time + time_tolerance > score and time - time_tolerance < score then
            database.save_score(time, decoded_replay, steam_id)
            print("replay verified, score saved")
        else
            print("time between packets of " .. time .. " does not match score of " .. score)
        end
    else
        print("The replay's score of " .. decoded_replay.score .. " does not match the actual score of " .. score)
    end
end

database.open()
local run = true
while run do
    local cmd = love.thread.getChannel("game_commands"):demand()
    if cmd[1] == "rp" then
        verify_replay(cmd[2], cmd[3], cmd[4])
    elseif cmd[1] == "stop" then
        run = false
    end
end
database.close()
