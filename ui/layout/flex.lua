local point_in_polygon = require("ui.point_in_polygon")
local flex = {}
flex.__index = flex

---create a new flex container
---@param elements table
---@param options table?
---@return table
function flex:new(elements, options)
    options = options or {}
    local obj = setmetatable({
        direction = options.direction or "row",
        same_size = options.same_size or false,
        elements = elements,
        scale = 1,
        scrollable = options.scrollable or false,
        needs_scroll = false,
        scroll = 0,
        external_scroll_offset = { 0, 0 },
        own_scroll_offset = { 0, 0 },
        bounds = {},
    }, flex)
    for i = 1, #elements do
        elements[i].parent = obj
        elements[i].parent_index = i
    end
    if options.style then
        obj:set_style(options.style)
    end
    return obj
end

---set the style of all children
---@param style table
function flex:set_style(style)
    for i = 1, #self.elements do
        self.elements[i]:set_style(style)
    end
end

---set the gui scale of all elements in the flex container
---@param scale number
function flex:set_scale(scale)
    for i = 1, #self.elements do
        self.elements[i]:set_scale(scale)
    end
    self.scale = scale
end

---have all children process an event
---@param name string
---@param ... unknown
function flex:process_event(name, ...)
    local is_outer = false
    if flex.scrolled_already == nil then
        is_outer = true
        flex.scrolled_already = false
    end
    for i = 1, #self.elements do
        self.elements[i]:process_event(name, ...)
    end
    if name == "wheelmoved" and self.needs_scroll and not flex.scrolled_already then
        local x, y = love.mouse.getPosition()
        if point_in_polygon(self.bounds, x + self.external_scroll_offset[1], y + self.external_scroll_offset[2]) then
            flex.scrolled_already = true
            local _, direction = ...
            self.scroll = self.scroll - 10 * direction
            if self.direction == "row" then
                self.own_scroll_offset[1] = self.scroll
            elseif self.direction == "column" then
                self.own_scroll_offset[2] = self.scroll
            end
            self:set_scroll_offset()
        end
    end
    if is_outer then
        flex.scrolled_already = nil
    end
end

---set scroll offset for this and child elements
---@param scroll_offset any
function flex:set_scroll_offset(scroll_offset)
    scroll_offset = scroll_offset or self.external_scroll_offset
    self.external_scroll_offset = scroll_offset
    local new_scroll_offset = {unpack(scroll_offset)}
    for i = 1, 2 do
        new_scroll_offset[i] = new_scroll_offset[i] + self.own_scroll_offset[i]
    end
    for i = 1, #self.elements do
        self.elements[i]:set_scroll_offset(new_scroll_offset)
    end
end

---calculate the positions and size of the elements in the container (returns total width and height)
---@param available_area table
---@return number
---@return number
function flex:calculate_layout(available_area)
    local element_area = {
        x = available_area.x,
        y = available_area.y,
        width = available_area.width,
        height = available_area.height,
    }
    local final_width, final_height
    if self.same_size then
        -- all elements are given the same area size
        local element_size
        if self.direction == "row" then
            element_area.width = element_area.width / #self.elements
            element_size = element_area.width
        elseif self.direction == "column" then
            element_area.height = element_area.height / #self.elements
            element_size = element_area.height
        end
        local new_element_size = 0
        local thickness = 0
        for i = 1, #self.elements do
            local width, height = self.elements[i]:calculate_layout(element_area)
            if self.direction == "row" then
                element_area.x = element_area.x + element_area.width
                new_element_size = math.max(width, new_element_size)
                thickness = math.max(thickness, height)
            elseif self.direction == "column" then
                element_area.y = element_area.y + element_area.height
                new_element_size = math.max(height, new_element_size)
                thickness = math.max(thickness, width)
            end
        end
        -- check if elements fit in the area and if not provide them with a large still same size area so they barely fit
        if new_element_size > element_size then
            element_area.x = available_area.x
            element_area.y = available_area.y
            if self.direction == "row" then
                element_area.width = new_element_size
            elseif self.direction == "column" then
                element_area.height = new_element_size
            end
            thickness = 0
            for i = 1, #self.elements do
                local width, height = self.elements[i]:calculate_layout(element_area)
                if self.direction == "row" then
                    element_area.x = element_area.x + new_element_size
                    thickness = math.max(thickness, height)
                elseif self.direction == "column" then
                    element_area.y = element_area.y + new_element_size
                    thickness = math.max(thickness, width)
                end
            end
            element_size = new_element_size
        end
        if self.direction == "row" then
            final_width = element_size * #self.elements
            final_height = thickness
        elseif self.direction == "column" then
            final_width = thickness
            final_height = element_size * #self.elements
        end
    else
        -- calculate the total and individual size of all elements (in flex direction)
        local sizes = {}
        local total_size = 0
        local x = element_area.x
        local y = element_area.y
        local thickness = 0
        for i = 1, #self.elements do
            local width, height = self.elements[i]:calculate_layout(element_area)
            if self.direction == "row" then
                element_area.x = element_area.x + width
                sizes[i] = width
                total_size = total_size + width
                thickness = math.max(thickness, height)
            elseif self.direction == "column" then
                element_area.y = element_area.y + height
                sizes[i] = height
                total_size = total_size + height
                thickness = math.max(thickness, width)
            end
        end
        local target_size, target_property
        if self.direction == "row" then
            target_size = element_area.width
            target_property = "width"
        elseif self.direction == "column" then
            target_size = element_area.height
            target_property = "height"
        end
        -- if the total size of all elements is too big then scale down each individual area calculated in the last step and give it to the element as available area (this way the ratio between element sizes is preserved)
        if total_size > target_size then
            element_area.x = x
            element_area.y = y
            thickness = 0
            local factor = target_size / total_size
            for i = 1, #sizes do
                element_area[target_property] = sizes[i] * factor
                local width, height = self.elements[i]:calculate_layout(element_area)
                if self.direction == "row" then
                    element_area.x = element_area.x + width
                    thickness = math.max(thickness, height)
                elseif self.direction == "column" then
                    element_area.y = element_area.y + height
                    thickness = math.max(thickness, width)
                end
            end
        end
        if self.direction == "row" then
            final_width = element_area.x - x
            final_height = thickness
        elseif self.direction == "column" then
            final_width = thickness
            final_height = element_area.y - y
        end
    end
    self.needs_scroll = false
    if self.scrollable then
        if self.direction == "row" then
            if final_width > available_area.width then
                final_width = available_area.width
                self.needs_scroll = true
            end
        elseif self.direction == "column" then
            if final_height > available_area.height then
                final_height = available_area.height
                self.needs_scroll = true
            end
        end
        if not self.canvas or self.canvas:getWidth() ~= final_width or self.canvas:getHeight() ~= final_height then
            self.canvas = love.graphics.newCanvas(final_width, final_height, {
                -- TODO: make configurable
                msaa = 4,
            })
        end
    end
    if not self.needs_scroll then
        self.scroll = 0
        self.own_scroll_offset = { 0, 0 }
        self:set_scroll_offset()
    end
    self.bounds = {
        available_area.x,
        available_area.y,
        available_area.x + final_width,
        available_area.y,
        available_area.x + final_width,
        available_area.y + final_height,
        available_area.x,
        available_area.y + final_height,
    }
    return final_width, final_height
end

---draw all the elements in the container
function flex:draw()
    if self.needs_scroll then
        love.graphics.push()
        local before_canvas = love.graphics.getCanvas()
        love.graphics.setCanvas(self.canvas)
        love.graphics.origin()
        love.graphics.translate(-self.bounds[1], -self.bounds[2])
        love.graphics.clear(0, 0, 0, 0)
        if self.direction == "row" then
            love.graphics.translate(-math.floor(self.scroll), 0)
        elseif self.direction == "column" then
            love.graphics.translate(0, -math.floor(self.scroll))
        end
        for i = 1, #self.elements do
            self.elements[i]:draw()
        end
        love.graphics.setCanvas(before_canvas)
        love.graphics.pop()
        love.graphics.draw(self.canvas, self.bounds[1], self.bounds[2])
    else
        for i = 1, #self.elements do
            self.elements[i]:draw()
        end
    end
end

return flex
