local assets = require("compat.game192.assets")
local DynamicQuads = require("compat.game21.dynamic_quads")
local set_color = require("compat.game21.color_transform")
local public = {
    running = false
}
local game = {
    style = require("compat.game192.style"),
    status = require("compat.game192.status"),
    level = require("compat.game192.level"),
    player = require("compat.game192.player"),
    lua_runtime = require("compat.game192.lua_runtime"),
    difficulty_mult = 1,
}

local last_move = 0
local main_quads = DynamicQuads:new()
local current_rotation = 0

function game.set_sides(side_count)
    -- TODO: play beep.ogg
    if side_count < 3 then
        side_count = 3
    end
    game.level_data.sides = side_count
end

function game.get_main_color(black_and_white)
    local r, g, b, a = game.style.get_main_color()
    if black_and_white then
        r, g, b = 255, 255, 255
    end
    return r, g, b, a
end

function public.start(pack_folder, level_id, difficulty_mult)
    -- TODO: first play
    game.pack = assets.get_pack(pack_folder)
    local level_data = game.pack.levels[level_id]
    if level_data == nil then
        error("Level with id '" .. level_id .. "' not found")
    end
    game.level_data = game.level.set(level_data)
    if level_data.style_id == nil then
        error("Style id cannot be 'nil'!")
    end
    local style_data = game.pack.styles[level_data.style_id]
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
    -- TODO: reset walls
    game.player.reset()
    -- TODO: reset timelines
    -- TODO: call onUnload if not first play
    game.lua_runtime.init_env(game)
    game.lua_runtime.run_lua_file(game.pack.path .. "Scripts/" .. level_data.lua_file)
    game.lua_runtime.run_fn_if_exists("onLoad")
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
    -- TODO: if not dead
    if true then
        local focus = love.keyboard.isDown("lshift")
        local cw = love.keyboard.isDown("right")
        local ccw = love.keyboard.isDown("left")
        local move
        if cw and not ccw then
            move = 1
            last_move = 1
        elseif not cw and ccw then
            move = -1
            last_move = -1
        elseif cw and ccw then
            move = -last_move
        else
            move = 0
        end
        game.player.update(frametime, game.status.radius, move, focus)
        -- TODO: update walls
        -- TODO: update events
        if game.status.time_stop <= 0 then
            game.status.current_time = game.status.current_time + frametime / 60
            game.status.increment_time = game.status.increment_time + frametime / 60
        else
            game.status.time_stop = game.status.time_stop - frametime
        end
        if game.status.increment_enabled then
            if game.status.increment_time >= game.level_data.increment_time then
                game.status.increment_time = 0
                -- TODO: increment difficulty
            end
        end
        -- TODO: update level
        -- TODO: if not beatpulse disabled in config
        if game.status.beat_pulse_delay <= 0 then
            game.status.beat_pulse = game.level_data.beat_pulse_max
            game.status.beat_pulse_delay = game.level_data.beat_pulse_delay_max
        else
            game.status.beat_pulse_delay = game.status.beat_pulse_delay - frametime
        end
        if game.status.beat_pulse > 0 then
            game.status.beat_pulse = game.status.beat_pulse - 2 * frametime
        end
        -- TODO: radius_min = 75 if beatpulse disabled in config
        local radius_min = game.level_data.radius_min
        game.status.radius = radius_min * (game.status.pulse / game.level_data.pulse_min) + game.status.beat_pulse
        -- TODO: if not pulse disabled in config
        if game.status.pulse_delay <= 0 and game.status.pulse_delay_half <= 0 then
            local pulse_add = game.status.pulse_direction > 0 and game.level_data.pulse_speed or -game.level_data.pulse_speed_r
            local pulse_limit = game.status.pulse_direction > 0 and game.level_data.pulse_max or game.level_data.pulse_min
            game.status.pulse = game.status.pulse + pulse_add * frametime
            if (game.status.pulse_direction > 0 and game.status.pulse >= pulse_limit) or (game.status.pulse_direction < 0 and game.status.pulse <= pulse_limit) then
                game.status.pulse = pulse_limit
                game.status.pulse_direction = -game.status.pulse_direction
                game.status.pulse_delay_half = game.level_data.pulse_delay_half_max
                if game.status.pulse_direction < 0 then
                    game.status.pulse_delay = game.level_data.pulse_delay_max
                end
            end
        end
        game.status.pulse_delay = game.status.pulse_delay - frametime
        game.status.pulse_delay_half = game.status.pulse_delay_half - frametime
        -- TODO: only update style if not bw mode
        game.style.update(frametime)
    else
        -- TODO: mult rot speed by 0.99
    end
    -- TODO: update 3d if enabled in config
    -- TODO: update rotation if not disabled in config
    -- TODO: handle level change
    -- TODO: invalidate score if not official status invalid set or fps limit maybe?
end

function public.draw(screen)
    local width, height = screen:getDimensions()
    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / width, 768 / height)
    -- apply pulse as well
    local p = game.status.pulse / game.level_data.pulse_min
    love.graphics.scale(zoom_factor / p, zoom_factor / p)
    love.graphics.rotate(math.rad(current_rotation))
    game.style.compute_colors()
    -- TODO: only if not background disabled in config
    -- TODO: black and white mode
    -- TODO: keep track of sides
    game.style.draw_background(game.level_data.sides, false)
    main_quads:clear()
    game.player.draw(game.style, game.level_data.sides, game.status.radius, main_quads, false, game.get_main_color(false))
    -- TODO: draw 3d if enabled in config
    -- TODO: draw walls
    main_quads:draw()
    game.player.draw_cap(game.level_data.sides, game.style, false)
    -- TODO: draw text
    -- TODO: draw flash
end

return public
