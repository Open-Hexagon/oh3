local t = {}
local sin, cos = math.sin, math.cos

function t.get_orbit(start_pos, angle, distance, result)
    if result == nil then
        return start_pos[1] + cos(angle) * distance, start_pos[2] + sin(angle) * distance
    else
        result[1] = start_pos[1] + cos(angle) * distance
        result[2] = start_pos[2] + sin(angle) * distance
    end
end

function t.point_in_polygon(vertices, x, y)
    local result = false
    for i = 1, #vertices, 2 do
        local j = (i + 1) % #vertices + 1
        local x0, y0 = vertices[i], vertices[i + 1]
        local x1, y1 = vertices[j], vertices[j + 1]
        if (y0 > y) ~= (y1 > y) and x < (x1 - x0) * (y - y0) / (y1 - y0) + x0 then
            result = not result
        end
    end
    return result
end

return t
