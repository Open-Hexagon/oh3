local config = {}
local settings = {}
local properties = {}

local function add_property(name, default, can_change_in_offical)
    properties[name] = { default = default, can_change_in_offical = can_change_in_offical }
end

add_property("official_mode", true, false)
add_property("sync_music_to_dm", true, true)
add_property("player_size", 7.3, false)
add_property("player_speed", 9.45, false)
add_property("player_focus_speed", 4.625, false)
add_property("music_speed_mult", 1, true)
add_property("play_swap_sound", true, true)
add_property("beatpulse", true, false)
add_property("pulse", true, false)
add_property("3D_enabled", true, false)
add_property("3D_multiplier", 1, false)
add_property("background", true, false)
add_property("player_tilt_intensity", 1, true)
add_property("swap_blinking_effect", true, true)
add_property("flash", true, true)
add_property("messages", true, false)
add_property("key_focus", "lshift", true)
add_property("key_swap", "space", true)
add_property("key_right", "right", true)
add_property("key_left", "left", true)
add_property("shaders", true, false)
add_property("invincible", false, false)
add_property("black_and_white", false, false)
add_property("camera_shake_mult", 1, true)
add_property("text_scale", 1, true)
add_property("show_player_trail", false, true)
add_property("player_trail_decay", 3, true)
add_property("player_trail_scale", 0.9, true)
add_property("player_trail_alpha", 35, true)
add_property("player_trail_has_swap_color", true, true)
add_property("show_swap_particles", true, true)

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