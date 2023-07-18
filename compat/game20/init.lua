local args = require("args")
local uv = require("luv")
local playsound = require("compat.game21.playsound")
local assets = require("compat.game20.assets")
local make_fake_config = require("compat.game20.fake_config")
local lua_runtime = require("compat.game20.lua_runtime")
local dynamic_quads = require("compat.game21.dynamic_quads")
local set_color = require("compat.game21.color_transform")
local timeline = require("compat.game20.timeline")
local public = {
    running = false,
    first_play = true,
}
local game = {
    status = require("compat.game20.status"),
    level = require("compat.game20.level"),
    level_status = require("compat.game20.level_status"),
    vfs = require("compat.game192.virtual_filesystem"),
    style = require("compat.game20.style"),
    player = require("compat.game20.player"),
    walls = require("compat.game20.walls"),
    main_timeline = timeline:new(),
    event_timeline = timeline:new(),
    message_timeline = timeline:new(),
    message_text = "",
    beep_sound = nil,
}
local main_quads
local must_change_sides = false
local last_move, input_both_cw_ccw = 0, false
local death_sound, game_over_sound, level_up_sound, go_sound
local depth = 0
local layer_shader, message_font
local instance_offsets = {}
local instance_colors = {}

---starts a new game
---@param pack_id string
---@param level_id string
---@param level_options table
function public.start(pack_id, level_id, level_options)
    game.difficulty_mult = level_options.difficulty_mult
    if not game.difficulty_mult then
        error("Cannot start compat game without difficulty mult")
    end
    local seed = math.floor(uv.hrtime())
    math.randomseed(game.input.next_seed(seed))
    game.pack = assets.get_pack(pack_id)
    game.level.set(game.pack.levels[level_id])
    game.level_status.reset()
    game.style.set(game.pack.styles[game.level.styleId])
    public.running = true
    local segment
    if not args.headless and game.music and game.music.source then
        game.music.source:stop()
    end
    game.music = game.pack.music[game.level.musicId]
    if not public.first_play then
        segment = math.random(1, #game.music.segments)
    end
    if not args.headless then
        go_sound:play()
        if game.music and game.music.source then
            if public.first_play then
                game.music.source:seek(math.floor(game.music.segments[1].time))
            else
                game.music.source:seek(math.floor(game.music.segments[segment].time))
            end
            game.music.source:set_pitch(game.config.get("sync_music_to_dm") and math.pow(game.difficulty_mult, 0.12) or 1)
            game.music.source:play()
        end
    end

    -- virtual filesystem init
    game.vfs.clear()
    game.vfs.pack_path = game.pack.path
    game.vfs.pack_folder_name = game.pack.folder
    local files = {
        ["config.json"] = make_fake_config(game.config),
    }
    if public.persistent_data ~= nil then
        for path, contents in pairs(public.persistent_data) do
            files[path] = contents
        end
    end
    game.vfs.load_files(files)

    game.message_text = ""
    game.event_timeline:clear()
    game.event_timeline:reset()
    game.message_timeline:clear()
    game.message_timeline:reset()
    game.walls.init(game)
    game.player.reset(game, assets)
    game.main_timeline:clear()
    game.main_timeline:reset()
    must_change_sides = false
    game.status.reset()
    game.real_time = 0
    if not public.first_play then
        lua_runtime.run_fn_if_exists("onUnload")
    end
    lua_runtime.init_env(game, public, assets)
    lua_runtime.run_lua_file(game.pack.path .. game.level.luaFile)
    lua_runtime.run_fn_if_exists("onInit")
    lua_runtime.run_fn_if_exists("onLoad")
    game.set_sides(game.level_status.sides)
    game.current_rotation = 0
    game.style._3D_depth = math.min(game.style._3D_depth, game.config.get("3D_max_depth"))
    depth = game.style._3D_depth
end

function game.increment_difficulty()
    playsound(level_up_sound)
    game.level_status.rotation_speed = game.level_status.rotation_speed + game.level_status.rotation_speed_inc * (game.level_status.rotation_speed > 0 and 1 or -1)
    game.level_status.rotation_speed = -game.level_status.rotation_speed
    local rotation_speed_max = game.level_status.rotation_speed_max
    if game.status.fast_spin < 0 and math.abs(game.level_status.rotation_speed) > rotation_speed_max then
        game.level_status.rotation_speed = rotation_speed_max * (game.level_status.rotation_speed > 0 and 1 or -1)
    end
    game.status.fast_spin = game.level_status.fast_spin
end

function game.get_speed_mult_dm()
    return game.level_status.speed_mult * math.pow(game.difficulty_mult, 0.65)
end

function game.get_delay_mult_dm()
    return game.level_status.delay_mult / math.pow(game.difficulty_mult, 0.10)
end

function game.death(force)
    playsound(death_sound)
    if not force and (game.config.get("invincible") or game.level_status.tutorial_mode) then
        return
    end
    playsound(game_over_sound)
    game.status.flash_effect = 255
    -- TODO: camera shake
    game.status.has_died = true
    if not args.headless and game.music and game.music.source then
        game.music.source:stop()
    end
    if public.death_callback then
        public.death_callback()
    end
end

function game.set_sides(sides)
    playsound(game.beep_sound)
    if sides < 3 then
        sides = 3
    end
    game.level_status.sides = sides
end

local function get_smoother_step(edge0, edge1, x)
    x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return x * x * x * (x * (x * 6 - 15) + 10)
end

---update the game
---@param frametime number
---@return number
function public.update(frametime)
    game.real_time = game.real_time + frametime
    frametime = frametime * 60
    game.input.update()
    local focus = game.input.get(game.config.get("key_focus"))
    local swap = game.input.get(game.config.get("key_swap"))
    local cw = game.input.get(game.config.get("key_right"))
    local ccw = game.input.get(game.config.get("key_left"))
    local move = 0
    if cw and not ccw then
        move = 1
    elseif not cw and ccw then
        move = -1
    elseif cw and ccw then
        if not input_both_cw_ccw then
            if move == 1 and last_move == 1 then
                move = -1
            elseif move == -1 and last_move == -1 then
                move = 1
            end
        end
    end
    last_move = move
    input_both_cw_ccw = cw and ccw
    if game.status.flash_effect > 0 then
        game.status.flash_effect = game.status.flash_effect - 3 * frametime
    end
    if game.status.flash_effect > 255 then
        game.status.flash_effect = 255
    elseif game.status.flash_effect < 0 then
        game.status.flash_effect = 0
    end
    if not game.status.has_died then
        game.walls.update(frametime)
        game.player.update(frametime, move, focus, swap)
        game.event_timeline:update(frametime)
        if game.event_timeline.finished then
            game.event_timeline:clear()
            game.event_timeline:reset()
        end
        game.message_timeline:update(frametime)
        if game.message_timeline.finished then
            game.message_timeline:clear()
            game.message_timeline:reset()
        end
        if game.status.time_stop <= 0 then
            game.status.current_time = game.status.current_time + frametime / 60
            game.status.increment_time = game.status.increment_time + frametime / 60
        else
            game.status.time_stop = game.status.time_stop - frametime
        end
        if game.level_status.inc_enabled and game.status.increment_time >= game.level_status.inc_time then
            game.status.increment_time = 0
            game.increment_difficulty()
            must_change_sides = true
        end
        if must_change_sides and #game.walls.entities == 0 then
            local sides = math.random(game.level_status.sides_min, game.level_status.sides_max)
            lua_runtime.run_fn_if_exists("onIncrement")
            game.level_status.speed_mult = game.level_status.speed_mult + game.level_status.speed_inc
            game.level_status.delay_mult = game.level_status.delay_mult + game.level_status.delay_inc
            if game.level_status.rnd_side_changes_enabled then
                game.set_sides(sides)
            end
            must_change_sides = false
        end
        if game.status.time_stop <= 0 then
            lua_runtime.run_fn_if_exists("onUpdate", frametime)
            game.main_timeline:update(frametime)
            if game.main_timeline.finished and not must_change_sides then
                game.main_timeline:clear()
                lua_runtime.run_fn_if_exists("onStep")
                game.main_timeline:reset()
            end
        end
        local music_dm_sync_factor = game.config.get("sync_music_to_dm") and math.pow(game.difficulty_mult, 0.12) or 1
        if game.config.get("beatpulse") then
            if game.status.beatpulse_delay <= 0 then
                game.status.beatpulse = game.level_status.beat_pulse_max
                game.status.beatpulse_delay = game.level_status.beat_pulse_delay_max
            else
                game.status.beatpulse_delay = game.status.beatpulse_delay - frametime * music_dm_sync_factor
            end
            if game.status.beatpulse > 0 then
                game.status.beatpulse = game.status.beatpulse - 2 * frametime * music_dm_sync_factor
            end
            local radius_min = game.config.get("beatpulse") and game.level_status.radius_min or 75
            game.status.radius = radius_min * (game.status.pulse / game.level_status.pulse_min) + game.status.beatpulse
        end
        if game.config.get("pulse") then
            if game.status.pulse_delay <= 0 and game.status.pulse_delay_half <= 0 then
                local pulse_add = game.status.pulse_direction > 0 and game.level_status.pulse_speed
                    or -game.level_status.pulse_speed_r
                local pulse_limit = game.status.pulse_direction > 0 and game.level_status.pulse_max
                    or game.level_status.pulse_min
                game.status.pulse = game.status.pulse + pulse_add * frametime * music_dm_sync_factor
                if
                    (game.status.pulse_direction > 0 and game.status.pulse >= pulse_limit)
                    or (game.status.pulse_direction < 0 and game.status.pulse <= pulse_limit)
                then
                    game.status.pulse = pulse_limit
                    game.status.pulse_direction = -game.status.pulse_direction
                    game.status.pulse_delay_half = game.level_status.pulse_delay_half_max
                    if game.status.pulse_direction < 0 then
                        game.status.pulse_delay = game.level_status.pulse_delay_max
                    end
                end
            end
            game.status.pulse_delay = game.status.pulse_delay - frametime
            game.status.pulse_delay_half = game.status.pulse_delay_half - frametime
        end
        if not game.config.get("black_and_white") then
            game.style.update(frametime, math.pow(game.difficulty_mult, 0.8))
        end
    else
        game.level_status.rotation_speed = game.level_status.rotation_speed * 0.99
    end
    if game.config.get("3D_enabled") then
        game.status.pulse_3D = game.status.pulse_3D + game.style._3D_pulse_speed * game.status.pulse_3D_direction * frametime
        if game.status.pulse_3D > game.style._3D_pulse_max then
            game.status.pulse_3D_direction = -1
        elseif game.status.pulse_3D < game.style._3D_pulse_min then
            game.status.pulse_3D_direction = 1
        end
    end
    if game.config.get("rotation") then
        local next_rotation = game.level_status.rotation_speed * 10
        if game.status.fast_spin > 0 then
            next_rotation = next_rotation
                + math.abs(get_smoother_step(0, game.level_status.fast_spin, game.status.fast_spin) / 3.5 * 17)
                    * (next_rotation > 0 and 1 or -1)
            game.status.fast_spin = game.status.fast_spin - frametime
        end
        game.current_rotation = (game.current_rotation + next_rotation * frametime) % 360
    end
    -- the game runs on a tickrate of 120 ticks per second
    return 1 / 120
end

---draw the game to the current canvas
---@param screen love.Canvas
function public.draw(screen)
    local width, height = screen:getDimensions()
    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / width, 768 / height)
    -- apply pulse as well
    local p = game.status.pulse / game.level_status.pulse_min
    love.graphics.scale(zoom_factor / p, zoom_factor / p)
    local effect
    if game.config.get("3D_enabled") then
        effect = game.style._3D_skew * game.status.pulse_3D * game.config.get("3D_multiplier")
        love.graphics.scale(1, 1 / (1 + effect))
    end
    love.graphics.rotate(math.rad(game.current_rotation))
    game.style.compute_colors()
    local black_and_white = game.config.get("black_and_white")
    if game.config.get("background") then
        game.style.draw_background(game.level_status.sides, black_and_white)
    end
    main_quads:clear()
    game.walls.draw(main_quads)
    game.player.draw(main_quads)
    if game.config.get("3D_enabled") and depth > 0 then
        local per_layer_offset = game.style._3D_spacing
            * game.style._3D_perspective_mult
            * effect
            * 3.6
        local rad_rot = math.rad(game.current_rotation)
        local sin_rot = math.sin(rad_rot)
        local cos_rot = math.cos(rad_rot)
        local darken_mult = game.style._3D_darken_mult
        local r, g, b, a = game.style.get_3D_override_color()
        if darken_mult == 0 then
            r, g, b = 0, 0, 0
        else
            r = r / darken_mult
            g = g / darken_mult
            b = b / darken_mult
        end
        local alpha_mult = game.style._3D_alpha_mult
        if alpha_mult == 0 then
            a = 0
        else
            a = a / alpha_mult
        end
        local alpha_falloff = game.style._3D_alpha_falloff
        for i = 1, depth do
            local offset = per_layer_offset * i
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
    game.player.draw_cap()

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
        local r, g, b, a = game.style.get_color(2)
        if black_and_white then
            r, g, b, a = 0, 0, 0, 0
        end
        set_color(r, g, b, a)
        -- 2.0-rc2 unlike the steam version actually does outlines like this so it's probably fine to do the same here
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
    if game.status.flash_effect ~= 0 and game.config.get("flash") then
        set_color(255, 255, 255, game.status.flash_effect)
        love.graphics.rectangle("fill", 0, 0, width / zoom_factor, height / zoom_factor)
    end
end

---get the current score
---@return number
function public.get_score()
    return game.status.current_time
end

---get the timed current score
---@return number
function public.get_timed_score()
    return game.real_time
end

---runs the game until the player dies without caring about real time
---@param stop_condition function
function public.run_game_until_death(stop_condition)
    while not game.status.has_died do
        public.update(1 / 120)
        if stop_condition and stop_condition() then
            return
        end
    end
    public.stop()
end

---stop the game
function public.stop()
    public.running = false
    if not args.headless and game.music and game.music.source then
        game.music.source:stop()
    end
end

---updates the persistent data
function public.update_save_data()
    local files = game.vfs.dump_files()
    files["config.json"] = nil
    local has_files = false
    for _, _ in pairs(files) do
        has_files = true
        break
    end
    if has_files then
        public.persistent_data = files
    end
end

---initialize the game
---@param pack_level_data table
---@param input_handler table
---@param config table
---@param persistent_data table
---@param audio table
function public.init(pack_level_data, input_handler, config, persistent_data, audio)
    assets.init(pack_level_data, persistent_data, audio, config)
    game.config = config
    game.input = input_handler
    if not args.headless then
        game.beep_sound = assets.get_sound("click.ogg")
        death_sound = assets.get_sound("death.ogg")
        game_over_sound = assets.get_sound("game_over.ogg")
        level_up_sound = assets.get_sound("level_up.ogg")
        go_sound = assets.get_sound("go.ogg")
        main_quads = dynamic_quads:new()
        message_font = love.graphics.newFont("assets/font/imagine.ttf", 38)
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
    end
end

return public
