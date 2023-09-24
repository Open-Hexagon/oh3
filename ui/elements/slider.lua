local keyboard_navigation = require("ui.keyboard_navigation")
local element = require("ui.elements.element")
local signal = require("ui.anim.signal")
local extmath = require("ui.extmath")
local slider = {}
slider.__index = setmetatable(slider, { __index = element })

function slider:new(options)
    options = options or {}
    local obj = element.new(
        setmetatable({
            steps = (options.steps or 3) - 1,
            step_size = options.step_size or 40,
            state = options.initial_state or 0,
            radius = options.radius or 16,
            background_color = { 0.5, 0.5, 0.5, 1 },
            position = signal.new_queue(0),
        }, slider),
        options
    )
    obj.selectable = true
    obj.position:set_immediate_value(obj.state)
    return obj
end

function slider:process_event(name, ...)
    element.process_event(self, name, ...)
    local last_state = self.state
    if name == "wheelmoved" and self.is_mouse_over and self:check_screen() then
        self.selected = true
        keyboard_navigation.select_element(self)
        if self.selection_handler then
            if self.selection_handler(self) then
                return true
            end
        end
        local _, direction = ...
        self.state = extmath.clamp(self.state - direction, 0, self.steps)
    end
    if (name == "mousemoved" or name == "mousepressed") and self.is_mouse_over and love.mouse.isDown(1) then
        self.state = math.floor((self.local_mouse_x - self.radius * self.scale) / (self.step_size * self.scale) + 0.5)
        self.state = extmath.clamp(self.state, 0, self.steps)
    end
    if name == "keypressed" and self.selected then
        local key = ...
        if key == "left" then
            self.state = extmath.clamp(self.state - 1, 0, self.steps)
        elseif key == "right" then
            self.state = extmath.clamp(self.state + 1, 0, self.steps)
        end
    end
    if self.state ~= last_state then
        self.position:stop()
        self.position:keyframe(0.1, self.state)
        return true
    end
end

function slider:set_style(style)
    self.background_color = self.style.background_color or style.background_color or self.background_color
    element.set_style(self, style)
end

function slider:calculate_element_layout()
    -- max and min size is the same, so available area doesn't matter here at all
    local diameter = self.radius * 2 * self.scale
    local width = self.steps * self.step_size * self.scale + diameter
    local height = diameter
    return width, height
end

function slider:draw_element()
    local radius = self.radius * self.scale
    local inner_radius = radius * 0.5
    local x = radius
    local y = radius
    local inner_width = self.steps * self.step_size * self.scale
    local segments = 100
    love.graphics.setColor(self.background_color)
    love.graphics.circle("fill", x, y, inner_radius, segments)
    love.graphics.circle("fill", x + inner_width, y, inner_radius, segments)
    love.graphics.rectangle("fill", x, y - inner_radius, inner_width, inner_radius * 2)
    love.graphics.setColor(self.color)
    local indicator_x = x + self.position() * self.step_size * self.scale
    love.graphics.circle("fill", indicator_x, y, radius, segments)
    if self.selected then
        -- TODO: add select border width option
        love.graphics.setLineWidth(self.scale)
        -- TODO: replace temporary selection color
        love.graphics.setColor(0, 0, 1, 1)
        love.graphics.circle("line", indicator_x, y, radius, segments)
    end
end

return slider
