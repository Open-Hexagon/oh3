local make_make_accessors = require("compat.game21.lua_runtime.make_accessors")

return function(game)
    local pack = game.pack_data
    local lua_runtime = game.lua_runtime
    local env = lua_runtime.env
    local make_accessors = make_make_accessors(game)
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
end
