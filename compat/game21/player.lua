local player = {}

local timer = require("compat.game21.timer")
local get_color_from_hue = require("compat.game21.hue").get_color

local base_thickness = 5
local unfocused_triangle_width = 3
local focused_tirangle_width = -1.5
local triangle_width_range = unfocused_triangle_width - focused_tirangle_width

function player:reset(swap_cooldown, size, speed, focus_speed)
    self._start_pos = {0, 0}
    self._pos = {0, 0}
    self._pre_push_pos = {0, 0}
    self._last_pos = {0, 0}
    self._hue = 0
    self._angle = 0
    self._last_angle = 0
    self._size = size
    self._speed = speed
    self._focus_speed = focus_speed
    self._dead = false
    self._just_swapped = false
    self._forced_move = false
    self._radius = 0
    self._max_safe_distance = 0
    self._current_speed = 0
    self._triangle_width = unfocused_triangle_width
    self._triangle_width_transition_time = 0
    self._swap_timer = timer:new(swap_cooldown)
    self._swap_blink_timer = timer:new(6)
    self._dead_effect_timer = timer:new(80, false)
    self._curr_tilted_angle = 0
    self._color = {0, 0, 0, 0}
    self._death_effect_color = {0, 0, 0, 0}
end

function player:get_color(color)
    if self._dead_effect_timer.running then
        get_color_from_hue(self._hue / 360, color)
    end
end

function player:get_color_adjusted_for_swap(color)
    if not self._swap_timer.running and not self._dead then
        get_color_from_hue(math.fmod(self._swap_blink_timer.current / 12, 0.2), color)
    else
        self:get_color(color)
    end
end

-- TODO: clean draw code up a little (also draws more polygons than it needs to)
-- (currently it's pretty much just copied from the game)
function player:draw(sides, style, angle_tilt_intensity, swap_blinking_effect)
    -- TODO: 255, 255, 255, normal a if bw mode
    self._color[1], self._color[2], self._color[3], self._color[4] = style:get_player_color()
    self:draw_pivot(sides, style)
    if not self._dead_effect_timer.running then
        self:draw_death_effect()
    end
    local tilted_angle = self._angle + (self._curr_tilted_angle * math.rad(24) * angle_tilt_intensity)
    local deg100 = math.rad(100)
    local cos, sin = math.cos, math.sin
    local distance = self._size + self._triangle_width
    local p_left_x = cos(tilted_angle - deg100) * distance + self._pos[1]
    local p_left_y = sin(tilted_angle - deg100) * distance + self._pos[2]
    local p_right_x = cos(tilted_angle + deg100) * distance + self._pos[1]
    local p_right_y = sin(tilted_angle + deg100) * distance + self._pos[2]
    local pos_x = cos(tilted_angle) * self._size + self._pos[1]
    local pos_y = sin(tilted_angle) * self._size + self._pos[2]
    if swap_blinking_effect then
        self:get_color_adjusted_for_swap(self._color)
    else
        self:get_color(self._color)
    end
    love.graphics.setColor(unpack(self._color))
    love.graphics.polygon("fill", pos_x, pos_y, p_left_x, p_left_y, p_right_x, p_right_y)
end

function player:draw_pivot(sides, style)
    local div = math.pi / sides
    local p_radius = self._radius * 0.75
    local sin, cos = math.sin, math.cos
    for i = 0, sides - 1 do
        local s_angle = div * 2 * i
        local p1_x, p1_y = self._start_pos[1] + cos(s_angle - div) * p_radius, self._start_pos[2] + sin(s_angle - div) * p_radius
        local p2_x, p2_y = self._start_pos[1] + cos(s_angle + div) * p_radius, self._start_pos[2] + sin(s_angle + div) * p_radius
        local p3_x, p3_y = self._start_pos[1] + cos(s_angle + div) * (p_radius + base_thickness), self._start_pos[2] + sin(s_angle + div) * (p_radius + base_thickness)
        local p4_x, p4_y = self._start_pos[1] + cos(s_angle - div) * (p_radius + base_thickness), self._start_pos[2] + sin(s_angle - div) * (p_radius + base_thickness)
        love.graphics.setColor(style:get_main_color())
        love.graphics.polygon("fill", p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y)
        love.graphics.setColor(style:get_cap_color_result())
        love.graphics.polygon("fill", p1_x, p1_y, p2_x, p2_y, unpack(self._start_pos))
    end
end

function player:draw_death_effect()
    local div = math.pi / 6
    local d_radius = self._hue / 8
    local thickness = self._hue / 20
    get_color_from_hue((360 - self._hue) / 360, self._death_effect_color)
    love.graphics.setColor(unpack(self._death_effect_color))
    local sin, cos = math.sin, math.cos
    for i = 0, 5 do
        local s_angle = div * 2 * i
        local p1_x, p1_y = self._pos[1] + cos(s_angle - div) * d_radius, self._pos[2] + sin(s_angle - div) * d_radius
        local p2_x, p2_y = self._pos[1] + cos(s_angle + div) * d_radius, self._pos[2] + sin(s_angle + div) * d_radius
        local p3_x, p3_y = self._pos[1] + cos(s_angle + div) * (d_radius + thickness), self._pos[2] + sin(s_angle + div) * (d_radius + base_thickness)
        local p4_x, p4_y = self._pos[1] + cos(s_angle - div) * (d_radius + thickness), self._pos[2] + sin(s_angle - div) * (d_radius + base_thickness)
        love.graphics.polygon("fill", p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y)
    end
end

function player:player_swap()
    self._angle = self._angle + math.pi
end

function player:kill(fatal)
    self._dead_effect_timer:restart()
    if fatal then
        self._dead = true
        if not self._just_swapped and math.sqrt((self._pos[1] - self._last_pos[1]) ^ 2 + (self._pos[2] - self._last_pos[2]) ^ 2) < 24 then
            self._pos[1] = -math.cos(self._angle) * self._size + self._last_pos[1]
            self._pos[2] = -math.sin(self._angle) * self._size + self._last_pos[2]
        end
    end
end

local collision_padding = 0.5

function player:check_wall_collision_escape(wall, pos, radius_squared)
    -- TODO
end

function player:wall_push(movement_dir, radius, wall, center_pos, radius_squared, frametime)
    -- TODO
end

function player:cw_push(movement_dir, radius, custom_wall, radius_squared, frametime)
    -- TODO
end

local function move_towards(value, target, step)
    if value < target then
        value = value + step
        if value > target then
            value = target
        end
    elseif value > target then
        value = value - step
        if value < target then
            value = target
        end
    end
    return value
end

local function get_smooth_step(edge0, edge1, x)
    x = (x - edge0) / (edge1 - edge0)
    if x < 0 then
        x = 0
    elseif x > 1 then
        x = 1
    end
    return x * x * (3 - 2 * x)
end

function player:update_triangle_width_transition(focused, frametime)
    if focused and self._triangle_width_transition_time < 1 then
        self._triangle_width_transition_time = move_towards(self._triangle_width_transition_time, 1, frametime * 0.1)
    elseif not focused and self._triangle_width_transition_time > 0 then
        self._triangle_width_transition_time = move_towards(self._triangle_width_transition_time, 0, frametime * 0.1)
    end
    self._triangle_width = triangle_width_range * (1 - get_smooth_step(0, 1, self._triangle_width_transition_time))
end

function player:update(focused, swap_enabled, frametime)
    self:update_triangle_width_transition(focused, frametime)
    if self._dead_effect_timer.running then
        self._dead_effect_timer:update(frametime)
        self._hue = self._hue + 18 * frametime
        if self._hue > 360 then
            self._hue = 0
        end
        if self._dead then
            return
        end
        if self._dead_effect_timer.total >= 100 then
            self._dead_effect_timer:stop()
            self._dead_effect_timer:reset_all()
        end
    end
    self._swap_blink_timer:update(frametime / 3)
    if swap_enabled and self._swap_timer:update(frametime) then
        self._swap_timer:stop()
    end
    self._last_angle = self._angle
    self._forced_move = false
end

function player:update_input_movement(movement_dir, player_speed_mult, focused, frametime)
    self._current_speed = player_speed_mult * (focused and self._focus_speed or self._speed) * frametime
    self._angle = self._angle + math.rad(self._current_speed * movement_dir)
    local inc = frametime / 10
    self._curr_tilted_angle = movement_dir == 0 and move_towards(self._curr_tilted_angle, 0, inc) or move_towards(self._curr_tilted_angle, movement_dir, inc * 2)
end

function player:reset_swap(swap_cooldown)
    self._swap_timer:restart(swap_cooldown)
    self._swap_blink_timer:restart(6)
end

function player:set_just_swapped(value)
    self._just_swapped = value
end

function player:update_position(radius)
    self._radius = radius
    local sin, cos = math.sin, math.cos
    self._pos[1] = cos(self._angle) * self._radius + self._start_pos[1]
    self._pos[2] = sin(self._angle) * self._radius + self._start_pos[2]
    self._pre_push_pos[1] = self._pos[1]
    self._pre_push_pos[2] = self._pos[2]
    local pos_diff_x = self._last_pos[1] - self._start_pos[1] - cos(self._last_angle + math.rad(self._current_speed)) * self._radius
    local pos_diff_y = self._last_pos[2] - self._start_pos[2] - sin(self._last_angle + math.rad(self._current_speed)) * self._radius
    self._max_safe_distance = pos_diff_x ^ 2 + pos_diff_y ^ 2 + 32
end

function player:get_just_swapped()
    return self._just_swapped
end

function player:get_position()
    return unpack(self._pos)
end

function player:get_player_angle()
    return self._angle
end

function player:set_player_angle(new_ang)
    self._angle = new_ang
    self._forced_move = true
end

function player:is_ready_to_swap()
    return not self._swap_timer.running
end

function player:has_changed_angle()
    return self._angle ~= self._last_angle
end

return player
