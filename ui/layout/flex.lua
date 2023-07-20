local flex = {}
flex.__index = flex

function flex:new(options, elements)
    return setmetatable({
        direction = options.direction or "row",
        same_size = options.same_size or false,
        elements = elements,
        scale = 1,
    }, flex)
end

function flex:set_scale(scale)
    for i = 1, #self.elements do
        self.elements[i]:set_scale(scale)
    end
    self.scale = scale
end

function flex:calculate_layout(available_area)
    local element_area = {
        x = available_area.x,
        y = available_area.y,
        width = available_area.width,
        height = available_area.height,
    }
    if self.same_size then
        -- all elements are given the same area size
        if self.direction == "row" then
            element_area.width = element_area.width / #self.elements
        elseif self.direction == "column" then
            element_area.height = element_area.height / #self.elements
        end
        for i = 1, #self.elements do
            local width, height = self.elements[i]:calculate_layout(element_area)
            if self.direction == "row" then
                element_area.x = element_area.x + width
            elseif self.direction == "column" then
                element_area.y = element_area.y + height
            end
        end
    else
        -- calculate the total and individual size of all elements (in flex direction)
        local sizes = {}
        local total_size = 0
        local x = element_area.x
        local y = element_area.y
        for i = 1, #self.elements do
            local width, height = self.elements[i]:calculate_layout(element_area)
            if self.direction == "row" then
                element_area.x = element_area.x + width
                sizes[i] = width
                total_size = total_size + width
            elseif self.direction == "column" then
                element_area.y = element_area.y + height
                sizes[i] = height
                total_size = total_size + height
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
            local factor = target_size / total_size
            for i = 1, #sizes do
                element_area[target_property] = sizes[i] * factor
                local width, height = self.elements[i]:calculate_layout(element_area)
                if self.direction == "row" then
                    element_area.x = element_area.x + width
                elseif self.direction == "column" then
                    element_area.y = element_area.y + height
                end
            end
        end
    end
end

function flex:draw()
    for i = 1, #self.elements do
        self.elements[i]:draw()
    end
end

return flex
