local game = {}

game.level_validators = love.thread.getChannel("ranked_levels"):demand(1)
if not game.level_validators then
    error("server thread did not recieve list of ranked levels")
end

return game
