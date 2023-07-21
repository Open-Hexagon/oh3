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
    }, flex)
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
---@param ... unknown
function flex:process_event(...)
    for i = 1, #self.elements do
        self.elements[i]:process_event(...)
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
    return final_width, final_height
end

---draw all the elements in the container
function flex:draw()
    for i = 1, #self.elements do
        self.elements[i]:draw()
    end
end

return flex
