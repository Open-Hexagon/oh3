local element = require("ui.elements.element")
local quad = {}
quad.__index = setmetatable(quad, {
    __index = element,
})

---create a new quad that can have a child element, offsetted vertices and a border
---@param options any
---@return table
function quad:new(options)
    options = options or {}
    local obj = element.new(
        setmetatable({
            vertex_offsets = options.vertex_offsets or { 0, 0, 0, 0, 0, 0, 0, 0 },
            element = options.child_element,
            border_thickness = 1,
            border_color = { 1, 1, 1, 1 },
            background_color = { 0, 0, 0, 1 },
            vertices = {},
        }, quad),
        options
    )
    if obj.element then
        obj.element.parent = obj
    end
    return obj
end

---set the style
---@param style table
function quad:set_style(style)
    if self.element then
        self.element:set_style(style)
    end
    self.background_color = self.style.background_color or style.background_color or self.color
    self.border_thickness = self.style.border_thickness or style.border_thickness or self.border_thickness
    self.border_color = self.style.border_color or style.border_color or self.border_color
end

---set the gui scale
---@param scale number
function quad:set_scale(scale)
    if self.element then
        self.element:set_scale(scale)
    end
    self.scale = scale
end

---process an event
---@param ... unknown
function quad:process_event(...)
    element.process_event(self, ...)
    if self.element then
        self.element:process_event(...)
    end
end

---set scroll offset
---@param scroll_offset table
function quad:set_scroll_offset(scroll_offset)
    self.scroll_offset = scroll_offset
    if self.element then
        self.element:set_scroll_offset(scroll_offset)
    end
end

---calculate the layout
---@param available_area table
---@return number
---@return number
function quad:calculate_layout(available_area)
    available_area = available_area or self.last_available_area
    local vertex_offsets = {}
    for i = 1, #self.vertex_offsets do
        -- offsets must be positive (outwards) and must be whole numbers
        vertex_offsets[i] = math.floor(math.abs(self.vertex_offsets[i]) * self.scale)
    end
    local top = math.max(vertex_offsets[2], vertex_offsets[4]) + self.padding
    local bot = math.max(vertex_offsets[6], vertex_offsets[8]) + self.padding
    local left = math.max(vertex_offsets[1], vertex_offsets[7]) + self.padding
    local right = math.max(vertex_offsets[3], vertex_offsets[5]) + self.padding
    local new_area = {
        x = available_area.x + left,
        y = available_area.y + top,
        width = available_area.width - right,
        height = available_area.height - bot,
    }
    local width, height
    if self.element then
        width, height = self.element:calculate_layout(new_area)
    else
        width = available_area.width - left - right
        height = available_area.height - top - bot
    end
    self.vertices[1] = new_area.x - vertex_offsets[1]
    self.vertices[2] = new_area.y - vertex_offsets[2]
    self.vertices[3] = new_area.x + width + vertex_offsets[3]
    self.vertices[4] = new_area.y - vertex_offsets[4]
    self.vertices[5] = new_area.x + width + vertex_offsets[5]
    self.vertices[6] = new_area.y + height + vertex_offsets[6]
    self.vertices[7] = new_area.x - vertex_offsets[7]
    self.vertices[8] = new_area.y + height + vertex_offsets[8]
    self.bounds = self.vertices
    self:_update_last_available_area(available_area)
    return left + width + right, top + height + bot
end

---draw the quad
function quad:draw()
    love.graphics.setColor(self.background_color)
    love.graphics.polygon("fill", self.vertices)
    love.graphics.setColor(self.border_color)
    love.graphics.setLineWidth(self.border_thickness * self.scale)
    love.graphics.polygon("line", self.vertices)
    if self.element then
        self.element:draw()
    end
end

return quad
