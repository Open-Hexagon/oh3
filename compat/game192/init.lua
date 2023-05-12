local assets = require("compat.game192.assets")
local DynamicQuads = require("compat.game21.dynamic_quads")
local public = {
    running = false
}
local game = {
    style = require("compat.game192.style"),
    status = require("compat.game192.status"),
    level = require("compat.game192.level"),
    player = require("compat.game192.player"),
    lua_runtime = require("compat.game192.lua_runtime"),
    events = require("compat.game192.events"),
    difficulty_mult = 1,
    restart_id = "",
    restart_first_time = false,
    first_play = true,
}

local layer_shader = love.graphics.newShader(
    [[
        attribute vec2 instance_offset;
        attribute vec4 instance_color;
        varying vec4 instance_color_out;

        vec4 position(mat4 transform_projection, vec4 vertex_position)
        {
            instance_color_out = instance_color / 255.0;
            vertex_position.xy += instance_offset;
            return transform_projection * vertex_position;
        }
    ]],
    [[
        varying vec4 instance_color_out;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            return instance_color_out;
        }
    ]]
)
local instance_offsets = {}
local instance_colors = {}
local depth = 0
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
    game.events.init(game)
    game.status.reset()
    game.restart_id = level_id
    game.restart_first_time = false
    game.set_sides(game.level_data.sides)
    -- TODO: reset walls
    game.player.reset()
    -- TODO: reset timelines
    if not game.first_play then
        game.lua_runtime.run_fn_if_exists("onUnload")
    end
    game.lua_runtime.init_env(game)
    game.lua_runtime.run_lua_file(game.pack.path .. "Scripts/" .. level_data.lua_file)
    game.lua_runtime.run_fn_if_exists("onLoad")
    if math.random(0, 1) == 0 then
        game.level_data.rotation_speed = -game.level_data.rotation_speed
    end
    current_rotation = 0
    depth = game.style.get_value("3D_depth")
    if depth > 100 then
        depth = 100
    end
    public.running = true
end

local function get_sign(num)
    return (num > 0 and 1 or (num == 0 and 0 or -1))
end

local function get_smoother_step(edge0, edge1, x)
    x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return x * x * x * (x * (x * 6 - 15) + 10)
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
        game.events.update(frametime, game.status.current_time)
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
        game.level_data.rotation_speed = game.level_data.rotation_speed * 0.99
    end
    -- TODO: only update 3d if enabled in config
    game.status.pulse_3D = game.status.pulse_3D + game.style.get_value("3D_pulse_speed") * game.status.pulse_3D_direction * frametime
    if game.status.pulse_3D > game.style.get_value("3D_pulse_max") then
        game.status.pulse_3D_direction = -1
    elseif game.status.pulse_3D < game.style.get_value("3D_pulse_min") then
        game.status.pulse_3D_direction = 1
    end
    -- TODO: if not rotation disabled in config
    local next_rotation = math.abs(game.level_data.rotation_speed) * 10 * frametime
    if game.status.fast_spin > 0 then
        next_rotation = next_rotation + math.abs((get_smoother_step(0, game.level_data.fast_spin, game.status.fast_spin) / 3.5) * frametime * 17)
        game.status.fast_spin = game.status.fast_spin - frametime
    end
    current_rotation = current_rotation + next_rotation * get_sign(game.level_data.rotation_speed)
    -- only for level change, real restarts will happen externally
    if game.status.must_restart then
        game.first_play = game.restart_first_time
        public.start(game.pack.folder, game.restart_id, game.difficulty_mult)
    end
    -- TODO: invalidate score if not official status invalid set or fps limit maybe?
end

function public.draw(screen)
    local width, height = screen:getDimensions()
    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / width, 768 / height)
    -- apply pulse as well
    local p = game.status.pulse / game.level_data.pulse_min
    love.graphics.scale(zoom_factor / p, zoom_factor / p)
    local effect
    -- TODO: if 3d enabled in config
    if true then
        effect = game.style.get_value("3D_skew") * game.status.pulse_3D
        love.graphics.scale(1, 1 / (1 + effect))
    end
    love.graphics.rotate(math.rad(current_rotation))
    game.style.compute_colors()
    -- TODO: only if not background disabled in config
    -- TODO: black and white mode
    game.style.draw_background(game.level_data.sides, false)
    main_quads:clear()
    game.player.draw(game.style, game.level_data.sides, game.status.radius, main_quads, false, game.get_main_color(false))
    -- TODO: draw 3d if enabled in config
    -- TODO: draw walls
    -- TODO: if 3d enabled in config
    if true then
        -- TODO: get 3d multiplier from config (1 by default)
        local per_layer_offset = game.style.get_value("3D_spacing") * game.style.get_value("3D_perspective_multiplier") * effect * 3.6
        local rad_rot = math.rad(current_rotation)
        local sin_rot = math.sin(rad_rot)
        local cos_rot = math.cos(rad_rot)
        local darken_mult = game.style.get_value("3D_darken_multiplier")
        local r, g, b, a = game.style.get_3D_override_color()
        if darken_mult == 0 then
            r, g, b = 0, 0, 0
        else
            r = r / darken_mult
            g = g / darken_mult
            b = b / darken_mult
        end
        local alpha_mult = game.style.get_value("3D_alpha_multiplier")
        if alpha_mult == 0 then
            a = 0
        else
            a = a / alpha_mult
        end
        local alpha_falloff = game.style.get_value("3D_alpha_falloff")
        for i = 1, depth do
            local offset = per_layer_offset * (i - 1)
            instance_offsets[i] = instance_offsets[i] or {}
            instance_offsets[i][1] = offset * sin_rot
            instance_offsets[i][2] = offset * cos_rot
            instance_colors[i] = instance_colors[i] or {}
            instance_colors[i][1] = r
            instance_colors[i][2] = g
            instance_colors[i][3] = b
            instance_colors[i][4] = a
            a = (a - alpha_falloff) % 256
        end
        main_quads:set_instance_attribute_array("instance_offset", "float", 2, instance_offsets)
        main_quads:set_instance_attribute_array("instance_color", "float", 4, instance_colors)
        love.graphics.setShader(layer_shader)
        main_quads:draw_instanced(depth)
        love.graphics.setShader()
    end
    main_quads:draw()
    game.player.draw_cap(game.level_data.sides, game.style, false)
    -- TODO: draw text
    -- TODO: draw flash
end

return public
