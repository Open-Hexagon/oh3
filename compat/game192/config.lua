local config = {}
local settings = {}
local properties = {}

local function add_property(name, default, can_change_in_offical)
    properties[name] = { default = default, can_change_in_offical = can_change_in_offical }
end

add_property("official_mode", true, false)
add_property("beatpulse", true, false)
add_property("pulse", true, false)
add_property("black_and_white", false, false)
add_property("3D_enabled", true, false)
add_property("rotation", true, false)
add_property("background", true, false)
add_property("3D_multiplier", 1, false)
add_property("player_size", 7.3, false)
add_property("player_speed", 9.45, false)
add_property("player_focus_speed", 4.625, false)
add_property("invincible", true, false)
add_property("messages", true, false)
add_property("key_focus", "lshift", true)
add_property("key_right", "right", true)
add_property("key_left", "left", true)

function config.set_defaults()
    for name, values in pairs(properties) do
        settings[name] = values.default
    end
end

function config.set(name, value)
    settings[name] = value
end

function config.get(name)
    local value = settings[name]
    local property = properties[name]
    if settings.official_mode and not property.can_change_in_offical and value ~= property.default then
        return properties[name].default
    else
        return value
    end
end

config.set_defaults()
-- TODO: load from file / get whatever the user set in the ui

return config
