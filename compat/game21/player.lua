local player = {}

local timer = require("compat.game21.timer")
local get_color_from_hue = require("compat.game21.hue").get_color

local base_thickness = 5
local unfocused_triangle_width = 3
local focused_tirangle_width = -1.5
local triangle_width_range = unfocused_triangle_width - focused_tirangle_width

local _start_pos
local _pos
local _pre_push_pos
local _last_pos
local _hue
local _angle
local _last_angle
local _size
local _speed
local _focus_speed
local _dead
local _just_swapped
local _forced_move
local _radius
local _max_safe_distance
local _current_speed
local _triangle_width
local _triangle_width_transition_time
local _swap_timer
local _swap_blink_timer
local _dead_effect_timer
local _curr_tilted_angle
local _color
local _death_effect_color

function player.reset(swap_cooldown, size, speed, focus_speed)
    _start_pos = { 0, 0 }
    _pos = { 0, 0 }
    _pre_push_pos = { 0, 0 }
    _last_pos = { 0, 0 }
    _hue = 0
    _angle = 0
    _last_angle = 0
    _size = size
    _speed = speed
    _focus_speed = focus_speed
    _dead = false
    _just_swapped = false
    _forced_move = false
    _radius = 0
    _max_safe_distance = 0
    _current_speed = 0
    _triangle_width = unfocused_triangle_width
    _triangle_width_transition_time = 0
    _swap_timer = timer:new(swap_cooldown)
    _swap_blink_timer = timer:new(6)
    _dead_effect_timer = timer:new(80, false)
    _curr_tilted_angle = 0
    _color = { 0, 0, 0, 0 }
    _death_effect_color = { 0, 0, 0, 0 }
end

local function get_color(color)
    if _dead_effect_timer.running then
        get_color_from_hue(_hue / 360, color)
    end
end

local function get_color_adjusted_for_swap(color)
    if not _swap_timer.running and not _dead then
        get_color_from_hue(math.fmod(_swap_blink_timer.current / 12, 0.2), color)
    else
        get_color(color)
    end
end

local function draw_pivot(sides, style, pivotquads, cap_tris)
    local div = math.pi / sides
    local p_radius = _radius * 0.75
    local sin, cos = math.sin, math.cos
    for i = 0, sides - 1 do
        local s_angle = div * 2 * i
        local p1_x, p1_y = _start_pos[1] + cos(s_angle - div) * p_radius, _start_pos[2] + sin(s_angle - div) * p_radius
        local p2_x, p2_y = _start_pos[1] + cos(s_angle + div) * p_radius, _start_pos[2] + sin(s_angle + div) * p_radius
        local p3_x, p3_y =
            _start_pos[1] + cos(s_angle + div) * (p_radius + base_thickness),
            _start_pos[2] + sin(s_angle + div) * (p_radius + base_thickness)
        local p4_x, p4_y =
            _start_pos[1] + cos(s_angle - div) * (p_radius + base_thickness),
            _start_pos[2] + sin(s_angle - div) * (p_radius + base_thickness)
        pivotquads:add_quad(p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, style.get_main_color())
        cap_tris:add_tris(p1_x, p1_y, p2_x, p2_y, _start_pos[1], _start_pos[2], style.get_cap_color_result())
    end
end

local function draw_death_effect(quads)
    local div = math.pi / 6
    local d_radius = _hue / 8
    local thickness = _hue / 20
    get_color_from_hue((360 - _hue) / 360, _death_effect_color)
    local sin, cos = math.sin, math.cos
    for i = 0, 5 do
        local s_angle = div * 2 * i
        local p1_x, p1_y = _pos[1] + cos(s_angle - div) * d_radius, _pos[2] + sin(s_angle - div) * d_radius
        local p2_x, p2_y = _pos[1] + cos(s_angle + div) * d_radius, _pos[2] + sin(s_angle + div) * d_radius
        local p3_x, p3_y =
            _pos[1] + cos(s_angle + div) * (d_radius + thickness),
            _pos[2] + sin(s_angle + div) * (d_radius + base_thickness)
        local p4_x, p4_y =
            _pos[1] + cos(s_angle - div) * (d_radius + thickness),
            _pos[2] + sin(s_angle - div) * (d_radius + base_thickness)
        quads:add_quad(p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, unpack(_death_effect_color))
    end
end

function player.draw(sides, style, pivotquads, playertris, cap_tris, angle_tilt_intensity, swap_blinking_effect)
    -- TODO: 255, 255, 255, normal a if bw mode
    _color[1], _color[2], _color[3], _color[4] = style.get_player_color()
    draw_pivot(sides, style, pivotquads, cap_tris)
    if not _dead_effect_timer.running then
        draw_death_effect(pivotquads)
    end
    local tilted_angle = _angle + (_curr_tilted_angle * math.rad(24) * angle_tilt_intensity)
    local deg100 = math.rad(100)
    local cos, sin = math.cos, math.sin
    local distance = _size + _triangle_width
    local p_left_x = cos(tilted_angle - deg100) * distance + _pos[1]
    local p_left_y = sin(tilted_angle - deg100) * distance + _pos[2]
    local p_right_x = cos(tilted_angle + deg100) * distance + _pos[1]
    local p_right_y = sin(tilted_angle + deg100) * distance + _pos[2]
    local pos_x = cos(tilted_angle) * _size + _pos[1]
    local pos_y = sin(tilted_angle) * _size + _pos[2]
    if swap_blinking_effect then
        get_color_adjusted_for_swap(_color)
    else
        get_color(_color)
    end
    playertris:add_tris(pos_x, pos_y, p_left_x, p_left_y, p_right_x, p_right_y, unpack(_color))
end

function player.player_swap()
    _angle = _angle + math.pi
end

function player.kill(fatal)
    _dead_effect_timer:restart()
    if fatal then
        _dead = true
        if not _just_swapped and math.sqrt((_pos[1] - _last_pos[1]) ^ 2 + (_pos[2] - _last_pos[2]) ^ 2) < 24 then
            _pos[1] = -math.cos(_angle) * _size + _last_pos[1]
            _pos[2] = -math.sin(_angle) * _size + _last_pos[2]
        end
    end
end

local collision_padding = 0.5

function player.check_wall_collision_escape(wall, pos, radius_squared)
    -- TODO
end

function player.wall_push(movement_dir, radius, wall, center_pos, radius_squared, frametime)
    -- TODO
end

function player.cw_push(movement_dir, radius, custom_wall, radius_squared, frametime)
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

local function update_triangle_width_transition(focused, frametime)
    if focused and _triangle_width_transition_time < 1 then
        _triangle_width_transition_time = move_towards(_triangle_width_transition_time, 1, frametime * 0.1)
    elseif not focused and _triangle_width_transition_time > 0 then
        _triangle_width_transition_time = move_towards(_triangle_width_transition_time, 0, frametime * 0.1)
    end
    _triangle_width = triangle_width_range * (1 - get_smooth_step(0, 1, _triangle_width_transition_time))
end

function player.update(focused, swap_enabled, frametime)
    update_triangle_width_transition(focused, frametime)
    if _dead_effect_timer.running then
        _dead_effect_timer:update(frametime)
        _hue = _hue + 18 * frametime
        if _hue > 360 then
            _hue = 0
        end
        if _dead then
            return
        end
        if _dead_effect_timer.total >= 100 then
            _dead_effect_timer:stop()
            _dead_effect_timer:reset_all()
        end
    end
    _swap_blink_timer:update(frametime / 3)
    if swap_enabled and _swap_timer:update(frametime) then
        _swap_timer:stop()
    end
    _last_angle = _angle
    _forced_move = false
end

function player.update_input_movement(movement_dir, player_speed_mult, focused, frametime)
    _current_speed = player_speed_mult * (focused and _focus_speed or _speed) * frametime
    _angle = _angle + math.rad(_current_speed * movement_dir)
    local inc = frametime / 10
    _curr_tilted_angle = movement_dir == 0 and move_towards(_curr_tilted_angle, 0, inc)
        or move_towards(_curr_tilted_angle, movement_dir, inc * 2)
end

function player.reset_swap(swap_cooldown)
    _swap_timer:restart(swap_cooldown)
    _swap_blink_timer:restart(6)
end

function player.set_just_swapped(value)
    _just_swapped = value
end

function player.update_position(radius)
    _radius = radius
    local sin, cos = math.sin, math.cos
    _pos[1] = cos(_angle) * _radius + _start_pos[1]
    _pos[2] = sin(_angle) * _radius + _start_pos[2]
    _pre_push_pos[1] = _pos[1]
    _pre_push_pos[2] = _pos[2]
    local pos_diff_x = _last_pos[1] - _start_pos[1] - cos(_last_angle + math.rad(_current_speed)) * _radius
    local pos_diff_y = _last_pos[2] - _start_pos[2] - sin(_last_angle + math.rad(_current_speed)) * _radius
    _max_safe_distance = pos_diff_x ^ 2 + pos_diff_y ^ 2 + 32
end

function player.get_just_swapped()
    return _just_swapped
end

function player.get_position()
    return unpack(_pos)
end

function player.get_player_angle()
    return _angle
end

function player.set_player_angle(new_ang)
    _angle = new_ang
    _forced_move = true
end

function player.is_ready_to_swap()
    return not _swap_timer.running
end

function player.has_changed_angle()
    return _angle ~= _last_angle
end

return player
