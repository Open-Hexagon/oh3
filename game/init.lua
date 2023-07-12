-- TODO: implement functions and the game itself
local public = {}

---starts a new game
---@param pack_id string
---@param level_id string
---@param level_options table
function public.start(pack_id, level_id, level_options)
end

---update the game
function public.update()
end

---draw the game to the current canvas
---@param screen love.Canvas
function public.draw(screen)
end

---get the current score
---@return number
function public.get_score()
end

---get the timed current score even if there is a custom score
---@return number
function public.get_timed_score()
end

---runs the game until the player dies without caring about real time
---@param stop_condition function
function public.run_game_until_death(stop_condition)
end

---stop the game
function public.stop()
end

---initialize the game
---@param pack_level_data table
---@param input_handler table
---@param config table
---@param persistent_data table
---@param audio table
function public.init(pack_level_data, input_handler, config, persistent_data, audio)
end
