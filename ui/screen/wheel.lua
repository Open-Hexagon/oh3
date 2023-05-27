
local background = require("ui.screens.background")
local theme = require("ui.theme")
local transform = require("transform")
local ease = require("anim.ease")
local signal = require("anim.signal")

-- Title menu

-- Individual main menu buttons
local PanelButton = {}
PanelButton.__index = PanelButton

function PanelButton:select()
    self.radius:stop()
    self.radius:keyframe(1.5, 0.985, ease.out_sine)
    self.selected = true
end

function PanelButton:deselect()
    self.radius:stop()
    self.radius:keyframe(1.5, 0, ease.out_sine)
    self.selected = false
end

function PanelButton:draw()
    local outer_radius = background.panel_radius()
    local inner_radius = self.radius()
    if inner_radius == outer_radius then
        return
    end
    love.graphics.translate(background.x(), background.y())

    local a1 = self.angle()
    local a2 = a1 + ARC
    local x1, y1 = math.cos(a1), math.sin(a1)
    local x2, y2 = math.cos(a2), math.sin(a2)
    love.graphics.setColor(theme.title.main_color)
    local a, b, c, d = transform.scale(outer_radius, x1, y1, x2, y2)
    local e, f, g, h = transform.scale(inner_radius, x2, y2, x1, y1)
    love.graphics.polygon("fill", a, b, c, d, e, f, g, h)
    love.graphics.origin()
end

local function new_panel_button(angle)
    local temp = signal.new_queue()
    local newinst = setmetatable({
        angle = angle,
        radius = signal.lerp(background.panel_radius, background.pivot_radius, temp),
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

function wheel.handle_event(name, a, b, c, d, e, f) end

return wheel