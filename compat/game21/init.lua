-- 2.1.X compatibility mode
local Timeline = require("compat.game21.timeline")
local Quads = require("compat.game21.dynamic_quads")
local Tris = require("compat.game21.dynamic_tris")
local set_color = require("compat.game21.color_transform")
local Particles = require("compat.game21.particles")
local public = {
    config = require("compat.game21.config"),
    assets = require("compat.game21.assets"),
    running = false,
}
local game = {
    lua_runtime = require("compat.game21.lua_runtime"),
    level_status = require("compat.game21.level_status"),
    level_data = nil,
    pack_data = nil,
    difficulty_mult = nil,
    music = nil,
    seed = nil,
    message_text = "",
    last_move = 0,
    must_change_sides = false,
    current_rotation = 0,
    status = require("compat.game21.status"),
    style = require("compat.game21.style"),
    player = require("compat.game21.player"),
    player_now_ready_to_swap = false,
    event_timeline = Timeline:new(),
    message_timeline = Timeline:new(),
    main_timeline = Timeline:new(),
    custom_timelines = require("compat.game21.custom_timelines"),
    first_play = true,
    walls = require("compat.game21.walls"),
    custom_walls = require("compat.game21.custom_walls"),
    flash_color = { 0, 0, 0, 0 },
    width = love.graphics.getWidth(),
    height = love.graphics.getHeight(),
}
local wall_quads = Quads:new()
local pivot_quads = Quads:new()
local player_tris = Tris:new()
local cap_tris = Tris:new()
local layer_offsets = {}
local pivot_layer_colors = {}
local wall_layer_colors = {}
local player_layer_colors = {}
local death_shake_translate = { 0, 0 }
local current_trail_color = { 0, 0, 0, 0 }
local swap_particle_info = { x = 0, y = 0, angle = 0 }
local layer_shader = love.graphics.newShader(
    [[
        attribute vec2 instance_position;
        attribute vec4 instance_color;
        varying vec4 instance_color_out;

        vec4 position(mat4 transform_projection, vec4 vertex_position)
        {
            instance_color_out = instance_color / 255.0;
            vertex_position.xy += instance_position;
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
local message_font = public.assets.get_font("OpenSquare-Regular.ttf", 32 * public.config.get("text_scale"))
local go_sound = public.assets.get_sound("go.ogg")
local swap_blip_sound = public.assets.get_sound("swap_blip.ogg")
local level_up_sound = public.assets.get_sound("level_up.ogg")
local restart_sound = public.assets.get_sound("restart.ogg")
local select_sound = public.assets.get_sound("select.ogg")
local small_circle = public.assets.get_image("smallCircle.png")
local trail_particles
trail_particles = Particles:new(small_circle, function(p, frametime)
    p.color[4] = p.color[4] - trail_particles.alpha_decay / 255 * frametime
    p.scale = p.scale * 0.98
    local distance = game.status.radius + 2.4
    p.x, p.y = math.cos(p.angle) * distance, math.sin(p.angle) * distance
    return p.color[4] <= 3 / 255
end, public.config.get("player_trail_alpha"), public.config.get("player_trail_decay"))
local swap_particles = Particles:new(small_circle, function(p, frametime)
    p.color[4] = p.color[4] - 3.5 / 255 * frametime
    p.scale = p.scale * 0.98
    p.x = p.x + math.cos(p.angle) * p.speed_mult * frametime
    p.y = p.y + math.sin(p.angle) * p.speed_mult * frametime
    return p.color[4] <= 3 / 255
end)
local spawn_swap_particles_ready = false
local must_spawn_swap_particles = false

function public.start(pack_folder, level_id, difficulty_mult)
    game.pack_data = public.assets.get_pack(pack_folder)
    game.level_data = game.pack_data.levels[level_id]
    game.level_status.reset(public.config.get("sync_music_to_dm"), public.assets)
    game.style.select(game.pack_data.styles[game.level_data.styleId])
    game.style.compute_colors()
    game.difficulty_mult = difficulty_mult
    game.status.reset_all_data()
    game.music = game.pack_data.music[game.level_data.musicId]
    if game.music == nil then
        error("Music with id '" .. game.level_data.musicId .. "' doesn't exist!")
    end
    game.refresh_music_pitch()
    local segment
    if game.first_play then
        segment = game.music.segments[1]
    else
        segment = game.music.segments[math.random(1, #game.music.segments)]
    end
    game.status.beat_pulse_delay = game.status.beat_pulse_delay + (segment.beat_pulse_delay_offset or 0)
    if game.music.source ~= nil then
        game.music.source:seek(segment.time)
        love.audio.play(game.music.source)
    end

    -- initialize random seed
    -- TODO: replays (need to read random seed from file)
    game.seed = math.floor(love.timer.getTime() * 1000)
    math.randomseed(game.seed)
    math.random()

    game.event_timeline:clear()
    game.message_timeline:clear()
    game.custom_timelines:reset()
    game.walls.reset(game.level_status)
    game.custom_walls.cw_clear()

    game.player.reset(
        game.get_swap_cooldown(),
        public.config.get("player_size"),
        public.config.get("player_speed"),
        public.config.get("player_focus_speed")
    )

    game.flash_color = { 255, 255, 255, 0 }

    game.current_rotation = 0
    game.must_change_sides = false
    if not game.first_play then
        game.lua_runtime.run_fn_if_exists("onPreUnload")
    end
    game.lua_runtime.init_env(game, public)
    game.lua_runtime.run_lua_file(game.pack_data.path .. "/" .. game.level_data.luaFile)
    public.running = true
    if game.first_play then
        love.audio.play(select_sound)
    else
        game.lua_runtime.run_fn_if_exists("onUnload")
        love.audio.play(restart_sound)
    end
    game.lua_runtime.run_fn_if_exists("onInit")
    game.set_sides(game.level_status.sides)
    game.status.pulse_delay = game.status.pulse_delay + game.level_status.pulse_initial_delay
    game.status.beat_pulse_delay = game.status.beat_pulse_delay + game.level_status.beat_pulse_initial_delay
    game.status.start()
    game.message_text = ""
    love.audio.play(go_sound)
    game.lua_runtime.run_fn_if_exists("onLoad")

    trail_particles:reset()
    swap_particles:reset(30)
end

function game.get_speed_mult_dm()
    local result = game.level_status.speed_mult * math.pow(game.difficulty_mult, 0.65)
    if not game.level_status.has_speed_max_limit() then
        return result
    end
    return result < game.level_status.speed_max and result or game.level_status.speed_max
end

function game.perform_player_kill()
    local fatal = not public.config.get("invincible") and not game.level_status.tutorial_mode
    game.player.kill(fatal)
    game.death()
end

function game.death(force)
    if not game.status.has_died then
        game.lua_runtime.run_fn_if_exists("onPreDeath")
        if force or not (game.level_status.tutorial_mode or public.config.get("invincible")) then
            game.lua_runtime.run_fn_if_exists("onDeath")
            game.status.camera_shake = 45 * public.config.get("camera_shake_mult")
            love.audio.stop()
            game.flash_color[1] = 255
            game.flash_color[2] = 255
            game.flash_color[3] = 255
            game.status.flash_effect = 255
            game.status.has_died = true
        end
        love.audio.play(game.level_status.death_sound)
    end
end

function game.perform_player_swap(play_sound)
    game.player.player_swap()
    game.lua_runtime.run_fn_if_exists("onCursorSwap")
    if play_sound then
        love.audio.play(game.level_status.swap_sound)
    end
end

function game.get_music_dm_sync_factor()
    return math.pow(game.difficulty_mult, 0.12)
end

function game.refresh_music_pitch()
    if game.music.source ~= nil then
        local pitch = game.level_status.music_pitch
            * public.config.get("music_speed_mult")
            * (game.level_status.sync_music_to_dm and game.get_music_dm_sync_factor() or 1)
        if pitch ~= pitch then
            -- pitch is NaN, happens with negative difficulty mults
            pitch = 1
        end
        if pitch < 0 then
            -- pitch can't be 0, setting it to almost 0, not sure if this could cause issues
            pitch = 0.001
        end
        game.music.source:setPitch(pitch)
    end
end

function game.get_swap_cooldown()
    return math.max(36 * game.level_status.swap_cooldown_mult, 8)
end

function game.set_sides(sides)
    love.audio.play(game.level_status.beep_sound)
    if sides < 3 then
        sides = 3
    end
    game.level_status.sides = sides
end

function game.increment_difficulty()
    love.audio.play(level_up_sound)
    local sign_mult = game.level_status.rotation_speed > 0 and 1 or -1
    game.level_status.rotation_speed = game.level_status.rotation_speed
        + game.level_status.rotation_speed_inc * sign_mult
    if math.abs(game.level_status.rotation_speed) > game.level_status.rotation_speed_max then
        game.level_status.rotation_speed = game.level_status.rotation_speed_max * sign_mult
    end
    game.level_status.rotation_speed = -game.level_status.rotation_speed
    game.status.fast_spin = game.level_status.fast_spin
end

function public.update(frametime)
    frametime = frametime * 60
    -- TODO: don't update if debug pause

    -- update flash
    if game.status.flash_effect > 0 then
        game.status.flash_effect = game.status.flash_effect - 3 * frametime
    end
    if game.status.flash_effect < 0 then
        game.status.flash_effect = 0
    elseif game.status.flash_effect > 255 then
        game.status.flash_effect = 255
    end
    game.flash_color[4] = game.status.flash_effect

    -- update input
    local focus = love.keyboard.isDown(public.config.get("key_focus"))
    local swap = love.keyboard.isDown(public.config.get("key_swap"))
    local cw = love.keyboard.isDown(public.config.get("key_right"))
    local ccw = love.keyboard.isDown(public.config.get("key_left"))
    local move
    if cw and not ccw then
        move = 1
        game.last_move = 1
    elseif not cw and ccw then
        move = -1
        game.last_move = -1
    elseif cw and ccw then
        move = -game.last_move
    else
        move = 0
    end
    -- TODO: update key icons and level info, or in ui code?
    if public.running then
        game.style.compute_colors()
        game.player.update(focus, game.level_status.swap_enabled, frametime)
        if not game.status.has_died then
            local prevent_player_input = game.lua_runtime.run_fn_if_exists("onInput", frametime, move, focus, swap)
            if not prevent_player_input then
                game.player.update_input_movement(move, game.level_status.player_speed_mult, focus, frametime)
                if not game.player_now_ready_to_swap and game.player.is_ready_to_swap() then
                    must_spawn_swap_particles = true
                    spawn_swap_particles_ready = true
                    swap_particle_info.x, swap_particle_info.y = game.player.get_position()
                    swap_particle_info.angle = game.player.get_player_angle()
                    game.player_now_ready_to_swap = true
                    if public.config.get("play_swap_sound") then
                        love.audio.play(swap_blip_sound)
                    end
                end
                if game.level_status.swap_enabled and swap and game.player.is_ready_to_swap() then
                    must_spawn_swap_particles = true
                    spawn_swap_particles_ready = false
                    swap_particle_info.x, swap_particle_info.y = game.player.get_position()
                    swap_particle_info.angle = game.player.get_player_angle()
                    game.perform_player_swap(true)
                    game.player.reset_swap(game.get_swap_cooldown())
                    game.player.set_just_swapped(true)
                    game.player_now_ready_to_swap = false
                else
                    game.player.set_just_swapped(false)
                end
            end
            game.status.accumulate_frametime(frametime)
            if game.level_status.score_overwritten then
                game.status.update_custom_score(game.lua_runtime.env[game.level_status.score_overwrite])
            end

            -- events
            if game.event_timeline:update(game.status.get_time_tp()) then
                game.event_timeline:clear()
            end
            if game.message_timeline:update(game.status.get_current_tp()) then
                game.message_timeline:clear()
            end

            -- increment
            if
                game.level_status.inc_enabled
                and game.status.get_increment_time_seconds() >= game.level_status.inc_time
            then
                game.level_status.current_increments = game.level_status.current_increments + 1
                game.increment_difficulty()
                game.status.reset_increment_time()
                game.must_change_sides = true
            end

            if game.must_change_sides and game.walls.empty() then
                local side_number = math.random(game.level_status.sides_min, game.level_status.sides_max)
                game.level_status.speed_mult = game.level_status.speed_mult + game.level_status.speed_inc
                game.level_status.delay_mult = game.level_status.delay_mult + game.level_status.delay_inc
                if game.level_status.rnd_side_changes_enabled then
                    game.set_sides(side_number)
                end
                game.must_change_sides = false
                love.audio.play(game.level_status.level_up_sound)
                game.lua_runtime.run_fn_if_exists("onIncrement")
            end

            if not game.status.is_time_paused() then
                game.lua_runtime.run_fn_if_exists("onUpdate", frametime)
                if game.main_timeline:update(game.status.get_time_tp()) and not game.must_change_sides then
                    game.main_timeline:clear()
                    game.lua_runtime.run_fn_if_exists("onStep")
                end
            end
            game.custom_timelines.update(game.status.get_current_tp())

            if public.config.get("beatpulse") then
                if not game.level_status.manual_beat_pulse_control then
                    if game.status.beat_pulse_delay <= 0 then
                        game.status.beat_pulse = game.level_status.beat_pulse_max
                        game.status.beat_pulse_delay = game.level_status.beat_pulse_delay_max
                    else
                        game.status.beat_pulse_delay = game.status.beat_pulse_delay
                            - frametime * game.get_music_dm_sync_factor()
                    end
                    if game.status.beat_pulse > 0 then
                        game.status.beat_pulse = game.status.beat_pulse
                            - 2
                                * frametime
                                * game.get_music_dm_sync_factor()
                                * game.level_status.beat_pulse_speed_mult
                    end
                end
            end
            local radius_min = public.config.get("beatpulse") and game.level_status.radius_min or 75
            game.status.radius = radius_min * (game.status.pulse / game.level_status.pulse_min) + game.status.beat_pulse

            if not game.level_status.manual_pulse_control then
                if game.status.pulse_delay <= 0 then
                    local pulse_add = game.status.pulse_direction > 0 and game.level_status.pulse_speed
                        or -game.level_status.pulse_speed_r
                    local pulse_limit = game.status.pulse_direction > 0 and game.level_status.pulse_max
                        or game.level_status.pulse_min
                    game.status.pulse = game.status.pulse + pulse_add * frametime * game.get_music_dm_sync_factor()
                    if
                        (game.status.pulse_direction > 0 and game.status.pulse >= pulse_limit)
                        or (game.status.pulse_direction < 0 and game.status.pulse <= pulse_limit)
                    then
                        game.status.pulse = pulse_limit
                        game.status.pulse_direction = -game.status.pulse_direction
                        if game.status.pulse_direction < 0 then
                            game.status.pulse_delay = game.level_status.pulse_delay_max
                        end
                    end
                end
                game.status.pulse_delay = game.status.pulse_delay - frametime * game.get_music_dm_sync_factor()
            end

            if not public.config.get("black_and_white") then
                game.style.update(frametime, math.pow(game.difficulty_mult, 0.8))
            end

            game.player.update_position(game.status.radius)
            game.walls.update(frametime, game.status.radius)
            if
                game.walls.handle_collision(move, frametime, game.player, game.status.radius)
                or game.custom_walls.handle_collision(move, game.status.radius, game.player, frametime)
            then
                game.perform_player_kill()
            end
        else
            game.level_status.rotation_speed = game.level_status.rotation_speed * 0.99
        end

        game.status.pulse3D = game.status.pulse3D
            + game.style.pseudo_3D_pulse_speed * game.status.pulse3D_direction * frametime
        if game.status.pulse3D > game.style.pseudo_3D_pulse_max then
            game.status.pulse3D_direction = -1
        elseif game.status.pulse3D < game.style.pseudo_3D_pulse_min then
            game.status.pulse3D_direction = 1
        end
        -- update rotation
        local next_rotation = game.level_status.rotation_speed * 10
        if game.status.fast_spin > 0 then
            local function get_sign(num)
                return (num > 0 and 1 or (num == 0 and 0 or -1))
            end
            local function get_smoother_step(edge0, edge1, x)
                x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
                return x * x * x * (x * (x * 6 - 15) + 10)
            end
            next_rotation = next_rotation
                + math.abs((get_smoother_step(0, game.level_status.fast_spin, game.status.fast_spin) / 3.5) * 17)
                    * get_sign(next_rotation)
            game.status.fast_spin = game.status.fast_spin - frametime
        end
        game.current_rotation = game.current_rotation + next_rotation * frametime

        if game.status.camera_shake <= 0 then
            death_shake_translate[1] = 0
            death_shake_translate[2] = 0
        else
            game.status.camera_shake = game.status.camera_shake - frametime
            death_shake_translate[1] = (1 - math.random() * 2) * game.status.camera_shake
            death_shake_translate[2] = (1 - math.random() * 2) * game.status.camera_shake
        end

        if not game.status.has_died then
            math.random(math.abs(game.status.pulse * 1000))
            math.random(math.abs(game.status.pulse3D * 1000))
            math.random(math.abs(game.status.fast_spin * 1000))
            math.random(math.abs(game.status.flash_effect * 1000))
            math.random(math.abs(game.level_status.rotation_speed * 1000))
        end

        -- update trail color (also used for swap particles)
        current_trail_color[1], current_trail_color[2], current_trail_color[3] = game.style.get_player_color()
        if public.config.get("black_and_white") then
            current_trail_color[1], current_trail_color[2], current_trail_color[3] = 255, 255, 255
        else
            if public.config.get("player_trail_has_swap_color") then
                game.player.get_color_adjusted_for_swap(current_trail_color)
            else
                game.player.get_color(current_trail_color)
            end
        end
        current_trail_color[4] = public.config.get("player_trail_alpha")

        if public.config.get("show_player_trail") and game.status.show_player_trail then
            trail_particles:update(frametime)
            if game.player.has_changed_angle() then
                local x, y = game.player.get_position()
                trail_particles:emit(
                    x,
                    y,
                    public.config.get("player_trail_scale"),
                    game.player.get_player_angle(),
                    unpack(current_trail_color)
                )
            end
        end

        if public.config.get("show_swap_particles") then
            swap_particles:update(frametime)
            if must_spawn_swap_particles then
                must_spawn_swap_particles = false
                local function spawn_particle(expand, speed_mult, scale_mult, alpha)
                    swap_particles.spawn_alpha = alpha
                    swap_particles:emit(
                        swap_particle_info.x,
                        swap_particle_info.y,
                        (love.math.random() * 0.7 + 0.65) * scale_mult,
                        swap_particle_info.angle + (love.math.random() * 2 - 1) * expand,
                        current_trail_color[1],
                        current_trail_color[2],
                        current_trail_color[3],
                        (love.math.random() * 9.9 + 0.1) * speed_mult
                    )
                end
                if spawn_swap_particles_ready then
                    for _ = 1, 14 do
                        spawn_particle(3.14, 1.3, 0.4, 140)
                    end
                else
                    for _ = 1, 20 do
                        spawn_particle(0.45, 1, 1, 45)
                    end
                    for _ = 1, 10 do
                        spawn_particle(3.14, 0.45, 0.75, 35)
                    end
                end
            end
        end

        -- supress empty block warning for now
        --- @diagnostic disable
        if game.level_status.pseudo_3D_required and not public.config.get("3D_enabled") then
            -- TODO: invalidate score
        end
        if game.level_status.shaders_required and not public.config.get("shaders") then
            -- TODO: invalidate score
        end
        --- @diagnostic enable
    end
end

function public.draw(screen)
    -- for lua access
    game.width, game.height = screen:getDimensions()

    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / game.width, 768 / game.height)
    -- apply pulse as well
    local p = public.config.get("pulse") and game.status.pulse / game.level_status.pulse_min or 1
    love.graphics.scale(zoom_factor / p, zoom_factor / p)
    love.graphics.translate(unpack(death_shake_translate))

    if not game.status.has_died then
        if game.level_status.camera_shake > 0 then
            love.graphics.translate(
                -- use love.math.random instead of math.random to not break replay rng
                (love.math.random() * 2 - 1) * game.level_status.camera_shake,
                (love.math.random() * 2 - 1) * game.level_status.camera_shake
            )
        end
    end
    local depth, pulse_3d, effect, rad_rot, sin_rot, cos_rot
    if public.config.get("3D_enabled") then
        depth = game.style.pseudo_3D_depth
        pulse_3d = public.config.get("pulse") and game.status.pulse3D or 1
        effect = game.style.pseudo_3D_skew * pulse_3d * public.config.get("3D_multiplier")
        rad_rot = math.rad(game.current_rotation + 90)
        sin_rot = math.sin(rad_rot)
        cos_rot = math.cos(rad_rot)
        love.graphics.scale(1, 1 / (1 + effect))
    end

    -- apply rotation
    love.graphics.rotate(-math.rad(game.current_rotation))

    local function set_render_stage(render_stage, no_shader, instanced)
        if public.config.get("shaders") then
            local shader = game.status.fragment_shaders[render_stage]
            if shader ~= nil then
                game.lua_runtime.run_fn_if_exists("onRenderStage", render_stage, love.timer.getDelta() * 60)
                if instanced then
                    love.graphics.setShader(shader.instance_shader)
                else
                    if render_stage ~= 8 then
                        love.graphics.setShader(shader.shader)
                    else
                        love.graphics.setShader(shader.text_shader)
                    end
                end
            else
                love.graphics.setShader(no_shader)
            end
        end
    end

    local black_and_white = public.config.get("black_and_white")
    if public.config.get("background") then
        set_render_stage(0)
        game.style.draw_background(
            game.level_status.sides,
            game.level_status.darken_uneven_background_chunk,
            black_and_white
        )
    end

    wall_quads:clear()
    game.walls.draw(game.style, wall_quads, black_and_white)
    game.custom_walls.draw(wall_quads)

    player_tris:clear()
    pivot_quads:clear()
    cap_tris:clear()
    if game.status.started then
        game.player.draw(
            game.level_status.sides,
            game.style,
            pivot_quads,
            player_tris,
            cap_tris,
            public.config.get("player_tilt_intensity"),
            public.config.get("swap_blinking_effect"),
            black_and_white
        )
    end
    love.graphics.setColor(1, 1, 1, 1)

    if public.config.get("3D_enabled") then
        local function adjust_alpha(a, i)
            if game.style.pseudo_3D_alpha_mult == 0 then
                return a
            end
            local new_alpha = (a / game.style.pseudo_3D_alpha_mult) - i * game.style.pseudo_3D_alpha_falloff
            if new_alpha > 255 then
                return 255
            elseif new_alpha < 0 then
                return 0
            end
            return new_alpha
        end
        for j = 1, depth do
            local i = depth - j
            local offset = game.style.pseudo_3D_spacing
                * (i + 1)
                * game.style.pseudo_3D_perspective_mult
                * effect
                * 3.6
                * 1.4
            layer_offsets[j] = layer_offsets[j] or {}
            layer_offsets[j][1] = offset * cos_rot
            layer_offsets[j][2] = offset * sin_rot
            local r, g, b, a = game.style.get_3D_override_color()
            if black_and_white then
                r, g, b = 255, 255, 255
                game.style.pseudo_3D_override_is_main = false
            end
            r = r / game.style.pseudo_3D_darken_mult
            g = g / game.style.pseudo_3D_darken_mult
            b = b / game.style.pseudo_3D_darken_mult
            a = adjust_alpha(a, i)
            pivot_layer_colors[j] = pivot_layer_colors[j] or {}
            pivot_layer_colors[j][1] = r
            pivot_layer_colors[j][2] = g
            pivot_layer_colors[j][3] = b
            pivot_layer_colors[j][4] = a
            if game.style.pseudo_3D_override_is_main then
                r, g, b, a = game.style.get_wall_color()
                r = r / game.style.pseudo_3D_darken_mult
                g = g / game.style.pseudo_3D_darken_mult
                b = b / game.style.pseudo_3D_darken_mult
                a = adjust_alpha(a, i)
            end
            wall_layer_colors[j] = wall_layer_colors[j] or {}
            wall_layer_colors[j][1] = r
            wall_layer_colors[j][2] = g
            wall_layer_colors[j][3] = b
            wall_layer_colors[j][4] = a
            if game.style.pseudo_3D_override_is_main then
                r, g, b, a = game.style.get_player_color()
                r = r / game.style.pseudo_3D_darken_mult
                g = g / game.style.pseudo_3D_darken_mult
                b = b / game.style.pseudo_3D_darken_mult
                a = adjust_alpha(a, i)
            end
            player_layer_colors[j] = player_layer_colors[j] or {}
            player_layer_colors[j][1] = r
            player_layer_colors[j][2] = g
            player_layer_colors[j][3] = b
            player_layer_colors[j][4] = a
        end
        if depth > 0 then
            wall_quads:set_instance_attribute_array("instance_position", "float", 2, layer_offsets)
            wall_quads:set_instance_attribute_array("instance_color", "float", 4, wall_layer_colors)
            pivot_quads:set_instance_attribute_array("instance_position", "float", 2, layer_offsets)
            pivot_quads:set_instance_attribute_array("instance_color", "float", 4, pivot_layer_colors)
            player_tris:set_instance_attribute_array("instance_position", "float", 2, layer_offsets)
            player_tris:set_instance_attribute_array("instance_color", "float", 4, player_layer_colors)

            set_render_stage(1, layer_shader, true)
            wall_quads:draw_instanced(depth)
            set_render_stage(2, layer_shader, true)
            pivot_quads:draw_instanced(depth)
            set_render_stage(3, layer_shader, true)
            player_tris:draw_instanced(depth)
        end
    end

    if public.config.get("show_player_trail") and game.status.show_player_trail then
        love.graphics.setShader()
        love.graphics.draw(trail_particles.batch)
    end

    if public.config.get("show_swap_particles") then
        love.graphics.setShader()
        love.graphics.draw(swap_particles.batch)
    end

    set_render_stage(4)
    wall_quads:draw()
    set_render_stage(5)
    cap_tris:draw()
    set_render_stage(6)
    pivot_quads:draw()
    set_render_stage(7)
    player_tris:draw()

    -- text shouldn't be affected by rotation/pulse
    love.graphics.origin()
    love.graphics.scale(zoom_factor, zoom_factor)
    love.graphics.translate(unpack(death_shake_translate))
    set_render_stage(8)
    if game.message_text ~= "" then
        -- text
        -- TODO: offset_color = game.style.get_color(0)  -- black in bw mode
        -- TODO: draw outlines (if not disabled in config)
        local r, g, b, a = game.style.get_text_color()
        if black_and_white then
            r, g, b = 255, 255, 255
        end
        set_color(r, g, b, a)
        love.graphics.print(
            game.message_text,
            message_font,
            game.width / zoom_factor / 2 - message_font:getWidth(game.message_text) / 2,
            game.height / zoom_factor / 5.5
        )
    end

    -- reset render stage shaders
    love.graphics.setShader()

    -- flash shouldnt be affected by rotation/pulse/camera_shake
    love.graphics.origin()
    love.graphics.scale(zoom_factor, zoom_factor)
    if game.flash_color[4] ~= 0 and public.config.get("flash") then
        set_color(unpack(game.flash_color))
        love.graphics.rectangle("fill", 0, 0, game.width / zoom_factor, game.height / zoom_factor)
    end
end

return public
