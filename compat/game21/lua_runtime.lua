local log = require("log")(...)
local lua_runtime = {
    env = {},
}

local error_sound
local file_cache = {}
local env = lua_runtime.env
local keycode_conversion = {
    [0] = "a",
    [1] = "b",
    [2] = "c",
    [3] = "d",
    [4] = "e",
    [5] = "f",
    [6] = "g",
    [7] = "h",
    [8] = "i",
    [9] = "j",
    [10] = "k",
    [11] = "l",
    [12] = "m",
    [13] = "n",
    [14] = "o",
    [15] = "p",
    [16] = "q",
    [17] = "r",
    [18] = "s",
    [19] = "t",
    [20] = "u",
    [21] = "v",
    [22] = "w",
    [23] = "x",
    [24] = "y",
    [25] = "z",
    [26] = "0",
    [27] = "1",
    [28] = "2",
    [29] = "3",
    [30] = "4",
    [31] = "5",
    [32] = "6",
    [33] = "7",
    [34] = "8",
    [35] = "9",
    [36] = "escape",
    [37] = "lctrl",
    [38] = "lshift",
    [39] = "lalt",
    [40] = "lgui",
    [41] = "rctrl",
    [42] = "rshift",
    [43] = "ralt",
    [44] = "rgui",
    [45] = "menu",
    [46] = "(",
    [47] = ")",
    [48] = ";",
    [49] = ",",
    [50] = ".",
    [51] = "'",
    [52] = "/",
    [53] = "\\",
    [54] = "~",
    [55] = "=",
    [56] = "-",
    [57] = "space",
    [58] = "return",
    [59] = "backspace",
    [60] = "tab",
    [61] = "pageup",
    [62] = "pagedown",
    [63] = "end",
    [64] = "home",
    [65] = "insert",
    [66] = "delete",
    [67] = "+",
    [68] = "-",
    [69] = "*",
    [70] = "/",
    [71] = "left",
    [72] = "right",
    [73] = "up",
    [74] = "down",
    [75] = "kp0",
    [76] = "kp1",
    [77] = "kp2",
    [78] = "kp3",
    [79] = "kp4",
    [80] = "kp5",
    [81] = "kp6",
    [82] = "kp7",
    [83] = "kp8",
    [84] = "kp9",
    [85] = "f1",
    [86] = "f2",
    [87] = "f3",
    [88] = "f4",
    [89] = "f5",
    [90] = "f6",
    [91] = "f7",
    [92] = "f8",
    [93] = "f9",
    [94] = "f10",
    [95] = "f11",
    [96] = "f12",
    [97] = "f13",
    [98] = "f14",
    [99] = "f15",
    [100] = "pause",
}

function lua_runtime.error(msg)
    love.audio.play(error_sound)
    log("Error: " .. msg)
end

function lua_runtime.init_env(game, public)
    local pack = game.pack_data
    local assets = public.assets
    error_sound = assets.get_sound("error.ogg")
    lua_runtime.env = {
        next = next,
        error = error,
        assert = assert,
        pcall = pcall,
        xpcall = xpcall,
        tonumber = tonumber,
        coroutine = coroutine,
        unpack = unpack,
        table = table,
        getmetatable = getmetatable,
        setmetatable = setmetatable,
        type = type,
        string = string,
        ipairs = ipairs,
        pairs = pairs,
        print = print,
        math = math,
    }
    env = lua_runtime.env
    env._G = env
    local function make_accessors(prefix, name, t, f)
        env[prefix .. "_set" .. name] = function(value)
            t[f] = value
        end
        env[prefix .. "_get" .. name] = function()
            return t[f]
        end
    end
    local function make_accessor(prefix, name, t, f)
        env[prefix .. "_" .. name] = function(value)
            t[f] = value
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
    make_accessors("l", "3dRequired", game.level_status, "pseudo_3D_required")
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
    make_accessor("l", "enableRndSideChanges", game.level_status, "rnd_side_changes_enabled")
    env.l_addTracked = function(variable, name)
        game.level_status.tracked_variables[variable] = name
    end
    env.l_removeTracked = function(variable)
        game.level_status.tracked_variables[variable] = nil
    end
    env.l_clearTracked = function()
        game.level_status.tracked_variables = {}
    end
    env.l_getLevelTime = function()
        return game.status.get_time_seconds()
    end
    env.l_resetTime = function()
        game.status.resetTime()
    end
    make_accessors("l", "Pulse", game.status, "pulse")
    make_accessors("l", "PulseDirection", game.status, "pulse_direction")
    make_accessors("l", "PulseDelay", game.status, "pulse_delay")
    make_accessors("l", "BeatPulse", game.status, "beat_pulse")
    make_accessors("l", "BeatPulseDelay", game.status, "beat_pulse_delay")
    make_accessors("l", "ShowPlayerTrail", game.status, "show_player_trail")
    make_accessors("l", "Rotation", game, "current_rotation")
    env.l_overrideScore = function(variable)
        game.level_status.score_overwrite = variable
        game.level_status.score_overwritten = true
        if type(env[variable]) ~= "number" then
            lua_runtime.error("Score override must be a number value")
        end
    end
    env.l_getOfficial = function()
        return public.config.get("official_mode")
    end

    -- Style functions
    make_accessors("s", "HueMin", game.style, "hue_min")
    make_accessors("s", "HueMax", game.style, "hue_max")
    make_accessors("s", "HueInc", game.style, "hue_increment")
    make_accessors("s", "HueIncrement", game.style, "hue_increment")
    make_accessors("s", "PulseMin", game.style, "pulse_min")
    make_accessors("s", "PulseMax", game.style, "pulse_max")
    make_accessors("s", "PulseInc", game.style, "pulse_increment")
    make_accessors("s", "PulseIncrement", game.style, "pulse_increment")
    make_accessors("s", "HuePingPong", game.style, "hue_ping_pong")
    make_accessors("s", "MaxSwapTime", game.style, "max_swap_time")
    make_accessors("s", "3dDepth", game.style, "pseudo_3D_depth")
    make_accessors("s", "3dSkew", game.style, "pseudo_3D_skew")
    make_accessors("s", "3dSpacing", game.style, "pseudo_3D_spacing")
    make_accessors("s", "3dDarkenMult", game.style, "pseudo_3D_darken_mult")
    make_accessors("s", "3dAlphaMult", game.style, "pseudo_3D_alpha_mult")
    make_accessors("s", "3dAlphaFalloff", game.style, "pseudo_3D_alpha_falloff")
    make_accessors("s", "3dPulseMax", game.style, "pseudo_3D_pulse_max")
    make_accessors("s", "3dPulseMin", game.style, "pseudo_3D_pulse_min")
    make_accessors("s", "3dPulseSpeed", game.style, "pseudo_3D_pulse_speed")
    make_accessors("s", "3dPerspectiveMult", game.style, "pseudo_3D_perspective_mult")
    make_accessors("s", "BGTileRadius", game.style, "bg_tile_radius")
    make_accessors("s", "BGColorOffset", game.style, "bg_color_offset")
    make_accessors("s", "BGRotationOffset", game.style, "bg_rot_off")
    env.s_setCapColorMain = function()
        game.style.set_cap_color(1)
    end
    env.s_setCapColorMainDarkened = function()
        game.style.set_cap_color(2)
    end
    env.s_setCapColorByIndex = function(index)
        game.style.set_cap_color(4 + index)
    end
    env.s_getMainColor = function()
        return game.style.get_main_color()
    end
    env.s_getPlayerColor = function()
        return game.style.get_player_color()
    end
    env.s_getTextColor = function()
        return game.style.get_text_color()
    end
    env.s_get3DOverrideColor = function()
        return game.style.get_3D_override_color()
    end
    env.s_getCapColorResult = function()
        return game.style.get_cap_color_result()
    end
    env.s_getColor = function(index)
        return game.style.get_color(index)
    end
    env.s_setStyle = function(style_id)
        local style_data = pack.styles[style_id]
        if style_data == nil then
            lua_runtime.error("Trying to load an invalid style '" .. style_id .. "'")
        else
            game.style.select(style_data)
            game.style.compute_colors()
        end
    end

    -- Audio functions
    env.a_setMusic = function(music_id)
        env.a_setMusicSegment(music_id, 0)
    end
    env.a_setMusicSegment = function(music_id, segment)
        local music = game.pack_data.music[music_id]
        if music == nil then
            lua_runtime.error("Music with id '" .. music_id .. "' doesn't exist!")
        else
            game.music = music
            game.refresh_music_pitch()
            game.music.source:seek(game.music.segments[segment + 1].time)
        end
    end
    env.a_setMusicSeconds = function(music_id, seconds)
        local music = game.pack_data.music[music_id]
        if music == nil then
            lua_runtime.error("Music with id '" .. music_id .. "' doesn't exist!")
        else
            game.music = music
            game.refresh_music_pitch()
            game.music.source:seek(seconds)
        end
    end
    env.a_playSound = function(sound_id)
        local sound = assets.get_sound(sound_id)
        if sound == nil then
            lua_runtime.error("Sound with id '" .. sound_id .. "' doesn't exist!")
        else
            love.audio.play(sound)
        end
    end
    local function get_pack_sound(sound_id)
        local sound = assets.get_pack_sound(pack, sound_id)
        if sound == nil then
            lua_runtime.error("Pack Sound with id '" .. sound_id .. "' doesn't exist!")
        else
            return sound
        end
    end
    env.a_playPackSound = function(sound_id)
        local sound = get_pack_sound(sound_id)
        if sound ~= nil then
            love.audio.play(sound)
        end
    end
    env.a_syncMusicToDM = function(value)
        game.level_status.sync_music_to_dm = value
    end
    env.a_setMusicPitch = function(pitch)
        game.level_status.music_pitch = pitch
        game.refresh_music_pitch()
    end
    env.a_overrideBeepSound = function(filename)
        game.level_status.beep_sound = get_pack_sound(filename) or game.level_status.beep_sound
    end
    env.a_overrideIncrementSound = function(filename)
        game.level_status.level_up_sound = get_pack_sound(filename) or game.level_status.level_up_sound
    end
    env.a_overrideSwapSound = function(filename)
        game.level_status.swap_sound = get_pack_sound(filename) or game.level_status.swap_sound
    end
    env.a_overrideDeathSound = function(filename)
        game.level_status.death_sound = get_pack_sound(filename) or game.level_status.death_sound
    end

    -- Main timeline functions
    env.t_eval = function(code)
        local fn = loadstring(code)
        setfenv(fn, env)
        game.main_timeline:append_do(fn)
    end
    env.t_clear = function()
        game.main_timeline:clear()
    end
    env.t_kill = function()
        game.main_timeline:append_do(function()
            game.death(true)
        end)
    end
    env.t_wait = function(duration)
        game.main_timeline:append_wait_for_sixths(duration)
    end
    env.t_waitS = function(duration)
        game.main_timeline:append_wait_for_seconds(duration)
    end
    env.t_waitUntilS = function(time)
        game.main_timeline:append_wait_until_fn(function()
            return game.status.get_level_start_tp() + time * 1000
        end)
    end

    -- Event timeline functions
    env.e_eval = function(code)
        local fn = loadstring(code)
        setfenv(fn, env)
        game.event_timeline:append_do(fn)
    end
    env.e_kill = function()
        game.event_timeline:append_do(function()
            game.death(true)
        end)
    end
    env.e_stopTime = function(duration)
        game.event_timeline:append_do(function()
            game.status.pause_time(duration / 60)
        end)
    end
    env.e_stopTimeS = function(duration)
        game.event_timeline:append_do(function()
            game.status.pause_time(duration)
        end)
    end
    env.e_wait = function(duration)
        game.event_timeline:append_wait_for_sixths(duration)
    end
    env.e_waitS = function(duration)
        game.event_timeline:append_wait_for_seconds(duration)
    end
    env.e_waitUntilS = function(time)
        game.event_timeline:append_wait_until_fn(function()
            return game.status.get_level_start_tp() + time * 1000
        end)
    end
    local function add_message(message, duration, sound_toggle)
        if public.config.get("messages") then
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
    end
    env.e_messageAdd = function(message, duration)
        game.event_timeline:append_do(function()
            add_message(message, duration, true)
        end)
    end
    env.e_messageAddImportant = function(message, duration)
        game.event_timeline:append_do(function()
            if game.first_play then
                add_message(message, duration, true)
            end
        end)
    end
    env.e_messageAddImportantSilent = function(message, duration)
        game.event_timeline:append_do(function()
            if game.first_play then
                add_message(message, duration, false)
            end
        end)
    end
    env.e_clearMessages = function()
        -- yes the game really does not do this with the event timeline like all the other e_ functions
        game.message_timeline:clear()
    end

    -- Utility functions
    env.u_isHeadless = function()
        return false
    end
    env.u_rndReal = function()
        -- u_rndReal = math.random wouldn't ignore args
        return math.random()
    end
    env.u_rndIntUpper = function(upper)
        return math.random(1, upper)
    end
    env.u_rndInt = function(lower, upper)
        return math.random(lower, upper)
    end
    env.u_rndSwitch = function(mode, lower, upper)
        if mode == 0 then
            return math.random()
        elseif mode == 1 then
            return math.random(1, upper)
        elseif mode == 2 then
            return math.random(lower, upper)
        end
        return 0
    end
    env.u_getAttemptRandomSeed = function()
        return game.seed
    end
    env.u_inMenu = function()
        -- the lua env shouldn't be active in the menu?
        return false
    end
    -- pretend to be the current newest version (2.1.7)
    env.u_getVersionMajor = function()
        return 2
    end
    env.u_getVersionMinor = function()
        return 1
    end
    env.u_getVersionMicro = function()
        return 7
    end
    env.u_getVersionString = function()
        return "2.1.7"
    end
    env.u_execScript = function(path)
        lua_runtime.run_lua_file(pack.path .. "/Scripts/" .. path)
    end
    env.u_execDependencyScript = function(disambiguator, name, author, script)
        local dependency_pack = assets.get_pack_from_metadata(disambiguator, author, name)
        local old = env.u_execScript
        env.u_execScript = function(path)
            lua_runtime.run_lua_file(dependency_pack.path .. "/Scripts/" .. path)
        end
        lua_runtime.run_lua_file(dependency_pack.path .. "/Scripts/" .. script)
        env.u_execScript = old
    end
    env.u_getWidth = function()
        return game.width
    end
    env.u_getHeight = function()
        return game.height
    end
    env.u_setFlashEffect = function(value)
        game.status.flash_effect = value
    end
    env.u_setFlashColor = function(r, g, b)
        game.flash_color[1] = r
        game.flash_color[2] = g
        game.flash_color[3] = b
    end
    env.u_log = function(message)
        log("[lua] " .. message)
    end
    env.u_isKeyPressed = function(key_code)
        local key = keycode_conversion[key_code]
        if key == nil then
            lua_runtime.error("Could not find key with sfml keycode '" .. key_code .. "'!")
            return false
        end
        return love.keyboard.isDown(key)
    end
    env.u_haltTime = function(duration)
        game.status.pause_time(duration / 60)
    end
    env.u_clearWalls = function()
        game.walls.clear()
    end
    env.u_getPlayerAngle = function()
        return game.player.get_player_angle()
    end
    env.u_setPlayerAngle = function(angle)
        return game.player.set_player_angle(angle)
    end
    env.u_isMouseButtonPressed = function(button)
        return love.mouse.isDown(button)
    end
    env.u_isFastSpinning = function()
        return game.status.fast_spin > 0
    end
    env.u_forceIncrement = function()
        game.increment_difficulty()
    end
    env.u_getDifficultyMult = function()
        return game.difficulty_mult
    end
    env.u_getSpeedMultDM = function()
        return game.get_speed_mult_dm()
    end
    env.u_getDelayMultDM = function()
        local result = game.level_status.delay_mult / math.pow(game.difficulty_mult, 0.1)
        if not game.level_status.has_delay_max_limit() then
            return result
        end
        return result < game.level_status.delay_max and result or game.level_status.delay_max
    end
    env.u_swapPlayer = function(play_sound)
        game.perform_player_swap(play_sound)
    end

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
            game.walls.wall(
                game.get_speed_mult_dm(),
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
    env.w_wall = function(side, thickness)
        wall(0, side, thickness)
    end
    env.w_wallAdj = function(side, thickness, speed_mult)
        wall(0, side, thickness, speed_mult)
    end
    env.w_wallAcc = function(side, thickness, speed_mult, acceleration, min_speed, max_speed)
        wall(0, side, thickness, speed_mult, acceleration, min_speed, max_speed)
    end
    env.w_wallHModSpeedData = function(
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
    env.w_wallHModCurveData = function(
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

    -- Custom timeline functions
    game.custom_timelines.add_lua_functions(game)

    -- Custom wall functions
    for name, fn in pairs(game.custom_walls) do
        if name:sub(1, 3) == "cw_" then
            env[name] = fn
        end
    end

    -- Shader functions
    local shaders = {}
    local loaded_filenames = {}
    local function get_shader_id(pack_data, filename)
        local loaded_pack_shaders = loaded_filenames[pack_data.path]
        if loaded_pack_shaders ~= nil and loaded_pack_shaders[filename] ~= nil then
            return loaded_pack_shaders[filename]
        else
            local shader = pack_data.shaders[filename]
            if shader == nil then
                lua_runtime.error("Shader '" .. filename .. "' does not exist!")
                return -1
            else
                local id = #shaders + 1
                shaders[id] = shader
                loaded_filenames[pack_data.path] = loaded_filenames[pack_data.path] or {}
                loaded_filenames[pack_data.path][filename] = id
                return id
            end
        end
    end
    env.shdr_getShaderId = function(filename)
        return get_shader_id(pack, filename)
    end
    env.shdr_getDependencyShaderId = function(disambiguator, name, author, filename)
        return get_shader_id(assets.get_pack_from_metadata(disambiguator, author, name), filename)
    end

    local function check_valid_shader_id(id)
        if id < 0 or id > #shaders then
            lua_runtime.error("Invalid shader id: '" .. id .. "'")
            return false
        end
        return true
    end
    local function set_uniform(id, uniform_type, name, value)
        if check_valid_shader_id(id) then
            local shader_type = shaders[id].uniforms[name]
            -- would be nil if uniform didn't exist (not printing errors because of spam)
            if shader_type ~= nil then
                if shader_type == uniform_type then
                    shaders[id].shader:send(name, value)
                    shaders[id].instance_shader:send(name, value)
                    shaders[id].text_shader:send(name, value)
                else
                    lua_runtime.error(
                        "Uniform type '"
                            .. uniform_type
                            .. "' does not match the type in the shader '"
                            .. shader_type
                            .. "'"
                    )
                end
            end
        end
    end
    -- making sure we don't need to create new tables all the time
    local uniform_value = {}
    env.shdr_setUniformF = function(id, name, a)
        set_uniform(id, "float", name, a or 0)
    end
    env.shdr_setUniformFVec2 = function(id, name, a, b)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        set_uniform(id, "vec2", name, uniform_value)
    end
    env.shdr_setUniformFVec3 = function(id, name, a, b, c)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        uniform_value[3] = c or 0
        set_uniform(id, "vec3", name, uniform_value)
    end
    env.shdr_setUniformFVec4 = function(id, name, a, b, c, d)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        uniform_value[3] = c or 0
        uniform_value[4] = d or 0
        set_uniform(id, "vec4", name, uniform_value)
    end
    env.shdr_setUniformI = function(id, name, a)
        set_uniform(id, "int", name, a or 0)
    end
    env.shdr_setUniformIVec2 = function(id, name, a, b)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        set_uniform(id, "vec2", name, uniform_value)
    end
    env.shdr_setUniformIVec3 = function(id, name, a, b, c)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        uniform_value[3] = c or 0
        set_uniform(id, "vec3", name, uniform_value)
    end
    env.shdr_setUniformIVec4 = function(id, name, a, b, c, d)
        uniform_value[1] = a or 0
        uniform_value[2] = b or 0
        uniform_value[3] = c or 0
        uniform_value[4] = d or 0
        set_uniform(id, "vec4", name, uniform_value)
    end
    env.shdr_resetAllActiveFragmentShaders = function()
        for i = 0, 8 do
            game.status.fragment_shaders[i] = nil
        end
    end
    local function check_valid_render_stage(render_stage)
        if render_stage < 0 or render_stage > 8 then
            lua_runtime.error("Invalid render_stage '" .. render_stage .. "'")
            return false
        end
        return true
    end
    env.shdr_resetActiveFragmentShader = function(render_stage)
        render_stage = render_stage or 0
        if check_valid_render_stage(render_stage) then
            game.status.fragment_shaders[render_stage] = nil
        end
    end
    env.shdr_setActiveFragmentShader = function(render_stage, id)
        render_stage = render_stage or 0
        if check_valid_render_stage(render_stage) and check_valid_shader_id(id) then
            game.status.fragment_shaders[render_stage] = shaders[id]
        end
    end

    -- Miscellaneous functions
    env.steam_unlockAchievement = function(achievement)
        lua_runtime.error("Attempt to unlock steam achievement '" .. achievement .. "' in compat mode")
    end

    -- make sure no malicious code is required in
    local safe_modules = {
        ["bit"] = true,
    }
    env.require = function(modname)
        if safe_modules[modname] then
            return require(modname)
        else
            lua_runtime.error("Script attempted to require potentially dangerous module: '" .. modname .. "'")
        end
    end

    -- restrict io operations
    env.io = {
        open = function(filename, mode)
            return io.open(filename, mode == "rb" and mode or "r")
        end,
    }
    log("initialized environment")
end

local function run_fn(name, ...)
    return env[name](...)
end

function lua_runtime.run_fn_if_exists(name, ...)
    if env[name] ~= nil then
        xpcall(run_fn, lua_runtime.error, name, ...)
    end
end

function lua_runtime.run_lua_file(path)
    if env == nil then
        error("attempted to load a lua file without initializing the environment")
    else
        if file_cache[path] == nil then
            local error_msg
            file_cache[path], error_msg = love.filesystem.load(path)
            if file_cache[path] == nil then
                error("Failed to load '" .. path .. "': " .. error_msg)
            end
        end
        local lua_file = file_cache[path]
        setfenv(lua_file, env)
        lua_file()
    end
end

return lua_runtime
