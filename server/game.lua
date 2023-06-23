local log = require("log")(...)
local game = {}
local thread = love.thread.newThread("server/game_thread.lua")

function game.init()
    thread:start("server.game_thread", true)
    game.level_validators = love.thread.getChannel("ranked_levels"):demand(1)
    if not game.level_validators then
        error("failed getting level ids from thread: " .. (thread:getError() or "no error"))
    end
    game.levels = love.thread.getChannel("ranked_levels"):demand(1)
    if not game.levels then
        error("failed getting levels from thread: " .. (thread:getError() or "no error"))
    end
end

function game.verify_replay_and_save_score(compressed_replay, time, steam_id)
    love.thread.getChannel("game_commands"):push({"verify_replay", compressed_replay, time, steam_id})
end

function game.stop()
    if thread:isRunning() then
        love.thread.getChannel("game_commands"):push({"stop"})
        thread:wait()
    else
        log("Got error in game thread:\n", thread:getError())
    end
end

return game
