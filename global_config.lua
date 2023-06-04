local json = require("extlibs.json.json-beautify")
local global_config = {}
local settings = {}
local g_config, g_profile
local path = "config.json"

local function save()
    local file = love.filesystem.newFile(path)
    file:open("w")
    file:write(json.beautify(settings))
    file:close()
end

---open the config file
---@param config any
---@param profile any
function global_config.init(config, profile)
    g_config, g_profile = config, profile
    if not love.filesystem.getInfo(path) then
        global_config.set_game_profile("default")
        global_config.set_settings_profile("default")
        save()
    else
        local file = love.filesystem.newFile(path)
        file:open("r")
        settings = json.decode(file:read())
        file:close()
        config.open_profile(settings.settings_profile)
        profile.open_or_new(settings.game_profile)
    end
end

---set the current settings profile (creates it if it doesn't exist)
---@param name string
function global_config.set_settings_profile(name)
    local profiles = g_config.list_profiles()
    local has_profile = false
    for i = 1, #profiles do
        if profiles[i] == name then
            has_profile = true
            break
        end
    end
    if not has_profile then
        g_config.create_profile(name)
    end
    g_config.open_profile(name)
    settings.settings_profile = name
    save()
end

---sets the current game profile (creates it if it doesn't exist)
---@param name string
function global_config.set_game_profile(name)
    g_profile.open_or_new(name)
    settings.game_profile = name
    save()
end

return global_config
