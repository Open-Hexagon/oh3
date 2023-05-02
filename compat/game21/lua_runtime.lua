local log = require("log")(...)
local lua_runtime = {
    env = nil,
    assets = nil,
    file_cache = {}
}

function lua_runtime:init_env(game, pack_name)
    local assets = game.assets
    local pack = assets.loaded_packs[pack_name]
    self.env = {
        print = print,
        math = math,
        u_execScript = function(path)
            self:run_lua_file(pack.path .. "/Scripts/" .. path)
        end,
        u_execDependencyScript = function(disambiguator, name, author, script)
            local pname = assets.metadata_pack_json_map[assets:_build_pack_id(disambiguator, author, name)].pack_name
            local old = self.env.u_execScript
            self.env.u_execScript = function(path)
                self:run_lua_file(assets:get_pack(pname).path .. "/Scripts/" .. path)
            end
            self:run_lua_file(assets:get_pack(pname).path .. "/Scripts/" .. script)
            self.env.u_execScript = old
        end,
        u_rndIntUpper = function(upper)
            return math.random(1, upper)
        end,
        u_getDifficultyMult = function()
            return game.difficulty_mult
        end,
        e_messageAdd = function() end,
    }
    local function make_accessors(prefix, name, t, f)
        self.env[prefix .. "_set" .. name] = function(value)
            t[f] = value
        end
        self.env[prefix .. "_get" .. name] = function()
            return t[f]
        end
    end
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
