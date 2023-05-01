local level_status = {}
level_status.__index = level_status

-- takes sync music because unless overwritten it is defined by the global config file
function level_status:new(sync_music_to_dm)
    return setmetatable({
        tracked_variables = {},
        score_overwritten = false,
        score_overwrite = "",
        sync_music_to_dm = sync_music_to_dm,
        music_pitch = 1,
        beep_sound = love.audio.newSource("assets/audio/click.ogg", "static"),
        level_up_sound = love.audio.newSource("assets/audio/increment.ogg", "static"),
        swap_sound = love.audio.newSource("assets/audio/swap.ogg", "static"),
        death_sound = love.audio.newSource("assets/audio/death.ogg", "static"),
        speed_mult = 1,
        player_speed_mult = 1,
        speed_inc = 0,
        speed_max = 0,
        rotation_speed = 0,
        rotation_speed_inc = 0,
        rotation_speed_max = 0,
        delay_mult = 1,
        delay_inc = 0,
        delay_min = 0,
        delay_max = 0,
        fast_spin = 0,
        inc_time = 15,
        pulse_min = 75,
        pulse_max = 80,
        pulse_speed = 0,
        pulse_speed_r = 0,
        pulse_delay_max = 0,
        pulse_initial_delay = 0,
        swap_cooldown_mult = 1,
        beat_pulse_initial_delay = 0,
        beat_pulse_max = 0,
        beat_pulse_delay_max = 0,
        beat_pulse_speed_mult = 1,
        radius_min = 72,
        wall_skew_left = 0,
        wall_skew_right = 0,
        wall_angle_left = 0,
        wall_angle_right = 0,
        wall_spawn_distance = 1600,
        camera_shake = 0,
        sides = 6,
        sides_max = 6,
        sides_min = 6,
        swap_enabled = false,
        tutorial_mode = false,
        _3D_required = false,
        shaders_required = false,
        inc_enabled = true,
        rnd_side_changes_enabled = true,
        darken_uneven_background_chunk = true,
        manual_pulse_control = false,
        manual_beat_pulse_control = false,
        current_increments = 0
    }, level_status)
end

function level_status:has_speed_max_limit()
    return self.speed_max > 0
end

function level_status:has_delay_max_limit()
    return self.delay_max > 0
end

return level_status
