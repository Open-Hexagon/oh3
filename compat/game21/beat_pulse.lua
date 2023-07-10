local beat_pulse = {}
local game, public

function beat_pulse.init(pass_game, pass_public)
    game = pass_game
    public = pass_public
    game.status.beat_pulse_delay = game.status.beat_pulse_delay + game.level_status.beat_pulse_initial_delay
end

function beat_pulse.update(frametime, dm_factor)
    if public.config.get("beatpulse") then
        if not game.level_status.manual_beat_pulse_control then
            if game.status.beat_pulse_delay <= 0 then
                game.status.beat_pulse = game.level_status.beat_pulse_max
                game.status.beat_pulse_delay = game.level_status.beat_pulse_delay_max
            else
                game.status.beat_pulse_delay = game.status.beat_pulse_delay - frametime * dm_factor
            end
            if game.status.beat_pulse > 0 then
                game.status.beat_pulse = game.status.beat_pulse
                    - 2 * frametime * dm_factor * game.level_status.beat_pulse_speed_mult
            end
        end
    end
    local radius_min = public.config.get("beatpulse") and game.level_status.radius_min or 75
    game.status.radius = radius_min * (game.status.pulse / game.level_status.pulse_min) + game.status.beat_pulse
end

return beat_pulse
