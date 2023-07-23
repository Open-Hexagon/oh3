local element = require("ui.elements.element")
local signal = require("ui.anim.signal")
local toggle = {}
toggle.__index = setmetatable(toggle, { __index = element })

function toggle:new(options)
    options = options or {}
    local obj = element.new(setmetatable({
        state = options.initial_state or false,
        state_indicator_offset = signal.new_queue(0),
        radius = options.radius or 32,
        background_color = { 0.5, 0.5, 0.5, 1 },
    }, toggle), options)
    obj.selectable = true
    obj.click_handler = function(elem)
        elem.state = not elem.state
        elem.state_indicator_offset:stop()
        if elem.state then
            elem.state_indicator_offset:keyframe(0.1, elem.radius * 2)
        else
            elem.state_indicator_offset:keyframe(0.1, 0)
        end
    end
    if obj.state then
        obj.state_indicator_offset:set_immediate_value(obj.radius * 2)
    end
    return obj
end

function toggle:set_style(style)
    self.background_color = self.style.background_color or style.background_color or self.background_color
    element.set_style(self, style)
end

function toggle:calculate_element_layout()
    -- max and min size is the same, so available area doesn't matter here at all
    local radius = self.radius * self.scale
    return radius * 4, radius * 2
end

function toggle:draw()
    local radius = self.radius * self.scale
    if self.state then
        -- TODO: replace temporary indicator color
        love.graphics.setColor(0.5, 0.5, 1, 1)
    else
        love.graphics.setColor(self.background_color)
    end
    love.graphics.circle("fill", self.bounds[1] + radius, self.bounds[2] + radius, radius)
    love.graphics.circle("fill", self.bounds[1] + 3 * radius, self.bounds[2] + radius, radius)
    love.graphics.rectangle("fill", self.bounds[1] + radius, self.bounds[2], 2 * radius, 2 * radius)
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.bounds[1] + radius + self.state_indicator_offset() * self.scale, self.bounds[2] + radius, radius)
    if self.selected then
        love.graphics.setLineWidth(self.scale)
        -- TODO: replace temporary selection color
        love.graphics.setColor(0, 0, 1, 1)
        love.graphics.circle("line", self.bounds[1] + radius + self.state_indicator_offset() * self.scale, self.bounds[2] + radius, radius)
    end
end

return toggle
