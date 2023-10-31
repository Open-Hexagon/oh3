local json = require("extlibs.json.json-beautify")
local input_schemes = require("input_schemes")
local config = {}
local settings = {}
local properties = {}

local profile_path = "config/"
local current_profile = nil
if not love.filesystem.getInfo(profile_path) then
    love.filesystem.createDirectory(profile_path)
end

---add a setting to the config
---@param name string
---@param default any
---@param options table?
local function add_setting(name, default, options)
    options = options or {}
    if options.can_change_in_offical == nil then
        options.can_change_in_offical = true
    end
    properties[name] = {
        default = default,
        display_name = name:gsub("_", " "):gsub("^%l", string.upper),
    }
    for key, value in pairs(options) do
        properties[name][key] = value
    end
end

add_setting("game_resolution_scale", 1, { min = 1, max = 10, step = 1 })
add_setting("area_based_gui_scale", false)
add_setting("background_preview", true)
add_setting("background_preview_has_text", false)
add_setting("background_preview_music_volume", 0, { min = 0, max = 1, step = 0.05 })
add_setting("background_preview_sound_volume", 0, { min = 0, max = 1, step = 0.05 })
add_setting("preload_all_packs", false)
add_setting("fps_limit", 200)
add_setting("official_mode", true, { can_change_in_offical = false, game_version = { 192, 20, 21, 3 } })
add_setting("sound_volume", 1, { game_version = { 192, 20, 21, 3 }, min = 0, max = 1, step = 0.05 })
add_setting("music_volume", 1, { game_version = { 192, 20, 21, 3 }, min = 0, max = 1, step = 0.05 })
add_setting("beatpulse", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("pulse", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("player_size", 7.3, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("player_speed", 9.45, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("player_focus_speed", 4.625, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("black_and_white", false, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("3D_enabled", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("3D_multiplier", 1, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("3D_max_depth", 100, { can_change_in_offical = false, game_version = { 192, 20 } })
add_setting("background", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("invincible", false, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("rotation", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("messages", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("sync_music_to_dm", true, { game_version = { 20, 21 } })
add_setting("music_speed_mult", 1, { game_version = 21 })
add_setting("play_swap_sound", true, { game_version = 21 })
add_setting("player_tilt_intensity", 1, { game_version = 21 })
add_setting("swap_blinking_effect", true, { game_version = 21 })
add_setting("flash", true, { can_change_in_offical = false, game_version = { 192, 20, 21 } })
add_setting("shaders", true, { can_change_in_offical = false, game_version = 21 })
add_setting("camera_shake_mult", 1, { game_version = 21 })
add_setting("text_scale", 1, { game_version = 21 })
add_setting("show_player_trail", false, { game_version = 21 })
add_setting("player_trail_decay", 3, { game_version = 21 })
add_setting("player_trail_scale", 0.9, { game_version = 21 })
add_setting("player_trail_alpha", 35, { game_version = 21 })
add_setting("player_trail_has_swap_color", true, { game_version = 21 })
add_setting("show_swap_particles", true, { game_version = 21 })

local function add_input(name, versions)
    local bindings = {}
    for scheme_name, scheme in pairs(input_schemes) do
        if #(scheme.defaults[name] or {}) > 0 then
            bindings[#bindings + 1] = {
                scheme = scheme_name,
                ids = scheme.defaults[name],
            }
        end
    end
    add_setting(name, bindings, {
        game_version = versions,
    })
end

add_input("right", { 192, 20, 21 })
add_input("left", { 192, 20, 21 })
add_input("focus", { 192, 20, 21 })
add_input("swap", { 20, 21 })
add_input("ui_up")
add_input("ui_down")
add_input("ui_right")
add_input("ui_left")
add_input("ui_click")
add_input("ui_delete")
add_input("ui_backspace")

---resets all settings
function config.set_defaults()
    for name, values in pairs(properties) do
        settings[name] = values.default
    end
end

---sets a setting to a value
---@param name string
---@param value any
function config.set(name, value)
    settings[name] = value
end

---gets a setting (returns the default for settings that cannot be changed in official mode if official mode is on)
---@param name string
---@return any
function config.get(name)
    local value = settings[name]
    local property = properties[name]
    if not property then
        return
    end
    if settings.official_mode and not property.can_change_in_offical and value ~= property.default then
        return properties[name].default
    else
        return value
    end
end

---get the definition of all the settings (default values, type, game versions it affects, ...)
---@return table
function config.get_definitions()
    return properties
end

---gets a table of all settings or all settings for a certain game version
---@param game_version number|nil
---@return table
function config.get_all(game_version)
    if game_version == nil then
        return settings
    elseif type(game_version) == "number" then
        local game_settings = {}
        for name, property in pairs(properties) do
            if property.game ~= nil then
                local has_version = false
                if type(property.game) == "table" then
                    for i = 1, #property.game do
                        if property.game[i] == game_version then
                            has_version = true
                            break
                        end
                    end
                elseif type(property.game) == "number" then
                    if property.game == game_version then
                        has_version = true
                    end
                end
                if has_version then
                    game_settings[name] = config.get(name)
                end
            end
        end
        return game_settings
    else
        error("game_version should be a number")
    end
end

---loads the config from a json file
---@param path string
local function load_from_json(path)
    -- reset the settings before loading in case some settings didn't exist yet in the config file
    config.set_defaults()
    local file = love.filesystem.newFile(path)
    file:open("r")
    local contents = file:read()
    file:close()
    for name, value in pairs(json.decode(contents)) do
        config.set(name, value)
    end
end

---saves the config into a json file
---@param path string
local function save_to_json(path)
    local file = love.filesystem.newFile(path)
    file:open("w")
    file:write(json.beautify(config.get_all()))
    file:close()
end

-- profiles here refer to setting profiles which should not be confused with game profiles!

---creates a new profile (raises an error if one with the same name already exists)
---@param name string
function config.create_profile(name)
    local path = profile_path .. name .. ".json"
    if not love.filesystem.getInfo(path) then
        save_to_json(path)
    else
        error("profile with name '" .. name .. "' already exists!")
    end
    current_profile = name
end

---opens a profile (raises an error if it doesn't exist)
---@param name string
function config.open_profile(name)
    local path = profile_path .. name .. ".json"
    if love.filesystem.getInfo(path) then
        load_from_json(path)
    else
        error("profile with name '" .. name .. "' doesn't exist!")
    end
    current_profile = name
end

---deletes a profile
---@param name string
function config.delete_profile(name)
    local path = profile_path .. name .. ".json"
    if love.filesystem.getInfo(path) then
        love.filesystem.remove(path)
    end
    current_profile = nil
    config.set_defaults()
end

---returns a table containing the names of all existing profiles
---@return table
function config.list_profiles()
    local filenames = love.filesystem.getDirectoryItems(profile_path)
    local names = {}
    for i = 1, #filenames do
        names[i] = filenames[i]:sub(1, -6)
    end
    return names
end

---saves the current profile
function config.save()
    save_to_json(profile_path .. current_profile .. ".json")
end

-- no profile loaded yet so use defaults for now
config.set_defaults()

return config
