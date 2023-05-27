-- Background with center polygon and panels

local layout = require("ui.layout")
local theme = require("ui.theme")
local signal = require("anim.signal")
local transform = require("transform")
local extmath = require("extmath")
local ease = require("anim.ease")

-- TODO: match background as level preview

---@type Screen
local background = {}
background.pass = false

-- Can be a float but must be > 2
background.sides = signal.new_queue(6)
-- Background angle
background.radian_speed = signal.new_queue(math.pi / 2)
background.angle = signal.new_queue(0)
-- Background coordinates
background.x = signal.new_queue(0.5)
background.y = signal.new_queue(0.5)
-- A percentage of the minor window dimension
background.pivot_radius = signal.new_queue(0.1)
-- A percentage of the calculated pivot radius
background.border_thickness = signal.new_queue(0.15)

-- Absolute pixel values
local x_pos = signal.lerp(layout.LEFT, layout.RIGHT, background.x)
local y_pos = signal.lerp(layout.TOP, layout.BOTTOM, background.y)
local pivot_radius = background.pivot_radius * layout.MINOR
local border_thickness = pivot_radius * background.border_thickness

function background.draw()
    local center = {}
    love.graphics.translate(x_pos(), y_pos())

    local sides = background.sides()
    local isides = math.floor(sides)

    local arc = extmath.tau / sides

    local function draw_sector(a1, a2, panel_color)
        local x1, y1 = math.cos(a1), math.sin(a1)
        local x2, y2 = math.cos(a2), math.sin(a2)

        love.graphics.push()
        love.graphics.scale(layout.major)
        love.graphics.setColor(unpack(panel_color))
        love.graphics.polygon("fill", 0, 0, x1, y1, x2, y2)
        love.graphics.pop()

        love.graphics.setColor(unpack(theme.title.main_color))
        local a, b, c, d = transform.scale(pivot_radius(), x1, y1, x2, y2)
        local e, f, g, h = transform.scale(pivot_radius() - border_thickness(), x2, y2, x1, y1)
        love.graphics.polygon("fill", a, b, c, d, e, f, g, h)
        table.insert(center, g)
        table.insert(center, h)
    end

    local angle = background.angle()
    local a1 = angle
    local a2
    for i = 1, isides do
        a2 = i * arc + angle
        draw_sector(a1, a2, theme.title.panel_colors[i % #theme.title.panel_colors + 1])
        a1 = a2
    end
    if sides ~= isides then
        draw_sector(a1, angle, theme.title.panel_colors[1])
    end

    love.graphics.setColor(unpack(theme.title.panel_colors[1]))
    love.graphics.polygon("fill", unpack(center))
    love.graphics.origin()
end

function background.handle_event(name, a, b, c, d, e, f)
    if name == "mousereleased" then
        return "menu_to_title"
    end
end

function background.update(dt)
    local radian_speed = background.radian_speed()
    if radian_speed ~= 0 then
        local new_angle = (background.angle() + background.radian_speed() * dt) % extmath.tau
        background.angle:set_immediate_value(new_angle)
    end
end

return background
