local game = {}
local thread = love.thread.newThread("server/game_thread.lua")

function game.init()
    thread:start()
    game.level_validators = love.thread.getChannel("ranked_levels"):demand(1)
    if not game.level_validators then
        error("failed getting level ids from thread: " .. (thread:getError() or "no error"))
    end
end

function game.verify_replay_and_save_score(compressed_replay, time, steam_id)
    love.thread.getChannel("game_commands"):push({"rp", compressed_replay, time, steam_id})
end

function game.stop()
    if thread:isRunning() then
        love.thread.getChannel("game_commands"):push({"stop"})
        thread:wait()
    else
        print("Got error in game thread:\n", thread:getError())
    end
end

return game
