local log = require("log")(...)
local lua_runtime = {
    env = nil,
    assets = nil,
    file_cache = {}
}

function lua_runtime:init_env(assets, pack_name)
    self.assets = assets
    local pack = assets.loaded_packs[pack_name]
    log("initializing environment...")
    self.env = {
        print = print,
        math = math,
        u_execScript = function(path)
            self:run_lua_file(pack.path .. "/" .. path)
        end
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
