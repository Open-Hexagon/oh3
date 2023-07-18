-- TODO: implement functions and the game itself
local public = {
    running = false,
    first_play = true,
    tickrate = 240,
}

---starts a new game
---@param pack_id string
---@param level_id string
---@param level_options table
function public.start(pack_id, level_id, level_options)
    public.running = true
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

---returns true if the player has died
---@return boolean
function public.is_dead()
end

---stop the game
function public.stop()
    public.running = false
end

---initialize the game
---@param pack_level_data table
---@param input_handler table
---@param config table
---@param persistent_data table
---@param audio table
function public.init(pack_level_data, input_handler, config, persistent_data, audio)
end

return public
