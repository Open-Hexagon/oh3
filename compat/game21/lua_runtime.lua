local log = require("log")(...)
local lua_runtime = {
    env = nil,
    assets = nil,
    file_cache = {}
}

function lua_runtime:init_env(game, pack_name)
    local assets = game.assets
    local pack = assets.loaded_packs[pack_name]
    log("initializing environment...")
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
        l_setBeatPulseMax = function() end,
        l_setBeatPulseDelayMax = function() end,
        l_setBeatPulseSpeedMult = function() end,
        e_messageAdd = function() end,
        l_getLevelTime = function()
            return 0
        end,
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
    make_accessors("l", "Sides", game.level_status, "sides")
    make_accessors("l", "SidesMin", game.level_status, "sides_min")
    make_accessors("l", "SidesMax", game.level_status, "sides_max")
    make_accessors("l", "IncTime", game.level_status, "inc_time")
    make_accessors("l", "PulseMin", game.level_status, "pulse_min")
    make_accessors("l", "PulseMax", game.level_status, "pulse_max")
    make_accessors("l", "PulseSpeed", game.level_status, "pulse_speed")
    make_accessors("l", "PulseSpeedR", game.level_status, "pulse_speed_r")
    make_accessors("l", "PulseDelayMax", game.level_status, "pulse_delay_max")
    make_accessors("l", "PulseInitialDelay", game.level_status, "pulse_initial_delay")
    make_accessors("l", "BeatPulseMax", game.level_status, "beat_pulse_max")
    make_accessors("l", "BeatPulseDelayMax", game.level_status, "beat_pulse_delay_max")
    make_accessors("l", "BeatPulseInitialDelay", game.level_status, "beat_pulse_initial_delay")
    make_accessors("l", "BeatPulseSpeedMult", game.level_status, "beat_pulse_speed_mult")
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
