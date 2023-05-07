local signal = require("anim.signal")
local layout = require("ui.layout")
local transform = require("transform")
local extmath = require("extmath")
local ease = require("anim.ease")

-- States
local STOP, TITLE, MENU = 1, 2, 3
local state = TITLE


local sides = 6

local main_color = { 1, 0.23, 0.13, 1 }
local panel_colors = {
    { 0.1, 0.02, 0.04, 1 },
    { 0.13, 0.02, 0.1, 1 },
}

local bicolor_shader = love.graphics.newShader("assets/image/title/bicolor.frag")

local title = {}

function title:load()
    self.position = signal.new_queue(0.25)
    self.y_open = signal.new_lerp(layout.TOP, layout.BOTTOM, self.position)
    self.y_hex = signal.new_lerp(layout.BOTTOM, layout.TOP, self.position)
    do
        self.img_open = love.graphics.newImage("assets/image/title/open.png")
        local width, height = self.img_open:getDimensions()
        self.img_open_center = love.math.newTransform()
        self.img_open_center:translate(width / -2, height / -2)
    end
    do
        self.img_hex = love.graphics.newImage("assets/image/title/hexagon.png")
        local width, height = self.img_hex:getDimensions()
        self.img_hex_center = love.math.newTransform()
        self.img_hex_center:translate(width / -2, height / -2)
    end
end

function title:enter()
    self.position:keyframe(0.2, -0.1, ease.in_back)
    self.position:call(function()
        state = TITLE
    end)
end

function title:exit()
    self.position:keyframe(0.2, 0.25, ease.out_back)
    self.position:call(function()
        state = MENU
    end)
end

function title:draw()
    local y_open = self.y_open()
    local y_hex = self.y_hex()
    local x = layout.CENTER_X()
    local scale = layout.width * 0.0003

    love.graphics.setShader(bicolor_shader)
    bicolor_shader:send("red", main_color)
    bicolor_shader:send("blue", { 1, 1, 1, 1 })

    love.graphics.push()
    love.graphics.translate(x, y_open)
    love.graphics.scale(scale)
    love.graphics.draw(self.img_open, self.img_open_center)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(x, y_hex)
    love.graphics.scale(scale)
    love.graphics.draw(self.img_hex, self.img_hex_center)
    love.graphics.pop()

    love.graphics.setShader()
end

local param = {}

param.x = signal.new_queue(0.5)
param.y = signal.new_queue(0.5)

param.pivot_radius = signal.new_queue(0.1)
param.border_thickness = signal.new_queue(0.15)

param.angle = signal.new_queue()
local function angle_loop()
    param.angle:waveform(2, function(t)
        return extmath.tau / 3 * t
    end)
    param.angle:call(angle_loop)
end
param.angle:call(angle_loop)

local background = {}

background.panel_radius = layout.RIGHT
background.x = signal.new_lerp(layout.LEFT, layout.RIGHT, param.x)
background.y = signal.new_lerp(layout.TOP, layout.BOTTOM, param.y)
background.pivot_radius = signal.new_lerp(layout.TOP, layout.BOTTOM, param.pivot_radius)
background.border_thickness = signal.new_lerp(signal.new_signal(0), background.pivot_radius, param.border_thickness)

-- local test_timeline = signal.new_queue()
-- test_timeline:persist()
-- test_timeline:wait(3)
-- test_timeline:call(function()
--     hexagon.x:keyframe(0.3, 0.3, ease.out_back)
--     hexagon.pivot_radius:keyframe(0.3, 0.2, ease.out_back)
--     hexagon.angle:stop()
--     local angle = hexagon.angle()
--     angle = angle + math.pi
--     angle = angle - angle % (extmath.tau / 3) + math.pi / 6
--     hexagon.angle:keyframe(0.3, angle, ease.out_back)
-- end)

local M = {}
function M.load()
    title:load()
end

function M.draw()
    local pivot_radius = background.pivot_radius()
    local border_thickness = background.border_thickness()

    local center = {}
    local arc = extmath.tau / sides
    love.graphics.translate(background.x(), background.y())
    for i = 0, sides - 1 do
        local a1 = i * arc + param.angle()
        local a2 = a1 + arc
        local x1, y1 = math.cos(a1), math.sin(a1)
        local x2, y2 = math.cos(a2), math.sin(a2)

        love.graphics.push()
        love.graphics.scale(background.panel_radius())
        love.graphics.setColor(unpack(panel_colors[i % #panel_colors + 1]))
        love.graphics.polygon("fill", 0, 0, x1, y1, x2, y2)
        love.graphics.pop()

        love.graphics.setColor(unpack(main_color))
        local a, b, c, d = transform.scale(pivot_radius, x1, y1, x2, y2)
        local e, f, g, h = transform.scale(pivot_radius - border_thickness, x2, y2, x1, y1)
        love.graphics.polygon("fill", a, b, c, d, e, f, g, h)
        table.insert(center, g)
        table.insert(center, h)
    end
    love.graphics.setColor(unpack(panel_colors[1]))
    love.graphics.polygon("fill", unpack(center))
    love.graphics.origin()

    title:draw()
end

local function get_angle(origin_x, origin_y, x, y)
    x, y = x - origin_x, y - origin_y
    local angle = math.atan2(y, x)
    return angle
end

function M.handle_event(name, a, b, c, d, e, f)
    if state == STOP then
        return
    end
    if name == "keypressed" and a == "tab" then
    elseif name == "mousemoved" then
        local angle = get_angle(background.x(), background.y(), a, b)

        -- selection = nil
        -- for _, btn in pairs(buttonlist) do
        --     if btn:check_cursor(a, b) then
        --         selection = btn
        --     end
        -- end
    elseif name == "mousereleased" then
        if state == TITLE then
            title:exit()
        else
            title:enter()
        end
    end
end

return M
