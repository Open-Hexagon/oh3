local element = {}
element.__index = element

function element:new(options)
    options = options or {}
    self.style = options.style or {}
    self.scale = 1
    self.padding = 8
    self.color = { 1, 1, 1, 1 }
    if options.style then
        self:set_style(options.style)
    end
    return self
end

function element:set_style(style)
    self.padding = self.style.padding or style.padding or self.padding
    self.color = self.style.color or style.color or self.color
end

function element:set_scale(scale)
    self.scale = scale
end

return element
