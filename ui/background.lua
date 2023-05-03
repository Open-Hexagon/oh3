local layout = require "ui.layout"
local transform = require "transform"

local sides = 6
local panel_radius = 1600
local pivot_radius = 50
local border_thickness = 5

local panel_colors = {
    { 0.2, 0.2, 0.2, 1 },
    { 0.3, 0.3, 0.3, 1 }
}

local center_color = { 1, 1, 1, 0.3 }
local border_color = { 1, 1, 1, 1 }

local rotation_speed = 0.3
local angle = 0

local background = {}

function background.update(dt)
    angle = angle + rotation_speed * dt
    if angle > 2 * math.pi then
        angle = angle - 2 * math.pi
    end
end

function background.handle_event()

end

function background.draw()
    local center = {}
    local arc = 2 * math.pi / sides
    for i = 0, sides - 1 do
        local a1 = i * arc + angle
        local a2 = a1 + arc
        local x1, y1 = math.cos(a1), math.sin(a1)
        local x2, y2 = math.cos(a2), math.sin(a2)

        love.graphics.setColor(unpack(panel_colors[i % #panel_colors + 1]))
        love.graphics.polygon("fill", transform.translate(layout.center_x, layout.center_y, 0, 0, transform.scale(panel_radius, x1, y1, x2, y2)))
        love.graphics.setColor(unpack(border_color))
        local a, b, c, d = transform.scale(pivot_radius, x1, y1, x2, y2)
        local e, f, g, h = transform.scale(pivot_radius - border_thickness, x2, y2, x1, y1)
        love.graphics.polygon("fill", transform.translate(layout.center_x, layout.center_y, a, b, c, d, e, f, g, h))
        table.insert(center, g)
        table.insert(center, h)
    end
    love.graphics.setColor(unpack(center_color))
    love.graphics.polygon("fill", transform.translate(layout.center_x, layout.center_y, unpack(center)))
end

return background
