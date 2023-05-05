local transform_hue = require("compat.game21.hue").transform
local walls = {}
local _walls = {}
local _level_status

function walls.reset(level_status)
    _walls = {}
    _level_status = level_status
end

function walls.wall(
    speed_mult_dm,
    difficulty_mult,
    hue_modifier,
    side,
    thickness,
    speed_mult,
    acceleration,
    min_speed,
    max_speed,
    ping_pong,
    curving
)
    hue_modifier = hue_modifier or 0
    side = math.floor(side)
    speed_mult = speed_mult or 1
    acceleration = acceleration or 0
    min_speed = min_speed or 0
    max_speed = max_speed or 0
    local distance = _level_status.wall_spawn_distance
    local div = math.pi / _level_status.sides
    local angle = div * 2 * side
    local sin, cos = math.sin, math.cos
    local vertices = {}
    local function set_vertex(vertex_angle, dist)
        vertices[#vertices + 1] = cos(vertex_angle) * dist
        vertices[#vertices + 1] = sin(vertex_angle) * dist
    end
    set_vertex(angle - div, distance)
    set_vertex(angle + div, distance)
    set_vertex(angle + div + _level_status.wall_angle_left, distance + thickness + _level_status.wall_skew_left)
    set_vertex(angle - div + _level_status.wall_angle_right, distance + thickness + _level_status.wall_skew_right)
    if not curving then
        speed_mult = speed_mult * speed_mult_dm
    end
    local wall_table = {
        vertices = vertices,
        speed = speed_mult,
        accel = acceleration / math.pow(difficulty_mult, 0.65),
        min_speed = min_speed * speed_mult_dm,
        max_speed = max_speed * speed_mult_dm,
        hue_modifier = hue_modifier,
        ping_pong = ping_pong and -1 or 1,
        old_speed = speed_mult_dm, -- used for curving walls actual speed (only curve needs accel)
        curving = curving,
    }
    _walls[#_walls + 1] = wall_table
end

function walls.update(frametime, radius)
    local half_radius = 0.5 * radius
    local outer_bounds = _level_status.wall_spawn_distance * 1.1
    local del_queue = {}
    for i = 1, #_walls do
        local wall = _walls[i]
        if wall.accel ~= 0 then
            wall.speed = wall.speed + wall.accel * frametime
            if wall.speed > wall.max_speed then
                wall.speed = wall.max_speed
                wall.accel = wall.accel * wall.ping_pong
            elseif wall.speed < wall.min_speed then
                wall.speed = wall.min_speed
                wall.accel = wall.accel * wall.ping_pong
            end
        end
        local points_on_center = 0
        local points_out_of_bounds = 0
        local move_distance
        if wall.curving then
            move_distance = wall.old_speed * 5 * frametime
        else
            move_distance = wall.speed * 5 * frametime
        end
        for vertex = 1, 8, 2 do
            local x, y = wall.vertices[vertex], wall.vertices[vertex + 1]
            local x_dist, y_dist = math.abs(x), math.abs(y)
            if x_dist > outer_bounds or y_dist > outer_bounds then
                points_out_of_bounds = points_out_of_bounds + 1
            end
            if x_dist < half_radius and y_dist < half_radius then
                points_on_center = points_on_center + 1
            else
                local magnitude = math.sqrt(x ^ 2 + y ^ 2)
                wall.vertices[vertex] = x - x / magnitude * move_distance
                wall.vertices[vertex + 1] = y - y / magnitude * move_distance
            end
        end
        if points_on_center == 4 or points_out_of_bounds == 4 then
            table.insert(del_queue, 1, i)
        end
        if wall.curving and wall.speed ~= 0 then
            local angle = wall.speed / 60 * frametime
            local sin, cos = math.sin(angle), math.cos(angle)
            for vertex = 1, 8, 2 do
                local x, y = wall.vertices[vertex], wall.vertices[vertex + 1]
                wall.vertices[vertex] = x * cos - y * sin
                wall.vertices[vertex + 1] = x * sin + y * cos
            end
        end
    end
    for _, i in pairs(del_queue) do
        table.remove(_walls, i)
    end
end

function walls.draw(style, wallquads)
    for i = 1, #_walls do
        local wall = _walls[i]
        if wall.hue_modifier == 0 then
            wallquads:add_quad(
                wall.vertices[1],
                wall.vertices[2],
                wall.vertices[3],
                wall.vertices[4],
                wall.vertices[5],
                wall.vertices[6],
                wall.vertices[7],
                wall.vertices[8],
                style.get_wall_color()
            )
        else
            wallquads:add_quad(
                wall.vertices[1],
                wall.vertices[2],
                wall.vertices[3],
                wall.vertices[4],
                wall.vertices[5],
                wall.vertices[6],
                wall.vertices[7],
                wall.vertices[8],
                transform_hue(wall.hue_modifier, style.get_wall_color())
            )
        end
    end
end

function walls.empty()
    return #_walls == 0
end

function walls.clear()
    _walls = {}
end

return walls
