local assets = require("compat.game192.assets")
local public = {
    running = false
}
local game = {
    style = require("compat.game192.style"),
    status = require("compat.game192.status"),
    level = require("compat.game192.level"),
    difficulty_mult = 1,
}

local current_rotation = 0

function game.set_sides(side_count)
    -- TODO: play beep.ogg
    if side_count < 3 then
        side_count = 3
    end
    game.level.set_value("sides", side_count)
end


function public.start(pack_folder, level_id, difficulty_mult)
    -- TODO: first play
    local pack = assets.get_pack(pack_folder)
    local level_data = pack.levels[level_id]
    if level_data == nil then
        error("Level with id '" .. level_id .. "' not found")
    end
    game.level_data = game.level.set(level_data)
    if level_data.style_id == nil then
        error("Style id cannot be 'nil'!")
    end
    local style_data = pack.styles[level_data.style_id]
    if style_data == nil then
        error("Style with id '" .. level_data.style_id .. "' does not exist.")
    end
    game.style.select(style_data)
    -- TODO: set music
    game.difficulty_mult = difficulty_mult
    -- TODO: clear messages
    -- TODO: clear events
    game.status.reset()
    game.set_sides(game.level_data.sides)
    -- TODO: reset walls and player
    -- TODO: reset timelines
    -- TODO: call onUnload if not first play
    -- TODO: reset lua env
    -- TODO: run level lua
    -- TODO: run onLoad
    if math.random(0, 1) == 0 then
        game.level_data.rotation_speed = -game.level_data.rotation_speed
    end
    current_rotation = 0
    -- TODO: init 3d (max 100) cannot change during runtime
    public.running = true
end

function public.update(frametime)
    frametime = frametime * 60
    -- TODO: adjust tick rate based on object count
    -- TODO: update flash
    -- TODO: update effects
    -- TODO: if not dead:
    --   TODO: update walls
    --   TODO: update events
    --   TODO: update time stop
    --   TODO: update increment
    --   TODO: update level
    --   TODO: update beatpulse if not disabled in config
    --   TODO: update pulse if not disabled in config
    --   TODO: only update style if not bw mode
    game.style.update(frametime)
    -- TODO: if dead: mult rot speed by 0.99
    -- TODO: update 3d if enabled in config
    -- TODO: update rotation if not disabled in config
    -- TODO: handle level change
    -- TODO: invalidate score if not official status invalid set or fps limit maybe?
end

function public.draw(screen)
    local width, height = screen:getDimensions()
    local zoom_factor = 1 / math.max(1024 / width, 768 / height)
    love.graphics.scale(zoom_factor, zoom_factor)
    love.graphics.rotate(math.rad(current_rotation))
    game.style.compute_colors()
    -- TODO: only if not background disabled in config
    -- TODO: black and white mode
    -- TODO: keep track of sides
    game.style.draw_background(game.level_data.sides, false)
    -- TODO: draw 3d if enabled in config
    -- TODO: draw walls
    -- TODO: draw text
    -- TODO: draw flash
end

return public
