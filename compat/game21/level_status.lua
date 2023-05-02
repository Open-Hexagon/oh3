local default_sounds = {
    beep_sound = love.audio.newSource("assets/audio/click.ogg", "static"),
    level_up_sound = love.audio.newSource("assets/audio/increment.ogg", "static"),
    swap_sound = love.audio.newSource("assets/audio/swap.ogg", "static"),
    death_sound = love.audio.newSource("assets/audio/death.ogg", "static"),
}
local level_status = {}
level_status.__index = level_status

-- takes sync music because unless overwritten it is defined by the global config file
function level_status:reset(sync_music_to_dm)
    for sound, source in pairs(default_sounds) do
        self[sound] = source
    end
    self.tracked_variables = {}
    self.score_overwritten = false
    self.score_overwrite = ""
    self.sync_music_to_dm = sync_music_to_dm
    self.music_pitch = 1
    self.speed_mult = 1
    self.player_speed_mult = 1
    self.speed_inc = 0
    self.speed_max = 0
    self.rotation_speed = 0
    self.rotation_speed_inc = 0
    self.rotation_speed_max = 0
    self.delay_mult = 1
    self.delay_inc = 0
    self.delay_min = 0
    self.delay_max = 0
    self.fast_spin = 0
    self.inc_time = 15
    self.pulse_min = 75
    self.pulse_max = 80
    self.pulse_speed = 0
    self.pulse_speed_r = 0
    self.pulse_delay_max = 0
    self.pulse_initial_delay = 0
    self.swap_cooldown_mult = 1
    self.beat_pulse_initial_delay = 0
    self.beat_pulse_max = 0
    self.beat_pulse_delay_max = 0
    self.beat_pulse_speed_mult = 1
    self.radius_min = 72
    self.wall_skew_left = 0
    self.wall_skew_right = 0
    self.wall_angle_left = 0
    self.wall_angle_right = 0
    self.wall_spawn_distance = 1600
    self.camera_shake = 0
    self.sides = 6
    self.sides_max = 6
    self.sides_min = 6
    self.swap_enabled = false
    self.tutorial_mode = false
    self._3D_required = false
    self.shaders_required = false
    self.inc_enabled = true
    self.rnd_side_changes_enabled = true
    self.darken_uneven_background_chunk = true
    self.manual_pulse_control = false
    self.manual_beat_pulse_control = false
    self.current_increments = 0
end

function level_status:has_speed_max_limit()
    return self.speed_max > 0
end

function level_status:has_delay_max_limit()
    return self.delay_max > 0
end

return level_status
