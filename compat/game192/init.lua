local args = require("args")
local playsound = require("compat.game21.playsound")
local assets = require("compat.game192.assets")
local DynamicQuads = require("compat.game21.dynamic_quads")
local Timeline = require("compat.game192.timeline")
local set_color = require("compat.game21.color_transform")
local public = {
    config = require("compat.game192.config"),
    running = false,
}
local game = {
    style = require("compat.game192.style"),
    status = require("compat.game192.status"),
    level = require("compat.game192.level"),
    player = require("compat.game192.player"),
    lua_runtime = require("compat.game192.lua_runtime"),
    events = require("compat.game192.events"),
    walls = require("compat.game192.walls"),
    difficulty_mult = 1,
    restart_id = "",
    restart_first_time = false,
    first_play = true,
    main_timeline = Timeline:new(),
    message_timeline = Timeline:new(),
    effect_timeline = Timeline:new(),
    real_time = 0,
    blocked_updates = 0,
    assets = assets,
    current_frametime = 0.25 / 60,
}

local shake_move = { 0, 0 }
local beep_sound, death_sound, game_over_sound, go_sound, level_up_sound, message_font, layer_shader, main_quads
if not args.headless then
    beep_sound = assets.get_sound("beep.ogg")
    death_sound = assets.get_sound("death.ogg")
    game_over_sound = assets.get_sound("game_over.ogg")
    go_sound = assets.get_sound("go.ogg")
    level_up_sound = assets.get_sound("level_up.ogg")
    message_font = love.graphics.newFont("assets/font/imagine.ttf", 40)
    layer_shader = love.graphics.newShader(
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
    main_quads = DynamicQuads:new()
end
local instance_offsets = {}
local instance_colors = {}
local depth = 0
local last_move = 0
local last_real_time = 0
local current_rotation = 0

function game.increment_difficulty()
    playsound(level_up_sound)
    game.level_data.rotation_speed = game.level_data.rotation_speed
        + game.level_data.rotation_increment * (game.level_data.rotation_speed > 0 and 1 or -1)
    game.level_data.rotation_speed = -game.level_data.rotation_speed
    if game.status.fast_spin < 0 and math.abs(game.level_data.rotation_speed) > game.level_data.rotation_speed_max then
        game.level_data.rotation_speed = game.level_data.rotation_speed_max
            * (game.level_data.rotation_speed > 0 and 1 or -1)
    end
    game.status.fast_spin = game.level_data.fast_spin
    game.main_timeline:append_do(function()
        game.side_change(math.random(game.level_data.sides_min, game.level_data.sides_max))
    end)
end

function game.side_change(side_count)
    if game.walls.size() > 0 then
        game.main_timeline:at_start_do(function()
            game.main_timeline:clear()
            game.main_timeline:reset()
        end)
        game.main_timeline:at_start_do(function()
            game.side_change(side_count)
        end)
        game.main_timeline:at_start_wait(1)
    else
        game.lua_runtime.run_fn_if_exists("onIncrement")
        game.level_data.speed_multiplier = game.level_data.speed_multiplier + game.level_data.speed_increment
        -- This is wrong, ask vee what he thought while doing that in 1.92 lol
        game.level_data.delay_increment = game.level_data.delay_multiplier + game.level_data.delay_increment
        if game.status.random_side_changes_enabled then
            game.set_sides(side_count)
        end
    end
end

function game.set_sides(side_count)
    playsound(beep_sound)
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
    game.real_time = 0
    last_real_time = 0
    public.running = true
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
    game.difficulty_mult = difficulty_mult
    if not args.headless then
        love.audio.stop()
        love.audio.play(go_sound)
        game.music = game.pack.music[level_data.music_id]
        if game.music == nil then
            error("Music with id '" .. level_data.music_id .. "' not found")
        end
        if game.music.source ~= nil then
            if game.first_play then
                game.music.source:seek(math.floor(game.music.segments[1].time))
            else
                game.music.source:seek(math.floor(game.music.segments[math.random(1, #game.music.segments)].time))
            end
            love.audio.play(game.music.source)
        end
    end
    game.message_text = ""
    game.events.init(game)
    game.status.reset()
    game.restart_id = level_id
    game.restart_first_time = false
    game.set_sides(game.level_data.sides)
    game.walls.clear()
    game.walls.set_level_data(game.level_data, game.difficulty_mult)
    game.player.reset(public.config)
    game.main_timeline:clear()
    game.main_timeline:reset()
    game.message_timeline:clear()
    game.message_timeline:reset()
    game.effect_timeline:clear()
    game.effect_timeline:reset()
    if not game.first_play then
        game.lua_runtime.run_fn_if_exists("onUnload")
    end
    game.lua_runtime.init_env(game, public)
    game.lua_runtime.run_lua_file(game.pack.path .. "Scripts/" .. level_data.lua_file)
    game.lua_runtime.run_fn_if_exists("onLoad")
    if math.random(0, 1) == 0 then
        game.level_data.rotation_speed = -game.level_data.rotation_speed
    end
    current_rotation = 0
    depth = math.floor(game.style.get_value("3D_depth"))
    if depth > 100 then
        depth = 100
    end
    shake_move[1], shake_move[2] = 0, 0
end

local function get_sign(num)
    return (num > 0 and 1 or (num == 0 and 0 or -1))
end

local function get_smoother_step(edge0, edge1, x)
    x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return x * x * x * (x * (x * 6 - 15) + 10)
end

function public.keypressed(key)
    -- TODO: make this work with ui? or make it specific only for levels that need it?
    if key == "r" or key == "up" then
        game.status.must_restart = true
    end
end

function public.update(frametime)
    if game.blocked_updates > 0 then
        game.blocked_updates = game.blocked_updates - 1
        return
    end
    game.current_frametime = frametime
    game.real_time = game.real_time + frametime
    frametime = (game.real_time - last_real_time) * 60
    last_real_time = game.real_time
    if frametime > 4 then
        frametime = 4
    end
    game.input.update()
    if game.status.flash_effect > 0 then
        game.status.flash_effect = game.status.flash_effect - 3 * frametime
    end
    if game.status.flash_effect > 255 then
        game.status.flash_effect = 255
    elseif game.status.flash_effect < 0 then
        game.status.flash_effect = 0
    end
    if game.status.has_died then
        game.effect_timeline:update(frametime)
        if game.effect_timeline.finished then
            game.effect_timeline:clear()
            game.effect_timeline:reset()
        end
    end
    if not game.status.has_died then
        local focus = game.input.get("key_focus")
        local cw = game.input.get("key_right")
        local ccw = game.input.get("key_left")
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
        game.walls.update(frametime, game.status.radius)
        if game.player.update(frametime, game.status.radius, move, focus, game.walls) then
            playsound(death_sound)
            playsound(game_over_sound)
            if not public.config.get("invincible") then
                game.status.flash_effect = 255
                -- camera shake
                local s = 7
                for i = s, 0, -1 do
                    local j = s - i + 1
                    for _ = 1, j * 3 do
                        game.effect_timeline:append_do(function()
                            shake_move[1] = (1 - math.random() * 2) * i
                            shake_move[2] = (1 - math.random() * 2) * i
                        end)
                        game.effect_timeline:append_wait(1)
                    end
                end
                game.effect_timeline:append_do(function()
                    shake_move[1], shake_move[2] = 0, 0
                end)
                game.status.has_died = true
                if not args.headless and game.music.source ~= nil then
                    love.audio.stop(game.music.source)
                end
            end
        end
        game.events.update(frametime, game.status.current_time, game.message_timeline)
        if game.status.time_stop <= 0 then
            game.status.current_time = game.status.current_time + frametime / 60
            game.status.increment_time = game.status.increment_time + frametime / 60
        else
            game.status.time_stop = game.status.time_stop - frametime
        end
        if game.status.increment_enabled then
            if game.status.increment_time >= game.level_data.increment_time then
                game.status.increment_time = 0
                game.increment_difficulty()
            end
        end
        game.lua_runtime.run_fn_if_exists("onUpdate", frametime)
        game.main_timeline:update(frametime)
        if game.main_timeline.finished then
            game.main_timeline:clear()
            game.lua_runtime.run_fn_if_exists("onStep")
            game.main_timeline:reset()
        end
        if public.config.get("beatpulse") then
            if game.status.beatpulse_delay <= 0 then
                game.status.beatpulse = game.level_data.beatpulse_max
                game.status.beatpulse_delay = game.level_data.beatpulse_delay_max
            else
                game.status.beatpulse_delay = game.status.beatpulse_delay - frametime
            end
            if game.status.beatpulse > 0 then
                game.status.beatpulse = game.status.beatpulse - 2 * frametime
            end
            game.status.radius = game.level_data.radius_min * (game.status.pulse / game.level_data.pulse_min)
                + game.status.beatpulse
        end
        if public.config.get("pulse") then
            if game.status.pulse_delay <= 0 and game.status.pulse_delay_half <= 0 then
                local pulse_add = game.status.pulse_direction > 0 and game.level_data.pulse_speed
                    or -game.level_data.pulse_speed_r
                local pulse_limit = game.status.pulse_direction > 0 and game.level_data.pulse_max
                    or game.level_data.pulse_min
                game.status.pulse = game.status.pulse + pulse_add * frametime
                if
                    (game.status.pulse_direction > 0 and game.status.pulse >= pulse_limit)
                    or (game.status.pulse_direction < 0 and game.status.pulse <= pulse_limit)
                then
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
        end
        if not public.config.get("black_and_white") then
            game.style.update(frametime)
        end
    else
        game.level_data.rotation_speed = game.level_data.rotation_speed * 0.99
    end
    if public.config.get("3D_enabled") then
        game.status.pulse_3D = game.status.pulse_3D
            + game.style.get_value("3D_pulse_speed") * game.status.pulse_3D_direction * frametime
        if game.status.pulse_3D > game.style.get_value("3D_pulse_max") then
            game.status.pulse_3D_direction = -1
        elseif game.status.pulse_3D < game.style.get_value("3D_pulse_min") then
            game.status.pulse_3D_direction = 1
        end
    end
    if public.config.get("rotation") then
        local next_rotation = math.abs(game.level_data.rotation_speed) * 10 * frametime
        if game.status.fast_spin > 0 then
            next_rotation = next_rotation
                + math.abs(
                    (get_smoother_step(0, game.level_data.fast_spin, game.status.fast_spin) / 3.5) * frametime * 17
                )
            game.status.fast_spin = game.status.fast_spin - frametime
        end
        current_rotation = current_rotation + next_rotation * get_sign(game.level_data.rotation_speed)
    end
    -- only for level change, real restarts will happen externally
    if game.status.must_restart then
        game.first_play = game.restart_first_time
        public.start(game.pack.folder, game.restart_id, game.difficulty_mult)
    end
    -- TODO: invalidate score if not official status invalid set or fps limit maybe?

    if public.reset_timings then
        game.lua_runtime.reset_timings = false
    end
    public.reset_timings = game.lua_runtime.reset_timings

    -- TODO: make adjustable on a per level basis
    local performance = 0.03
    local target_frametime = (
        (0.785 * depth + 1) * (0.000461074 * performance + 0.000155698) * game.walls.size()
        + performance * (0.025 * depth + 1)
    )
    if target_frametime < 0.0625 then
        target_frametime = 0.0625
    elseif target_frametime > 0.25 then
        target_frametime = 0.25
    end
    return target_frametime / 60
end

function public.draw(screen)
    local width, height = screen:getDimensions()
    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / width, 768 / height)
    -- apply pulse as well
    local p = game.status.pulse / game.level_data.pulse_min
    love.graphics.scale(zoom_factor / p, zoom_factor / p)
    love.graphics.translate(unpack(shake_move))
    local effect
    if public.config.get("3D_enabled") then
        effect = game.style.get_value("3D_skew") * game.status.pulse_3D
        love.graphics.scale(1, 1 / (1 + effect))
    end
    love.graphics.rotate(math.rad(current_rotation))
    game.style.compute_colors()
    local black_and_white = public.config.get("black_and_white")
    if public.config.get("background") then
        game.style.draw_background(game.level_data.sides, black_and_white)
    end
    main_quads:clear()
    game.walls.draw(main_quads, game.get_main_color(black_and_white))
    game.player.draw(
        game.style,
        game.level_data.sides,
        game.status.radius,
        main_quads,
        black_and_white,
        game.get_main_color(black_and_white)
    )
    if public.config.get("3D_enabled") and depth ~= 0 then
        local per_layer_offset = game.style.get_value("3D_spacing")
            * game.style.get_value("3D_perspective_multiplier")
            * public.config.get("3D_multiplier")
            * effect
            * 3.6
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
    -- message and flash shouldn't be affected by skew/rotation
    love.graphics.origin()
    love.graphics.scale(zoom_factor, zoom_factor)
    if game.message_text ~= nil then
        local function draw_text(ox, oy)
            love.graphics.print(
                game.message_text,
                message_font,
                width / zoom_factor / 2 - message_font:getWidth(game.message_text) / 2 + ox,
                height / zoom_factor / 6 + oy
            )
        end
        local r, g, b, a = game.style.get_second_color()
        if black_and_white then
            r, g, b, a = 0, 0, 0, 0
        end
        set_color(r, g, b, a)
        -- 1.92 unlike the steam version actually does outlines like this so it's probably fine to do the same here
        draw_text(-1, -1)
        draw_text(-1, 1)
        draw_text(1, -1)
        draw_text(1, 1)
        r, g, b, a = game.style.get_main_color()
        if black_and_white then
            r, g, b = 255, 255, 255
        end
        set_color(r, g, b, a)
        draw_text(0, 0)
    end
    if game.status.flash_effect ~= 0 then
        set_color(255, 255, 255, game.status.flash_effect)
        love.graphics.rectangle("fill", 0, 0, width / zoom_factor, height / zoom_factor)
    end
end

---give the game an input handler that is capable of replaying or recording inputs
---@param input table
function public.set_input_handler(input)
    game.input = input
    input.custom_keybinds = {
        key_focus = public.config.get("key_focus"),
        key_right = public.config.get("key_right"),
        key_left = public.config.get("key_left"),
    }
end

---get the current score (gets the custom score if one exists)
---@return integer
function public.get_score()
    return game.status.current_time
end

---runs the game until the player dies without caring about real time
function public.run_game_until_death()
    local frametime = 1 / 240
    while not game.status.has_died do
        -- TODO: timescale
        frametime = public.update(frametime) or frametime
    end
end

---stop the game (works during gameplay and gets out of blocking calls)
function public.stop()
    public.running = false
end

return public
