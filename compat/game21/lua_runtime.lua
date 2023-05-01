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
        l_setSpeedMult = function() end,
        l_setSpeedInc = function() end,
        l_setSpeedMax = function() end,
        l_setRotationSpeed = function() end,
        l_setRotationSpeedInc = function() end,
        l_setRotationSpeedMax = function() end,
        l_setDelayMult = function() end,
        l_setDelayInc = function() end,
        l_setFastSpin = function() end,
        l_setSides = function() end,
        l_setSidesMax = function() end,
        l_setSidesMin = function() end,
        l_setIncTime = function() end,
        l_setPulseMin = function() end,
        l_setPulseMax = function() end,
        l_setPulseSpeed = function() end,
        l_setPulseSpeedR = function() end,
        l_setPulseDelayMax = function() end,
        l_setBeatPulseMax = function() end,
        l_setBeatPulseDelayMax = function() end,
        l_setBeatPulseSpeedMult = function() end,
        e_messageAdd = function() end,
        l_getLevelTime = function()
            return 0
        end,
    }
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
