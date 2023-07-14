local utils = require("compat.game192.utils")
local pulse = {}
local game

function pulse.init(pass_game)
    game = pass_game
    game.status.pulse_delay = game.status.pulse_delay + game.level_status.pulse_initial_delay
end

function pulse.update(frametime, dm_factor)
    if not game.level_status.manual_pulse_control then
        game.status.pulse_delay = game.status.pulse_delay
        if game.status.pulse_delay <= 0 then
            local pulse_add = game.status.pulse_direction > 0 and game.level_status.pulse_speed
                or -game.level_status.pulse_speed_r
            local pulse_limit = game.status.pulse_direction > 0 and game.level_status.pulse_max
                or game.level_status.pulse_min
            game.status.pulse = utils.float_round(game.status.pulse + pulse_add * frametime * dm_factor)
            if
                (game.status.pulse_direction > 0 and game.status.pulse >= pulse_limit)
                or (game.status.pulse_direction < 0 and game.status.pulse <= pulse_limit)
            then
                game.status.pulse = pulse_limit
                game.status.pulse_direction = -game.status.pulse_direction
                if game.status.pulse_direction < 0 then
                    game.status.pulse_delay = game.level_status.pulse_delay_max
                end
            end
        end
        game.status.pulse_delay = game.status.pulse_delay - frametime * dm_factor
    end
end

function pulse.get_zoom(zoom_factor)
    local p = game.config.get("pulse") and game.status.pulse / game.level_status.pulse_min or 1
    return zoom_factor / p
end

return pulse
