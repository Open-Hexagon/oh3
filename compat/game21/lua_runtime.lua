local log = require("log")(...)
local lua_runtime = {
    env = nil,
    assets = nil,
    file_cache = {},
    error_sound = love.audio.newSource("assets/audio/error.ogg", "static"),
}

function lua_runtime:error(msg)
    love.audio.play(self.error_sound)
    log("Error: " .. msg)
end

function lua_runtime:init_env(game, pack_name)
    local assets = game.assets
    local pack = assets.loaded_packs[pack_name]
    self.env = {
        print = print,
        math = math,
    }
    local function make_accessors(prefix, name, t, f)
        self.env[prefix .. "_set" .. name] = function(value)
            t[f] = value
        end
        self.env[prefix .. "_get" .. name] = function()
            return t[f]
        end
    end

    -- Level functions
    make_accessors("l", "SpeedMult", game.level_status, "speed_mult")
    make_accessors("l", "PlayerSpeedMult", game.level_status, "player_speed_mult")
    make_accessors("l", "SpeedInc", game.level_status, "speed_inc")
    make_accessors("l", "SpeedMax", game.level_status, "speed_max")
    make_accessors("l", "RotationSpeed", game.level_status, "rotation_speed")
    make_accessors("l", "RotationSpeedInc", game.level_status, "rotation_speed_inc")
    make_accessors("l", "RotationSpeedMax", game.level_status, "rotation_speed_max")
    make_accessors("l", "DelayMult", game.level_status, "delay_mult")
    make_accessors("l", "DelayInc", game.level_status, "delay_inc")
    make_accessors("l", "DelayMin", game.level_status, "delay_min")
    make_accessors("l", "DelayMax", game.level_status, "delay_max")
    make_accessors("l", "FastSpin", game.level_status, "fast_spin")
    make_accessors("l", "IncTime", game.level_status, "inc_time")
    make_accessors("l", "PulseMin", game.level_status, "pulse_min")
    make_accessors("l", "PulseMax", game.level_status, "pulse_max")
    make_accessors("l", "PulseSpeed", game.level_status, "pulse_speed")
    make_accessors("l", "PulseSpeedR", game.level_status, "pulse_speed_r")
    make_accessors("l", "PulseDelayMax", game.level_status, "pulse_delay_max")
    make_accessors("l", "PulseInitialDelay", game.level_status, "pulse_initial_delay")
    make_accessors("l", "SwapCooldownMult", game.level_status, "swap_cooldown_mult")
    make_accessors("l", "BeatPulseMax", game.level_status, "beat_pulse_max")
    make_accessors("l", "BeatPulseDelayMax", game.level_status, "beat_pulse_delay_max")
    make_accessors("l", "BeatPulseInitialDelay", game.level_status, "beat_pulse_initial_delay")
    make_accessors("l", "BeatPulseSpeedMult", game.level_status, "beat_pulse_speed_mult")
    make_accessors("l", "RadiusMin", game.level_status, "radius_min")
    make_accessors("l", "WallSkewLeft", game.level_status, "wall_skew_left")
    make_accessors("l", "WallSkewRight", game.level_status, "wall_skew_right")
    make_accessors("l", "WallAngleLeft", game.level_status, "wall_angle_left")
    make_accessors("l", "WallAngleRight", game.level_status, "wall_angle_right")
    make_accessors("l", "WallSpawnDistance", game.level_status, "wall_spawn_distance")
    make_accessors("l", "3dRequired", game.level_status, "_3D_required")
    make_accessors("l", "ShadersRequired", game.level_status, "shaders_required")
    make_accessors("l", "CameraShake", game.level_status, "camera_shake")
    make_accessors("l", "Sides", game.level_status, "sides")
    make_accessors("l", "SidesMin", game.level_status, "sides_min")
    make_accessors("l", "SidesMax", game.level_status, "sides_max")
    make_accessors("l", "SwapEnabled", game.level_status, "swap_enabled")
    make_accessors("l", "TutorialMode", game.level_status, "tutorial_mode")
    make_accessors("l", "IncEnabled", game.level_status, "inc_enabled")
    make_accessors("l", "DarkenUnevenBackgroundChunk", game.level_status, "darken_uneven_background_chunk")
    make_accessors("l", "ManualPulseControl", game.level_status, "manual_pulse_control")
    make_accessors("l", "ManualBeatPulseControl", game.level_status, "manual_beat_pulse_control")
    make_accessors("l", "CurrentIncrements", game.level_status, "current_increments")
    self.env.l_addTracked = function(variable, name)
        game.level_status.tracked_variables[variable] = name
    end
    self.env.l_removeTracked = function(variable)
        game.level_status.tracked_variables[variable] = nil
    end
    self.env.l_clearTracked = function()
        game.level_status.tracked_variables = {}
    end
    self.env.l_getLevelTime = function()
        return game.status:get_time_seconds()
    end
    self.env.l_resetTime = function()
        game.status:resetTime()
    end
    make_accessors("l", "Pulse", game.status, "pulse")
    make_accessors("l", "PulseDirection", game.status, "pulse_direction")
    make_accessors("l", "PulseDelay", game.status, "pulse_delay")
    make_accessors("l", "BeatPulse", game.status, "beat_pulse")
    make_accessors("l", "BeatPulseDelay", game.status, "beat_pulse_delay")
    make_accessors("l", "ShowPlayerTrail", game.status, "show_player_trail")
    make_accessors("l", "CameraShake", game.status, "camera_shake")
    self.env.l_getOfficial = function()
        -- TODO
        return false
    end

    -- Style functions
    make_accessors("s", "HueMin", game.style, "hue_min")
    make_accessors("s", "HueMax", game.style, "hue_max")
    make_accessors("s", "HueInc", game.style, "hue_inc")
    make_accessors("s", "HueIncrement", game.style, "hue_increment")
    make_accessors("s", "PulseMin", game.style, "pulse_min")
    make_accessors("s", "PulseMax", game.style, "pulse_max")
    make_accessors("s", "PulseInc", game.style, "pulse_inc")
    make_accessors("s", "PulseIncrement", game.style, "pulse_increment")
    make_accessors("s", "HuePingPong", game.style, "hue_ping_pong")
    make_accessors("s", "MaxSwapTime", game.style, "max_swap_time")
    make_accessors("s", "3dDepth", game.style, "_3D_depth")
    make_accessors("s", "3dSkew", game.style, "_3D_skew")
    make_accessors("s", "3dSpacing", game.style, "_3D_spacing")
    make_accessors("s", "3dDarkenMult", game.style, "_3D_darken_mult")
    make_accessors("s", "3dAlphaMult", game.style, "_3D_alpha_mult")
    make_accessors("s", "3dAlphaFalloff", game.style, "_3D_alpha_falloff")
    make_accessors("s", "3dPulseMax", game.style, "_3D_pulse_max")
    make_accessors("s", "3dPulseMin", game.style, "_3D_pulse_min")
    make_accessors("s", "3dPulseSpeed", game.style, "_3D_pulse_speed")
    make_accessors("s", "3dPerspectiveMult", game.style, "_3D_perspective_mult")
    make_accessors("s", "BGTileRadius", game.style, "bg_tile_radius")
    make_accessors("s", "BGColorOffset", game.style, "bg_color_offset")
    make_accessors("s", "BGRotationOffset", game.style, "bg_rot_off")
    self.env.s_setCapColorMain = function()
        game.style._cap_color = 1
    end
    self.env.s_setCapColorMainDarkened = function()
        game.style._cap_color = 2
    end
    self.env.s_setCapColorByIndex = function(index)
        game.style._cap_color = 4 + index
    end
    self.env.s_getMainColor = function()
        return game.style:get_main_color()
    end
    self.env.s_getPlayerColor = function()
        return game.style:get_player_color()
    end
    self.env.s_getTextColor = function()
        return game.style:get_text_color()
    end
    self.env.s_get3DOverrideColor = function()
        return game.style:get_3D_override_color()
    end
    self.env.s_getCapColorResult = function()
        return game.style:get_cap_color_result()
    end
    self.env.s_getColor = function(index)
        return game.style:get_color(index)
    end
    self.env.s_setStyle = function(style_id)
        local style_data = pack.styles[style_id]
        if style_data == nil then
            self:error("Trying to load an invalid style '" .. style_id .. "'")
        else
            game.style:select(style_data)
            game.style:compute_colors()
        end
    end

    -- Audio functions
    self.env.a_setMusic = function(music_id)
        self.env.a_setMusicSegment(music_id, 0)
    end
    self.env.a_setMusicSegment = function(music_id, segment)
        local music = game.pack_data.music[music_id]
        if music == nil then
            self:error("Music with id '" .. music_id .. "' doesn't exist!")
        else
            game.music = music
            game:refresh_music_pitch()
            game.music.source:seek(self.music.segments[segment + 1])
        end
    end
    self.env.a_setMusicSeconds = function(music_id, seconds)
        local music = game.pack_data.music[music_id]
        if music == nil then
            self:error("Music with id '" .. music_id .. "' doesn't exist!")
        else
            game.music = music
            game:refresh_music_pitch()
            game.music.source:seek(seconds)
        end
    end
    self.env.a_playSound = function(sound_id)
        local sound = assets:get_sound(sound_id)
        if sound == nil then
            self:error("Sound with id '" .. sound_id .. "' doesn't exist!")
        else
            love.audio.play(sound)
        end
    end
    local function get_pack_sound(sound_id, cb)
        local sound = assets:get_pack_sound(pack, sound_id)
        if sound == nil then
            self:error("Pack Sound with id '" .. sound_id .. "' doesn't exist!")
        else
            return sound
        end
    end
    self.env.a_playPackSound = function(sound_id)
        local sound = get_pack_sound(sound_id)
        if sound ~= nil then
            love.audio.play(sound)
        end
    end
    self.env.a_syncMusicToDM = function(value)
        game.level_status.sync_music_to_dm = value
    end
    self.env.a_setMusicPitch = function(pitch)
        game.level_status.music_pitch = pitch
        game:refresh_music_pitch()
    end
    self.env.a_overrideBeepSound = function(filename)
        game.level_status.beep_sound = get_pack_sound(filename) or game.level_status.beep_sound
    end
    self.env.a_overrideIncrementSound = function(filename)
        game.level_status.level_up_sound = get_pack_sound(filename) or game.level_status.level_up_sound
    end
    self.env.a_overrideSwapSound = function(filename)
        game.level_status.swap_sound = get_pack_sound(filename) or game.level_status.swap_sound
    end
    self.env.a_overrideDeathSound = function(filename)
        game.level_status.death_sound = get_pack_sound(filename) or game.level_status.death_sound
    end

    -- Main timeline functions
    self.env.t_eval = function(code)
        local fn = loadstring(code)
        setfenv(fn, self.env)
        game.main_timeline:append_do(fn)
    end
    self.env.t_clear = function()
        game.main_timeline:clear()
    end
    self.env.t_kill = function()
        -- TODO
    end
    self.env.t_wait = function(duration)
        game.main_timeline:append_wait_for_sixths(duration)
    end
    self.env.t_waitS = function(duration)
        game.main_timeline:append_wait_for_seconds(duration)
    end
    self.env.t_waitUntilS = function(time)
        game.main_timeline:append_wait_for_until_fn(function()
            return game.status:get_level_start_tp() + time * 1000
        end)
    end

    -- Event timeline functions
    self.env.e_eval = function(code)
        local fn = loadstring(code)
        setfenv(fn, self.env)
        game.event_timeline:append_do(fn)
    end
    self.env.e_kill = function()
        -- TODO
    end
    self.env.e_stopTime = function(duration)
        game.event_timeline:append_do(function()
            game.status:pause_time(duration / 60)
        end)
    end
    self.env.e_stopTimeS = function(duration)
        game.event_timeline:append_do(function()
            game.status:pause_time(duration)
        end)
    end
    self.env.e_wait = function(duration)
        game.event_timeline:append_wait_for_sixths(duration)
    end
    self.env.e_waitS = function(duration)
        game.event_timeline:append_wait_for_seconds(duration)
    end
    self.env.e_waitUntilS = function(time)
        game.event_timeline:append_wait_until_fn(function()
            return game.status:get_level_start_tp() + time * 1000
        end)
    end
    local function add_message(message, duration, sound_toggle)
        -- TODO: don't do anything if messages disabled in config
        game.message_timeline:append_do(function()
            if sound_toggle then
                love.audio.play(game.level_status.beep_sound)
            end
            game.message_text = message:upper()
        end)
        game.message_timeline:append_wait_for_sixths(duration)
        game.message_timeline:append_do(function()
            game.message_text = ""
        end)
    end
    self.env.e_messageAdd = function(message, duration)
        game.event_timeline:append_do(function()
            add_message(message, duration, true)
        end)
    end
    self.env.e_messageAddImportant = function(message, duration)
        game.event_timeline:append_do(function()
            if game.first_play then
                add_message(message, duration, true)
            end
        end)
    end
    self.env.e_messageAddImportantSilent = function(message, duration)
        game.event_timeline:append_do(function()
            if game.first_play then
                add_message(message, duration, false)
            end
        end)
    end
    self.env.e_clearMessages = function()
        -- yes the game really does not do this with the event timeline like all the other e_ functions
        game.message_timeline:clear()
    end

    -- Utility functions
    self.env.u_rndReal = function()
        -- u_rndReal = math.random wouldn't ignore args
        return math.random()
    end
    self.env.u_rndIntUpper = function(upper)
        return math.random(1, upper)
    end
    self.env.u_rndInt = function(lower, upper)
        return math.random(lower, upper)
    end
    self.env.u_rndSwitch = function(mode, lower, upper)
        if mode == 0 then
            return math.random()
        elseif mode == 1 then
            return math.random(1, upper)
        elseif mode == 2 then
            return math.random(lower, upper)
        end
        return 0
    end
    self.env.u_getAttemptRandomSeed = function()
        return game.seed
    end
    self.env.u_inMenu = function()
        -- the lua env shouldn't be active in the menu?
        return false
    end
    -- pretend to be the current newest version (2.1.7)
    self.env.u_getVersionMajor = function()
        return 2
    end
    self.env.u_getVersionMinor = function()
        return 1
    end
    self.env.u_getVersionMicro = function()
        return 7
    end
    self.env.u_getVersionString = function()
        return "2.1.7"
    end
    self.env.u_execScript = function(path)
        self:run_lua_file(pack.path .. "/Scripts/" .. path)
    end
    self.env.u_execDependencyScript = function(disambiguator, name, author, script)
        local pname = assets.metadata_pack_json_map[assets:_build_pack_id(disambiguator, author, name)].pack_name
        local old = self.env.u_execScript
        self.env.u_execScript = function(path)
            self:run_lua_file(assets:get_pack(pname).path .. "/Scripts/" .. path)
        end
        self:run_lua_file(assets:get_pack(pname).path .. "/Scripts/" .. script)
        self.env.u_execScript = old
    end
    self.env.u_getWidth = function()
        return game.height
    end
    self.env.u_getHeight = function()
        return game.width
    end
    self.env.u_setFlashEffect = function(value)
        game.status.flash_effect = value
    end
    self.env.u_setFlashColor = function(r, g, b)
        -- TODO: init flash effect with r, g, b
    end
    self.env.u_log = function(message)
        log("[lua] " .. message)
    end
    self.env.u_isKeyPressed = function(key)
        -- TODO: this won't work, will need sfml keycode -> love key string conversion
        return love.keyboard.isDown(key)
    end
    self.env.u_haltTime = function(duration)
        game.status:pauseTime(duration / 60)
    end
    self.env.u_clearWalls = function()
        game.walls:clear()
    end
    self.env.u_getPlayerAngle = function()
        return game.player:get_player_angle()
    end
    self.env.u_setPlayerAngle = function(angle)
        return game.player:set_player_angle(angle)
    end
    self.env.u_isMouseButtonPressed = function(button)
        -- TODO: check if sfml button numbers correspond to love ones
        return love.mouse.isDown(button)
    end
    self.env.u_isFastSpinning = function()
        return game.status.fast_spin > 0
    end
    self.env.u_forceIncrement = function()
        game:increment_difficulty()
    end
    self.env.u_getDifficultyMult = function()
        return game.difficulty_mult
    end
    self.env.u_getSpeedMultDM = function()
        return game:get_speed_mult_dm()
    end
    self.env.u_getDelayMultDM = function()
        local result = game.level_status.delay_mult * math.pow(game.difficulty_mult, 0.1)
        if not game.level_status:has_delay_max_limit() then
            return result
        end
        return result < game.level_status.delay_max and result or game.level_status.delay_max
    end
    self.env.u_swapPlayer = function(play_sound)
        game:perform_player_swap(play_sound)
    end
    -- deprecated functions
    self.env.u_playSound = self.env.a_playSound
    self.env.u_playPackSound = self.env.a_playPackSound
    -- TODO: u_kill, u_eventKill (needs timeline)

    local function wall(
        hue_modifier,
        side,
        thickness,
        speed_mult,
        acceleration,
        min_speed,
        max_speed,
        ping_pong,
        curving
    )
        game.main_timeline:append_do(function()
            game.walls:wall(
                game:get_speed_mult_dm(),
                game.difficulty_mult,
                hue_modifier,
                side,
                thickness,
                speed_mult,
                acceleration,
                min_speed,
                max_speed,
                ping_pong,
                curving
            )
        end)
    end
    self.env.w_wall = function(side, thickness)
        wall(0, side, thickness)
    end
    self.env.w_wallAdj = function(side, thickness, speed_mult)
        wall(0, side, thickness, speed_mult)
    end
    self.env.w_wallAcc = function(side, thickness, speed_mult, acceleration, min_speed, max_speed)
        wall(0, side, thickness, speed_mult, acceleration, min_speed, max_speed)
    end
    self.env.w_wallModSpeedData = function(
        hue_modifier,
        side,
        thickness,
        speed_mult,
        acceleration,
        min_speed,
        max_speed,
        ping_pong
    )
        wall(hue_modifier, side, thickness, speed_mult, acceleration, min_speed, max_speed, ping_pong)
    end
    self.env.w_wallModCurveData = function(
        hue_modifier,
        side,
        thickness,
        speed_mult,
        acceleration,
        min_speed,
        max_speed,
        ping_pong
    )
        wall(hue_modifier, side, thickness, speed_mult, acceleration, min_speed, max_speed, ping_pong, true)
    end

    -- Miscellaneous functions
    self.env.steam_unlockAchievement = function(achievement)
        self:error("Attempt to unlock steam achievement '" .. achievement .. "' in compat mode")
    end
    log("initialized environment")
end

function lua_runtime:run_lua_file(path)
    if self.env == nil then
        error("attempted to load a lua file without initializing the environment")
    else
        if self.file_cache[path] == nil then
            self.file_cache[path] = loadfile(path)
        end
        local lua_file = self.file_cache[path]
        setfenv(lua_file, self.env)
        lua_file()
    end
end

return lua_runtime
