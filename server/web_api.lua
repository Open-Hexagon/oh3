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

local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

local unescape = function(url)
  return url:gsub("%%(%x%x)", hex_to_char)
end

app.add_handler("GET", "/get_newest_scores/...", function(captures)
    local seconds = tonumber(captures[1])
    local scores = database.get_newest_scores(seconds)
    return json.encode(scores), { ["content-type"] = "application/json" }
end)

app.add_handler("GET", "/get_leaderboard/.../.../...", function(captures)
    local pack, level, level_options = unpack(captures)
    if pack and level and level_options then
        pack = unescape(pack)
        level = unescape(level)
        level_options = json.decode(unescape(level_options))
        -- only difficulty_mult needs this as it's the only legacy option
        level_options.difficulty_mult = utils.float_round(level_options.difficulty_mult)
        local lb = database.get_leaderboard(pack, level, msgpack.pack(level_options))
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
    cors_url = os.getenv("CORS_URL"),
})
