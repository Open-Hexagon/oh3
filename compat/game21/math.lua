local utils = require("compat.game192.utils")
local t = {}
local sin, cos = math.sin, math.cos

function t.get_orbit(start_pos, angle, distance, result)
    angle = utils.float_round(angle)
    distance = utils.float_round(distance)
    start_pos[1] = utils.float_round(start_pos[1])
    start_pos[2] = utils.float_round(start_pos[2])
    if result == nil then
        return utils.float_round(start_pos[1] + cos(angle) * distance), utils.float_round(start_pos[2] + sin(angle) * distance)
    else
        result[1] = utils.float_round(start_pos[1] + cos(angle) * distance)
        result[2] = utils.float_round(start_pos[2] + sin(angle) * distance)
    end
end

function t.point_in_polygon(vertices, x, y)
    x = utils.float_round(x)
    y = utils.float_round(y)
    local result = false
    for i = 1, #vertices, 2 do
        local j = (i + 1) % #vertices + 1
        local x0, y0 = utils.float_round(vertices[i]), utils.float_round(vertices[i + 1])
        local x1, y1 = utils.float_round(vertices[j]), utils.float_round(vertices[j + 1])
        if (y0 > y) ~= (y1 > y) and x < (x1 - x0) * (y - y0) / (y1 - y0) + x0 then
            result = not result
        end
    end
    return result
end

return t
