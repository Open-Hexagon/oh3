local log_name, as_thread = ...
local log = require("log")(log_name)
local msgpack = require("extlibs.msgpack.msgpack")
local replay = require("game_handler.replay")
local game_handler = require("game_handler")
local config = require("config")
local uv = require("luv")

game_handler.init(config)

local database, replay_path
if as_thread then
    database = require("server.database")
    database.set_identity(1)
    replay_path = database.get_replay_path()
end

local api = {}

local time_tolerance = 3
local score_tolerance = 0.2
local max_processing_time = 300
local render_top_scores = false

local function save_replay(replay_obj, hash, data)
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
    return path, hash
end

function api.verify_replay(compressed_replay, time, steam_id)
    local start = uv.hrtime()
    local decoded_replay = replay:new_from_data(compressed_replay)
    game_handler.replay_start(decoded_replay)
    game_handler.run_until_death(function()
        if uv.hrtime() - start > max_processing_time * 1000000000 then
            log("exceeded max processing time")
            return true
        end
        return false
    end)
    local score = game_handler.get_score()
    if score + score_tolerance > decoded_replay.score and score - score_tolerance < decoded_replay.score then
        if time + time_tolerance > score and time - time_tolerance < score then
            log("replay verified, score: " .. score)
            local hash, data = decoded_replay:get_hash()
            local packed_level_settings = msgpack.pack(decoded_replay.data.level_settings)
            local replay_save_path, replay_hash = save_replay(decoded_replay, hash, data)
            if
                database.save_score(
                    time,
                    steam_id,
                    decoded_replay.pack_id,
                    decoded_replay.level_id,
                    packed_level_settings,
                    score,
                    replay_hash
                )
            then
                decoded_replay:save(replay_save_path, data)
                log("Saved new score")
                if
                    render_top_scores
                    and database.is_top_score(
                        decoded_replay.pack_id,
                        decoded_replay.level_id,
                        packed_level_settings,
                        steam_id
                    )
                then
                    local channel = love.thread.getChannel("replays_to_render")
                    channel:push(replay_save_path)
                    log(channel:getCount() .. " replays queued for rendering.")
                end
            end
        else
            log("time between packets of " .. time .. " does not match score of " .. score)
        end
    else
        log("The replay's score of " .. decoded_replay.score .. " does not match the actual score of " .. score)
    end
end

function api.get_levels21()
    local level_validators = {}
    local levels = {}
    local packs = game_handler.get_packs()
    for j = 1, #packs do
        local pack = packs[j]
        if pack.game_version == 21 then
            for k = 1, pack.level_count do
                local level = pack.levels[k]
                for i = 1, #level.options.difficulty_mult do
                    level_validators[#level_validators + 1] = pack.id
                        .. "_"
                        .. level.id
                        .. "_m_"
                        .. level.options.difficulty_mult[i]
                    levels[#levels + 1] = pack.id
                    levels[#levels + 1] = level.id
                    levels[#levels + 1] = level.options.difficulty_mult[i]
                end
            end
        end
    end
    if as_thread then
        love.thread.getChannel("ranked_levels"):push(level_validators)
        love.thread.getChannel("ranked_levels"):push(levels)
    else
        return { level_validators, levels }
    end
end

function api.set_render_top_scores(bool)
    render_top_scores = bool
end

if as_thread then
    local run = true
    while run do
        local cmd = love.thread.getChannel("game_commands"):demand()
        if cmd[1] == "stop" then
            run = false
        else
            xpcall(function()
                local fn = api[cmd[1]]
                table.remove(cmd, 1)
                fn(unpack(cmd))
            end, function(err)
                log("Error while verifying replay:\n", err)
            end)
        end
    end
else
    local tbl = api.get_levels21()
    tbl[3] = game_handler.get_packs()
    return tbl
end
