-- 2.1.X compatibility mode
local args = require("args")
local playsound = require("compat.game21.playsound")
local Timeline = require("compat.game21.timeline")
local Quads = require("compat.game21.dynamic_quads")
local Tris = require("compat.game21.dynamic_tris")
local set_color = require("compat.game21.color_transform")
local assets = require("compat.game21.assets")
local utils = require("compat.game192.utils")
local uv = require("luv")
local pulse = require("compat.game21.pulse")
local beat_pulse = require("compat.game21.beat_pulse")
local pseudo3d = require("compat.game21.pseudo3d")
local swap_particles = require("compat.game21.swap_particles")
local trail_particles = require("compat.game21.trail_particles")
local flash = require("compat.game21.flash")
local input = require("compat.game21.input")
local level_update = require("compat.game21.level_update")
local camera_shake = require("compat.game21.camera_shake")
local rotation = require("compat.game21.rotation")
local public = {
    running = false,
    first_play = true,
    tickrate = 240,
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
    walls = require("compat.game21.walls"),
    custom_walls = require("compat.game21.custom_walls"),
    flash_color = { 0, 0, 0, 0 },
    rng = require("compat.game21.random"),
}
local wall_quads, pivot_quads, player_tris, cap_tris
if args.headless then
    -- should be fine as long as no level uses initial values here to make rng
    game.width, game.height = 0, 0
else
    game.width = love.graphics.getWidth()
    game.height = love.graphics.getHeight()
    wall_quads = Quads:new()
    pivot_quads = Quads:new()
    player_tris = Tris:new()
    cap_tris = Tris:new()
end
local current_trail_color = { 0, 0, 0, 0 }

-- initialized in init function
local message_font, go_sound, level_up_sound, restart_sound, select_sound

---starts a new game
---@param pack_id string
---@param level_id string
---@param level_options table
function public.start(pack_id, level_id, level_options)
    -- update inital window dimensions when starting as well (for onInit/onLoad)
    if not args.headless then
        game.width = love.graphics.getWidth()
        game.height = love.graphics.getHeight()
    end
    local difficulty_mult = level_options.difficulty_mult
    if not difficulty_mult or type(difficulty_mult) ~= "number" then
        error("Must specify a numeric difficulty mult when running a compat game")
    end
    local seed = uv.hrtime()
    math.randomseed(game.input.next_seed(seed))
    math.random()
    game.pack_data = assets.get_pack_from_id(pack_id)
    game.level_data = game.pack_data.levels[level_id]
    if game.level_data == nil then
        error("Error: level with id '" .. level_id .. "' not found")
    end
    game.level_status.reset(game.config.get("sync_music_to_dm"), assets)
    local style_data = game.pack_data.styles[game.level_data.styleId]
    if style_data == nil then
        error("Error: style with id '" .. game.level_data.styleId .. "' not found")
    end
    game.style.select(style_data)
    game.style.compute_colors()
    game.difficulty_mult = difficulty_mult
    game.status.reset_all_data()
    game.music = game.pack_data.music[game.level_data.musicId]
    if game.music == nil then
        error("Music with id '" .. game.level_data.musicId .. "' doesn't exist!")
    end
    game.refresh_music_pitch()
    local segment
    if public.first_play then
        segment = game.music.segments[1]
    else
        segment = game.music.segments[math.random(1, #game.music.segments)]
    end
    game.status.beat_pulse_delay = game.status.beat_pulse_delay + (segment.beat_pulse_delay_offset or 0)
    if game.music.source ~= nil then
        game.music.source:seek(segment.time)
        game.music.source:play()
    end

    game.rng.set_seed(game.input.next_seed(seed))

    game.main_timeline:clear()
    game.event_timeline:clear()
    game.message_timeline:clear()
    game.custom_timelines:reset()
    game.walls.reset(game.level_status)
    game.custom_walls.cw_clear()
    game.player.reset(
        game.get_swap_cooldown(),
        game.config.get("player_size"),
        game.config.get("player_speed"),
        game.config.get("player_focus_speed")
    )
    flash.init(game)
    game.current_rotation = 0
    game.must_change_sides = false
    if not public.first_play then
        game.lua_runtime.run_fn_if_exists("onPreUnload")
    end
    game.lua_runtime.init_env(game, public, assets)
    game.lua_runtime.run_lua_file(game.pack_data.path .. "/" .. game.level_data.luaFile)
    public.running = true
    if public.first_play then
        playsound(select_sound)
    else
        game.lua_runtime.run_fn_if_exists("onUnload")
        playsound(restart_sound)
    end
    game.lua_runtime.run_fn_if_exists("onInit")
    game.set_sides(game.level_status.sides)
    pulse.init(game)
    beat_pulse.init(game)
    game.status.start()
    game.message_text = ""
    playsound(go_sound)
    game.lua_runtime.run_fn_if_exists("onLoad")

    if not args.headless then
        swap_particles.init(assets)
        trail_particles.init(assets, game)
    end
end

function game.set_sides(sides)
    playsound(game.level_status.beep_sound)
    if sides < 3 then
        sides = 3
    end
    game.level_status.sides = sides
end

function game.get_swap_cooldown()
    return math.max(36 * game.level_status.swap_cooldown_mult, 8)
end

function game.get_speed_mult_dm()
    local result = game.level_status.speed_mult * math.pow(game.difficulty_mult, 0.65)
    if not game.level_status.has_speed_max_limit() then
        return result
    end
    return result < game.level_status.speed_max and result or game.level_status.speed_max
end

function game.death(force)
    if not game.status.has_died then
        game.lua_runtime.run_fn_if_exists("onPreDeath")
        playsound(game.level_status.death_sound)
        if force or not (game.level_status.tutorial_mode or game.config.get("invincible")) then
            game.lua_runtime.run_fn_if_exists("onDeath")
            camera_shake.start()
            if not args.headless and game.music ~= nil and game.music.source ~= nil then
                game.music.source:stop()
            end
            flash.start_white()
            game.status.has_died = true
            if public.death_callback ~= nil then
                public.death_callback()
            end
        end
    end
end

function game.perform_player_swap(play_sound)
    game.player.player_swap()
    game.lua_runtime.run_fn_if_exists("onCursorSwap")
    if play_sound then
        playsound(game.level_status.swap_sound)
    end
end

local function get_music_dm_sync_factor()
    return math.pow(game.difficulty_mult, 0.12)
end

function game.refresh_music_pitch()
    if game.music.source ~= nil then
        local pitch = game.level_status.music_pitch
            * game.config.get("music_speed_mult")
            * (game.level_status.sync_music_to_dm and get_music_dm_sync_factor() or 1)
        if pitch ~= pitch then
            -- pitch is NaN, happens with negative difficulty mults
            pitch = 1
        end
        if pitch < 0 then
            -- pitch can't be 0, setting it to almost 0, not sure if this could cause issues
            pitch = 0.001
        end
        game.music.source:set_pitch(pitch)
    end
end

function game.increment_difficulty()
    playsound(level_up_sound)
    local sign_mult = game.level_status.rotation_speed > 0 and 1 or -1
    game.level_status.rotation_speed =
        utils.float_round(game.level_status.rotation_speed + game.level_status.rotation_speed_inc * sign_mult)
    if math.abs(game.level_status.rotation_speed) > game.level_status.rotation_speed_max then
        game.level_status.rotation_speed = game.level_status.rotation_speed_max * sign_mult
    end
    game.level_status.rotation_speed = -game.level_status.rotation_speed
    game.status.fast_spin = game.level_status.fast_spin
end

---update the game
---@param frametime number (in seconds)
function public.update(frametime)
    game.input.update()
    frametime = frametime * 60
    -- TODO: don't update if debug pause

    flash.update(frametime)

    if public.running then
        game.style.compute_colors()
        input.update(frametime)
        if not game.status.has_died then
            -- TODO: draw tracked vars (needs ui)
            -- small snippet to print them:
            --[[for var, name in pairs(game.level_status.tracked_variables) do
                print(name, game.lua_runtime.env[var])
            end]]
            level_update(game, frametime)
            game.custom_timelines.update(game.status.get_current_tp())

            local dm_factor = get_music_dm_sync_factor()
            beat_pulse.update(frametime, dm_factor)
            pulse.update(frametime, dm_factor)

            if not game.config.get("black_and_white") then
                game.style.update(frametime, math.pow(game.difficulty_mult, 0.8))
            end

            game.player.update_position(game.status.radius)
            game.walls.update(frametime, game.status.radius)
            if
                game.walls.handle_collision(input.move, frametime, game.player, game.status.radius)
                or game.custom_walls.handle_collision(input.move, game.status.radius, game.player, frametime)
            then
                local fatal = not game.config.get("invincible") and not game.level_status.tutorial_mode
                game.player.kill(fatal)
                game.death()
            end
            game.custom_walls.update_old_vertices()
        else
            game.level_status.rotation_speed = game.level_status.rotation_speed * 0.99
        end

        pseudo3d.update(frametime)

        -- update rotation
        if game.config.get("rotation") then
            rotation.update(game, frametime)
        end
        camera_shake.update(frametime)
        if not game.status.has_died then
            game.rng.advance(math.abs(game.status.pulse))
            game.rng.advance(math.abs(game.status.pulse3D))
            game.rng.advance(math.abs(game.status.fast_spin))
            game.rng.advance(math.abs(game.status.flash_effect))
            game.rng.advance(math.abs(game.level_status.rotation_speed))
        end

        -- update trail color (also used for swap particles)
        current_trail_color[1], current_trail_color[2], current_trail_color[3] = game.style.get_player_color()
        if game.config.get("black_and_white") then
            current_trail_color[1], current_trail_color[2], current_trail_color[3] = 255, 255, 255
        else
            if game.config.get("player_trail_has_swap_color") then
                game.player.get_color_adjusted_for_swap(current_trail_color)
            else
                game.player.get_color(current_trail_color)
            end
        end
        current_trail_color[4] = game.config.get("player_trail_alpha")

        if game.config.get("show_player_trail") and game.status.show_player_trail and not args.headless then
            trail_particles.update(frametime, current_trail_color)
        end
        if game.config.get("show_swap_particles") and not args.headless then
            swap_particles.update(frametime, current_trail_color)
        end

        -- supress empty block warning for now
        --- @diagnostic disable
        if game.level_status.pseudo_3D_required and not game.config.get("3D_enabled") then
            -- TODO: invalidate score
        end
        if game.level_status.shaders_required and not game.config.get("shaders") then
            -- TODO: invalidate score
        end
        --- @diagnostic enable
    end
end

---draw the game to the current canvas
---@param screen love.Canvas
---@param frametime number
---@param preview boolean
function public.draw(screen, frametime, preview)
    -- for lua access
    game.width, game.height = screen:getDimensions()

    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / game.width, 768 / game.height)
    -- apply pulse as well
    local zoom = pulse.get_zoom(zoom_factor)
    love.graphics.scale(zoom, zoom)
    if not preview then
        camera_shake.apply()
    end
    pseudo3d.apply_skew()
    rotation.apply(game)

    local function set_render_stage(render_stage, no_shader, instanced)
        if game.config.get("shaders") then
            local shader = game.status.fragment_shaders[render_stage]
            if shader ~= nil then
                game.lua_runtime.run_fn_if_exists("onRenderStage", render_stage, frametime * 60)
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

    local black_and_white = game.config.get("black_and_white")
    if game.config.get("background") then
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
    if preview then
        game.player.draw_pivot(game.level_status.sides, game.style, pivot_quads, cap_tris, black_and_white)
    elseif game.status.started then
        game.player.draw(
            game.level_status.sides,
            game.style,
            pivot_quads,
            player_tris,
            cap_tris,
            game.config.get("player_tilt_intensity"),
            game.config.get("swap_blinking_effect"),
            black_and_white
        )
    end
    love.graphics.setColor(1, 1, 1, 1)
    pseudo3d.draw(set_render_stage, wall_quads, pivot_quads, player_tris, black_and_white)

    if not preview then
        if game.config.get("show_player_trail") and game.status.show_player_trail then
            love.graphics.setShader()
            trail_particles.draw()
        end

        if game.config.get("show_swap_particles") then
            love.graphics.setShader()
            swap_particles.draw()
        end
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
    if not preview then
        camera_shake.apply()
    end
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
    flash.draw(game.config.get("flash"), zoom_factor)
end

---get the current score
---@return number the score
---@return boolean is custom score
function public.get_score()
    if game.level_status.score_overwritten then
        -- custom score may change after death, get it again
        return game.lua_runtime.env[game.level_status.score_overwrite], true
    end
    return game.status.get_played_accumulated_frametime_in_seconds(), false
end

---gets time based score even if there is a custom score
function public.get_timed_score()
    return game.status.get_total_accumulated_frametime_in_seconds()
end

---21 specific function that gets the custom score right before death (which is used for replay verification instead of the actual one)
---@return number?
function public.get_compat_custom_score()
    return game.status.get_custom_score()
end

---returns true if the player has died
---@return boolean
function public.is_dead()
    return game.status.has_died
end

---stop the game
function public.stop()
    public.running = false
    if not args.headless and game.music ~= nil and game.music.source ~= nil then
        game.music.source:stop()
    end
end

---initialize the game
---@param data any
---@param input_handler any
---@param config any
---@param audio any
function public.init(data, input_handler, config, _, audio)
    game.input = input_handler
    assets.init(data, audio, config)
    game.config = config
    game.audio = audio
    pseudo3d.init(game)
    input.init(game, swap_particles, assets)
    camera_shake.init(game)
    if not args.headless then
        -- TODO: config may change without the game restarting (may need to reload)
        message_font = assets.get_font("OpenSquare-Regular.ttf", 32 * game.config.get("text_scale"))
        go_sound = assets.get_sound("go.ogg")
        level_up_sound = assets.get_sound("level_up.ogg")
        restart_sound = assets.get_sound("restart.ogg")
        select_sound = assets.get_sound("select.ogg")
    end
end

---draws a minimal level preview to a canvas
---@param canvas love.Canvas
---@param pack string
---@param level string
---@return table?
function public.draw_preview(canvas, pack, level)
    local pack_data = assets.get_pack_no_load(pack)
    if not pack_data then
        error("pack with id '" .. pack .. "not found")
    end
    assets.preload(pack_data)
    if pack_data.preload_promise and not pack_data.preload_promise.executed then
        return pack_data.preload_promise
    end
    game.pack_data = pack_data
    game.level_data = game.pack_data.levels[level]
    if game.level_data == nil then
        error("Error: level with id '" .. level .. "' not found")
    end
    game.level_status.reset(game.config.get("sync_music_to_dm"), assets)
    local style_data = game.pack_data.styles[game.level_data.styleId]
    if style_data == nil then
        error("Error: style with id '" .. game.level_data.styleId .. "' not found")
    end
    game.style.select(style_data)
    game.style.compute_colors()
    game.status.reset_all_data()
    game.player.reset(
        game.get_swap_cooldown(),
        game.config.get("player_size"),
        game.config.get("player_speed"),
        game.config.get("player_focus_speed")
    )
    game.player.update_position(game.status.radius)
    game.walls.reset(game.level_status)
    game.custom_walls.cw_clear()
    flash.init(game)
    game.current_rotation = 0
    local sides = pack_data.preview_side_counts[level] or 6
    if sides < 3 then
        sides = 3
    end
    game.level_status.sides = sides
    pulse.init(game)
    beat_pulse.init(game)
    game.message_text = ""
    public.draw(canvas, 0, true)
end

return public
