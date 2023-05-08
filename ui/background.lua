local signal = require("anim.signal")
local layout = require("ui.layout")
local transform = require("transform")
local extmath = require("extmath")
local ease = require("anim.ease")

-- States
local STOP, TITLE, MENU = 1, 2, 3
local state = TITLE

local sides = 6
local ARC = extmath.tau / 6

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
    self.disabled = false
end

function title:enter()
    title.disabled = false
    self.position:keyframe(0.2, 0.25, ease.out_back)
    self.position:call(function()
        state = TITLE
    end)
end

function title:exit()
    self.position:keyframe(0.2, -0.1, ease.out_back)
    self.position:call(function()
        state = MENU
        title.disabled = true
    end)
end

function title:draw()
    if self.disabled then
        return
    end
    local y_open = self.y_open()
    local y_hex = self.y_hex()
    local x = layout.CENTER_X()
    local scale = layout.MINOR() * 0.00045

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

local background = {}

function background:load()
    self.angle = signal.new_queue()
    self:loop()
    self.panel_radius = layout.MAJOR

    local temp_x = signal.new_queue(0.5)
    local temp_y = signal.new_queue(0.5)
    local temp_pivot_radius = signal.new_queue(0.1)
    local temp_border_thickness = signal.new_queue(0.15)

    self.x = signal.wrap(signal.new_lerp(layout.LEFT, layout.RIGHT, temp_x), temp_x) --[[@as Queue]]
    self.y = signal.wrap(signal.new_lerp(layout.TOP, layout.BOTTOM, temp_y), temp_y) --[[@as Queue]]
    self.pivot_radius = signal.wrap(signal.new_product(layout.MINOR, temp_pivot_radius), temp_pivot_radius) --[[@as Queue]]
    self.border_thickness =
        signal.wrap(signal.new_product(self.pivot_radius, temp_border_thickness), temp_border_thickness) --[[@as Queue]]
end

local function angle_loop()
    background.angle:waveform(2, function(t)
        return extmath.tau / 3 * t
    end)
    background.angle:call(angle_loop)
end

function background:loop()
    self.angle:call(angle_loop)
end

function background:draw()
    local pivot_radius = self.pivot_radius()
    local border_thickness = self.border_thickness()

    local center = {}
    love.graphics.translate(self.x(), self.y())
    for i = 0, sides - 1 do
        local a1 = i * ARC + self.angle()
        local a2 = a1 + ARC
        local x1, y1 = math.cos(a1), math.sin(a1)
        local x2, y2 = math.cos(a2), math.sin(a2)

        love.graphics.push()
        love.graphics.scale(self.panel_radius())
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
end

local PanelButton = {}
PanelButton.__index = PanelButton

function PanelButton:select()
    self.radius:keyframe(0.15, 0.985, ease.out_sine)
    self.selected = true
end

function PanelButton:deselect()
    self.radius:keyframe(0.15, 0, ease.out_sine)
    self.selected = false
end

function PanelButton:draw()
    local outer_radius = background.panel_radius()
    local inner_radius = self.radius()
    love.graphics.translate(background.x(), background.y())

    local a1 = self.angle()
    local a2 = a1 + ARC
    local x1, y1 = math.cos(a1), math.sin(a1)
    local x2, y2 = math.cos(a2), math.sin(a2)
    love.graphics.setColor(main_color)
    local a, b, c, d = transform.scale(outer_radius, x1, y1, x2, y2)
    local e, f, g, h = transform.scale(inner_radius, x2, y2, x1, y1)
    love.graphics.polygon("fill", a, b, c, d, e, f, g, h)
    love.graphics.origin()
end

local function new_panel_button(angle)
    local temp = signal.new_queue()
    local newinst = setmetatable({
        angle = angle,
        radius = signal.wrap(signal.new_lerp(background.panel_radius, background.pivot_radius, temp), temp),
        selected = false,
    }, PanelButton)
    return newinst
end

local wheel = {}

function wheel:load()
    self.angle = signal.new_queue()
    self.panels = {}
    for i = -3, 2 do
        self.panels[i] = new_panel_button(signal.new_sum(self.angle, (i - 0.5) * ARC))
    end
    self.disable_selection()
    self.disable_drawing()
end

function wheel:check_cursor(x, y)
    if self.selection_disabled then
        return
    end
    local x0, y0 = layout.width * 0.35, layout.center_y
    x, y = x - x0, y - y0
    if extmath.alpha_max_beta_min(x, y) < background.pivot_radius() * 0.866 then
    else
        x, y = transform.rotate(math.pi / 6, x, y)
        local angle = math.atan2(y, x)
        for i, panel in pairs(self.panels) do
            local a1 = i * ARC
            local a2 = a1 + ARC
            if i * ARC < angle and angle < a2 then
                if not panel.selected then
                    panel:select()
                end
            else
                if panel.selected then
                    panel:deselect()
                end
            end
        end
    end
end

function wheel:draw()
    if self.drawing_disabled then
        return
    end
    for _, panel in pairs(self.panels) do
        panel:draw()
    end
end

function wheel.disable_selection()
    wheel.selection_disabled = true
    for _, panel in pairs(wheel.panels) do
        if panel.selected then
            panel:deselect()
        end
    end
end
function wheel.enable_selection()
    wheel.selection_disabled = false
end

function wheel.disable_drawing()
    wheel.drawing_disabled = true
end
function wheel.enable_drawing()
    wheel.drawing_disabled = false
end

local animate = {}

function animate.title_to_menu()
    title:exit()

    local time = 0.3

    background.x:keyframe(time, 0.35, ease.out_back)
    background.pivot_radius:keyframe(time, 0.2, ease.out_back)
    background.angle:stop()
    local angle = background.angle()
    local target = angle + math.pi
    target = target - target % (extmath.tau / 3) + math.pi / 6
    background.angle:keyframe(time, target, ease.out_back)

    wheel.enable_drawing()
    wheel.enable_selection()
    local rotate = target - angle
    wheel.angle:set_value(-rotate)
    wheel.angle:keyframe(time, 0, ease.out_back)
end

function animate.menu_to_title()
    title:enter()

    background.x:keyframe(0.3, 0.5, ease.out_back)
    background.pivot_radius:keyframe(0.3, 0.1, ease.out_back)
    local angle = background.angle()
    background.angle:keyframe(0.3, angle + math.pi / 2, ease.out_sine)
    background:loop()

    wheel.disable_selection()
    wheel.angle:keyframe(0.3, math.pi / 2, ease.out_sine)
    wheel.angle:set_value(0)
    wheel.angle:call(wheel.disable_drawing)
end

local M = {}
function M.load()
    title:load()
    background:load()
    wheel:load()
end

function M.draw()
    background:draw()
    wheel:draw()
    title:draw()
end

function M.handle_event(name, a, b, c, d, e, f)
    if state == STOP then
        return
    end
    if name == "keypressed" and a == "tab" then
    elseif name == "mousemoved" then
        wheel:check_cursor(a, b)
        -- selection = nil
        -- for _, btn in pairs(buttonlist) do
        --     if btn:check_cursor(a, b) then
        --         selection = btn
        --     end
        -- end
    elseif name == "mousereleased" then
        if state == TITLE then
            animate.title_to_menu()
        else
            animate.menu_to_title()
        end
        wheel:check_cursor(a, b)
    end
end

return M
