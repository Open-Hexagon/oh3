local utils = require("compat.game192.utils")
local database = require("server.database")
local app = require("extlibs.milua.milua")
local json = require("extlibs.json.json")
local msgpack = require("extlibs.msgpack.msgpack")

local packs
-- garbage collect everything when done
do
    local game_handler = require("game_handler")
    local config = require("config")
    game_handler.init(config)
    packs = game_handler.get_packs()
end

database.set_identity(3)

local replay_path = database.get_replay_path()

local function replay_get_video_path(hash)
    local path = replay_path .. hash:sub(1, 2) .. "/" .. hash .. ".mp4"
    if love.filesystem.getInfo(path) then
        return path
    end
end

app.add_handler("GET", "/get_leaderboard/.../.../...", function(captures)
    local pack, level, difficulty_mult = unpack(captures)
    if pack and level and difficulty_mult then
        local level_options = msgpack.pack({ difficulty_mult = utils.float_round(tonumber(difficulty_mult)) })
        local lb = database.execute({ "get_leaderboard", pack, level, level_options, nil })
        for i = 1, #lb do
            local score = lb[i]
            score.has_video = score.replay_hash and replay_get_video_path(score.replay_hash) and true or false
        end
        return json.encode(lb), { ["content-type"] = "application/json" }
    else
        return "invalid options"
    end
end)

app.add_handler("GET", "/get_video/...", function(captures)
    local replay_hash = captures[1]
    local path = replay_get_video_path(replay_hash)
    if path then
        local file = love.filesystem.newFile(path)
        file:open("r")
        local contents = file:read()
        file:close()
        return contents, { ["content-type"] = "video/mp4" }
    else
        return "no video for this replay"
    end
end)

app.add_handler("GET", "/get_packs", function()
    return json.encode(packs), { ["content-type"] = "application/json" }
end)

app.start({
    HOST = "0.0.0.0",
    PORT = 8001,
    key = "cert/key.pem",
    cert = "cert/cert.pem",
})
