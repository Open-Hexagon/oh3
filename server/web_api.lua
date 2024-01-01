local utils = require("compat.game192.utils")
local database = require("server.database")
local json = require("extlibs.json.json")
local msgpack = require("extlibs.msgpack.msgpack")
local threadify = require("threadify")
local threaded_assets = threadify.require("game_handler.assets")
local http = require("extlibs.http")
local url = require("socket.url")
local log = require("log")("server.web_api")
local uv = require("luv")

local args = {
    block = false,
    allow_cors = true,
    keyfile = os.getenv("TLS_KEY"),
    certfile = os.getenv("TLS_CERT"),
}
if args.keyfile and args.certfile then
    args.sslport = 8001
else
    log("WARNING: Falling back to http as no certificate or key were specified")
    args.port = 8001
end

local app = http:new(args)

json.encode_inf_as_1e500 = true

local packs
local promise = threaded_assets.init({}, true)
promise:done(function(pack_list)
    packs = pack_list
end)
while not promise.executed do
    threadify.update()
    uv.sleep(10)
end
if not packs then
    error("getting pack list failed")
end

database.set_identity(3)

local replay_path = database.get_replay_path()

local function replay_get_video_path(hash)
    local path = replay_path .. hash:sub(1, 2) .. "/" .. hash .. ".mp4"
    if love.filesystem.getInfo(path) then
        return path
    end
end

local newest_scores = database.get_newest_scores(3 * 10 ^ 6)

app.handlers["/get_newest_scores/..."] = function(captures, headers)
    local seconds = math.min(tonumber(captures[1]) or 0, 3 * 10 ^ 6)
    local channel = love.thread.getChannel("new_scores")
    for _ = 1, channel:getCount() do
        newest_scores[#newest_scores + 1] = channel:pop()
    end
    local scores = {}
    for i = 1, #newest_scores do
        if os.time() - newest_scores[i].timestamp < seconds then
            newest_scores[i].has_video = newest_scores[i].replay_hash
                    and replay_get_video_path(newest_scores[i].replay_hash)
                    and true
                or false
            scores[#scores + 1] = newest_scores[i]
        end
    end
    headers["content-type"] = "application/json"
    return json.encode(scores)
end

app.handlers["/get_leaderboard/.../.../..."] = function(captures, headers)
    local pack, level, level_options = unpack(captures)
    if pack and level and level_options then
        pack = url.unescape(pack)
        level = url.unescape(level)
        level_options = json.decode(url.unescape(level_options))
        -- only difficulty_mult needs this as it's the only legacy option
        level_options.difficulty_mult = utils.float_round(level_options.difficulty_mult)
        local lb = database.get_leaderboard(pack, level, msgpack.pack(level_options))
        for i = 1, #lb do
            local score = lb[i]
            score.has_video = score.replay_hash and replay_get_video_path(score.replay_hash) and true or false
        end
        headers["content-type"] = "application/json"
        return json.encode(lb)
    else
        return "invalid options"
    end
end

app.handlers["/get_video/..."] = function(captures, headers)
    local replay_hash = captures[1]
    local path = replay_get_video_path(replay_hash)
    if path then
        return http.file(path, headers)
    else
        return "no video for this replay"
    end
end

app.handlers["/get_packs"] = function(_, headers)
    headers["content-type"] = "application/json"
    return json.encode(packs)
end

app:run()
