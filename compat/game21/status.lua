local status = {
    flash_color = {0, 0, 0},
    _total_frametime_accumulator = 0,
    _played_frametime_accumulator = 0,
    _paused_frametime_accumulator = 0,
    _current_pause = 6,
    _current_increment_time = 0,
    _custom_score = 0,
    pulse = 75,
    pulse_direction = 1,
    pulse_delay = 0,
    beat_pulse = 0,
    beat_pulse_delay = 0,
    pulse3D = 1,
    pulse3D_direction = 1,
    flash_effect = 0,
    radius = 75,
    fast_spin = 0,
    camera_shake = 0,
    has_died = false,
    must_state_change = "none",
    score_invalid = false,
    invalid_reason = "",
    started = false,
    show_player_trail = true,
    fragment_shaders = {}
}

function status:start()
    self:reset_time()
    self.custom_score = 0
    self.started = true
end

function status:get_increment_time_seconds()
    return self._current_increment_time / 60
end

function status:get_time_seconds()
    return self:get_played_accumulated_frametime_in_seconds()
end

function status:get_current_tp()
    return self:get_total_accumulated_frametime_in_seconds() * 1000
end

function status:get_time_tp()
    return self:get_played_accumulated_frametime_in_seconds() * 1000
end

function status:get_level_start_tp()
    return 0
end

function status:is_time_paused()
    return self._current_pause > 0
end

function status:pause_time(time)
    self._current_pause = self._current_pause + time * 60
end

function status:reset_increment_time()
    self._current_increment_time = 0
end

function status:reset_time()
    self._total_frametime_accumulator = 0
    self._played_frametime_accumulator = 0
    self._paused_frametime_accumulator = 0
    self._current_pause = 6
    self._current_increment_time = 0
end

function status:accumulate_frametime(ft)
    self._total_frametime_accumulator = self._total_frametime_accumulator + ft
    if self._current_pause > 0 then
        self._current_pause = self._current_pause - ft
    else
        self._played_frametime_accumulator = self._played_frametime_accumulator + ft
        self._current_increment_time = self._current_increment_time + ft
    end
end

function status:update_custom_score(score)
    self._custom_score = score
end

function status:get_total_accumulated_frametime()
    return self._total_frametime_accumulator
end

function status:get_total_accumulated_frametime_in_seconds()
    return self:get_total_accumulated_frametime() / 60
end

function status:get_played_accumulated_frametime()
    return self._played_frametime_accumulator
end

function status:get_played_accumulated_frametime_in_seconds()
    return self:get_played_accumulated_frametime() / 60
end

function status:get_paused_accumulated_frametime()
    return self._paused_frametime_accumulator
end

function status:get_paused_accumulated_frametime_in_seconds()
    return self:get_paused_accumulated_frametime() / 60
end

function status:get_custom_score()
    return self._custom_score
end

return status
