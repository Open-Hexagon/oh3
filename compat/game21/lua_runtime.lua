local log = require("log")(...)
local lua_runtime = {
    env = nil,
    assets = nil,
    file_cache = {}
}

function lua_runtime:init_env(assets, pack_name)
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
