local assets = require("compat.game20.assets")
local public = {
    running = false,
    first_play = true,
}

---starts a new game
---@param pack_id string
---@param level_id string
---@param level_options table
function public.start(pack_id, level_id, level_options)
    local difficulty_mult = level_options.difficulty_mult
    if not difficulty_mult then
        error("Cannot start compat game without difficulty mult")
    end
    local pack = assets.get_pack(pack_id)
    local level = pack.levels[level_id]
    public.running = true
end

---update the game
function public.update()
    -- the game runs on a tickrate of 120 ticks per second
    return 1 / 120
end

---draw the game to the current canvas
---@param screen love.Canvas
function public.draw(screen) end

---get the current score
---@return number
function public.get_score() end

---get the timed current score
---@return number
function public.get_timed_score() end

---runs the game until the player dies without caring about real time
---@param stop_condition function
function public.run_game_until_death(stop_condition) end

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
    assets.init(pack_level_data, persistent_data, audio, config)
end

return public
