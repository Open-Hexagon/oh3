local background_dimension = require("ui.screen.background").dimension
local theme = require("ui.theme")
local transform = require("transform")
local ease = require("anim.ease")
local signal = require("anim.signal")
local extmath = require("extmath")
local layout = require("ui.layout")

-- Title menu

---@type Screen
local wheel = {}
wheel.angle = 0

-- Individual main menu buttons
---@class PanelButton
---@field a1 number
---@field a2 number
---@field condition function
---@field radius Queue
local PanelButton = {}
PanelButton.__index = PanelButton

function PanelButton:select()
    self.radius:stop()
    self.radius:keyframe(0.15, 0.985, ease.out_sine)
end

function PanelButton:deselect()
    self.radius:stop()
    self.radius:keyframe(0.15, 0, ease.out_sine)
end

function PanelButton:check_angle(angle)
    return self.condition(angle, self.a1, self.a2)
end

function PanelButton:draw()
    local radius = self.radius()
    if radius == 0 then
        return
    end

    local outer_radius = layout.major
    local inner_radius = extmath.lerp(outer_radius, background_dimension.pivot_radius(), radius)

    love.graphics.translate(background_dimension.x(), background_dimension.y())
    local angle = background_dimension.angle() + wheel.angle
    local a1, a2 = self.a1 + angle, self.a2 + angle
    local x1, y1 = math.cos(a1), math.sin(a1)
    local x2, y2 = math.cos(a2), math.sin(a2)
    love.graphics.setColor(theme.title.main_color)
    local a, b, c, d = transform.scale(outer_radius, x1, y1, x2, y2)
    local e, f, g, h = transform.scale(inner_radius, x2, y2, x1, y1)
    love.graphics.polygon("fill", a, b, c, d, e, f, g, h)
    love.graphics.origin()
end

local function new_panel_button(a1, a2, condition)
    local newinst = setmetatable({
        a1 = a1,
        a2 = a2,
        condition = condition
    }, PanelButton)
    newinst.radius = signal.new_queue(0)
    return newinst
end

--[[
    -5pi/6, -3pi/6
    -3pi/6, -pi/6
    pi/6, 3pi/6
    3pi/6, 5pi/6
    5pi/6, -5pi/6
]]

local panels = {}
do
    local function between(angle, a1, a2)
        return a1 <= angle and angle < a2
    end
    local function not_between(angle, a1, a2)
        return not (a1 <= angle and angle < a2)
    end
    local pi56, pi12, pi16 = 5 * math.pi / 6, math.pi / 2, math.pi / 6
    table.insert(panels, new_panel_button(-pi16, pi16, between)) -- Play
    table.insert(panels, new_panel_button(pi16, pi12, between)) -- Exit
    table.insert(panels, new_panel_button(-pi56, pi56, not_between)) -- Settings
end

---@type PanelButton?
local selection

local function clear_selection()
    if selection then
        selection:deselect()
        selection = nil
    end
end

local function check_cursor(x, y)
    local x0, y0 = layout.width * 0.35, layout.center_y
    x, y = x - x0, y - y0
    if extmath.alpha_max_beta_min(x, y) < background_dimension.pivot_radius() * 0.866 then
        -- Cursor is in center
        print("center")
    else
        local angle = math.atan2(y, x)
        for _, panel in pairs(panels) do
            if panel:check_angle(angle) then
                if selection ~= panel then
                    clear_selection()
                    panel:select()
                    selection = panel
                end
                return
            end
        end
    end
    clear_selection()
end

function wheel.open()
    local x, y = love.mouse.getPosition()
    check_cursor(x, y)
end

function wheel.draw()
    for _, panel in pairs(panels) do
        panel:draw()
    end
end

function wheel.handle_event(name, a, b, c, d, e, f)
    if name == "mousefocus" and not a then
        clear_selection()
    elseif name == "mousemoved" then
        check_cursor(a, b)
    elseif name == "mousereleased" then
        if not selection then
            return "menu_to_title"
        end
    end
end

return { screen = wheel }
