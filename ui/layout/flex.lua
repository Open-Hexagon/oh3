local flex = {}
flex.__index = flex
-- ensure that changed is set to true when any property in the change_map is changed
flex.__newindex = function(t, key, value)
    if t.change_map[key] and t[key] ~= value then
        t.changed = true
    end
    rawset(t, key, value)
end

---create a new flex container
---@param elements table
---@param options table?
---@return table
function flex:new(elements, options)
    options = options or {}
    local obj = setmetatable({
        -- direction the flex container will position elements in
        direction = options.direction or "row",
        -- size ratios of the elements, length has to be identical to elements list
        size_ratios = options.size_ratios,
        -- aligns items on the container's thickness (values are "start", "stretch", "center" and "end")
        align_items = options.align_items or "start",
        -- set if aligning happens relative to given "area" or to total "thickness"
        align_relative_to = options.align_relative_to or "area",
        elements = elements,
        scale = 1,
        style = {},
        -- transform the user can modify
        transform = love.math.newTransform(),
        -- transform used for internal layouting
        _transform = love.math.newTransform(),
        -- store last available area in order to only recalculate this container's layout in response to mutation
        last_available_width = 0,
        last_available_height = 0,
        -- last resulting width and height
        width = 0,
        height = 0,
        -- something changed, requires layout recalculation
        changed = true,
        change_map = {
            direction = true,
            size_ratios = true,
            align_items = true,
            align_relative_to = true,
            scale = true,
        },
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
    self.style = style
end

---set the gui scale of all elements in the flex container
---@param scale number
function flex:set_scale(scale)
    for i = 1, #self.elements do
        self.elements[i]:set_scale(scale)
    end
    self.scale = scale
end

---update the container when a child element changed size or when elements were added or removed
function flex:mutated()
    for i = 1, #self.elements do
        local element = self.elements[i]
        element.parent = self
        element.parent_index = i
        element:set_scale(self.scale)
        element:set_style(self.style)
        if element.changed then
            self.changed = true
        end
    end
    self:calculate_layout(self.last_available_width, self.last_available_height)
end

---send an event for the children to process (returns true if propagation should be stopped)
---@param name string
---@param ... unknown
---@return boolean?
function flex:process_event(name, ...)
    love.graphics.push()
    love.graphics.applyTransform(self._transform)
    love.graphics.applyTransform(self.transform)
    for i = 1, #self.elements do
        if self.elements[i]:process_event(name, ...) then
            return true
        end
    end
    love.graphics.pop()
end

---calculate the positions and size of the elements in the container (returns total width and height)
---@param width number
---@param height number
---@return number
---@return number
function flex:calculate_layout(width, height)
    if self.last_available_width == width and self.last_available_height == height and not self.changed then
        return self.width, self.height
    end
    self.last_available_width = width
    self.last_available_height = height
    -- define some useful values and functions depending on direction (this prevents cluttering the code with lots of ifs for the direction)
    local available_length, available_thickness, lt2wh, wh2lt
    if self.direction == "row" then
        -- container is a row
        -- +---+---+---+---+---+ ^
        -- |   |   |   |   |   | | thickness
        -- +---+---+---+---+---+ v
        -- <------------------->
        --        length
        available_length = width
        available_thickness = height
        --converts length and thickness to width and height (defaults to avalable area)
        lt2wh = function(length, thickness)
            return length or available_length, thickness or available_thickness
        end
        --converts witdth and height to length and thickness
        wh2lt = function(w, h)
            return w, h
        end
    else
        -- container is a column
        -- +---+ ^
        -- |   | |
        -- +---+ |
        -- |   | |
        -- +---+ |
        -- |   | | length
        -- +---+ |
        -- |   | |
        -- +---+ |
        -- |   | |
        -- +---+ v
        -- <--->
        --  thickness
        available_thickness = width
        available_length = height
        --converts length and thickness to width and height (defaults to avalable area)
        lt2wh = function(length, thickness)
            return thickness or available_thickness, length or available_length
        end
        --converts witdth and height to length and thickness
        wh2lt = function(w, h)
            return h, w
        end
    end
    if self.align_items == "stretch" then
        for i = 1, #self.elements do
            self.elements[i].flex_expand = self.direction == "row" and 2 or 1
        end
    end
    local final_thickness = 0
    local final_length = 0
    if self.size_ratios then
        -- available length is divided according to the given ratios
        -- e.g. this would be the result of this table: {1, 2, 1}
        -- +---+-------+---+
        -- | 1 |   2   | 1 |
        -- +---+-------+---+
        local ratio_sum = 0
        for i = 1, #self.size_ratios do
            ratio_sum = ratio_sum + self.size_ratios[i]
        end
        -- ratio_size_unit * ratio number in list = size of element (in length)
        local ratio_size_unit = available_length / ratio_sum
        local scale_factor = 1
        local length = 0
        local thickness = 0
        for i = 1, #self.elements do
            local size = self.size_ratios[i] * ratio_size_unit
            local len, thick = wh2lt(self.elements[i]:calculate_layout(lt2wh(size)))
            if len > size or thick > available_thickness then
                scale_factor = math.max(scale_factor, math.max(len / size, thick / available_thickness))
            end
            local transform = self.elements[i]._transform
            transform:reset()
            transform:translate(lt2wh(length, 0))
            length = length + size
            thickness = math.max(thickness, thick)
        end
        -- check if elements fit in the area
        if scale_factor ~= 1 then
            -- they don't fit, return larger area causing the gui scale to lower
            return width * scale_factor, height * scale_factor
        end
        -- size ratio layout calculation done
        final_length = length
        final_thickness = thickness
    else
        -- calculate the total and individual size of all elements (in flex direction)
        local sizes = {}
        local length = 0
        local thickness = 0
        for i = 1, #self.elements do
            -- give every element the whole area of the container and see how much space they take for now
            local len, thick = wh2lt(self.elements[i]:calculate_layout(lt2wh()))
            -- transform the element to its position
            local transform = self.elements[i]._transform
            transform:reset()
            transform:translate(lt2wh(length, 0))
            -- store the space it took
            sizes[i] = len
            -- add the space to the total space
            length = length + len
            thickness = math.max(thickness, thick)
        end
        if length > available_length then
            -- All elements together take too much size.
            -- possible output from the first step:
            -- +-----+----------+
            -- |     |          |
            -- +-----+----------+
            -- <---->
            --  available length
            local new_sizes = {}
            local last_sizes = {}
            for i = 1, #sizes do
                last_sizes[i] = sizes[i]
            end
            local too_large_set = {}
            local must_stop = false
            local original_length = length
            repeat
                -- calculate the total length of all elements that can no longer shrink (this is 0 for the first iteration)
                local taken = 0
                -- also calculate the amount of space that these elements took in the original attempt
                local original_taken = 0
                for i = 1, #new_sizes do
                    if new_sizes[i] ~= 0 or new_sizes[i] == sizes[i] then
                        taken = taken + new_sizes[i]
                        original_taken = original_taken + sizes[i]
                    end
                end
                -- if all elements can no longer shrink and still don't fit abort (gui scale will be lowered)
                if taken > available_length then
                    break
                end
                -- calculate a factor for scaling down each elements size so it barely fits
                -- if all elements manage to shrink the result from the above example would look like this:
                -- +-+--+
                -- | |  |
                -- +-+--+
                -- if some couldn't shrink in the last iteration then only scale down the remaining elements
                -- +--+--+
                -- |  |  | < this one must be scaled down more accordingly
                -- +--+--+                                               +-+
                --  ^                                                    | |
                --  couldn't shrink to fit in the prior calculated area: +-+
                --
                -- the scale factor is calculated like this like this:
                --   available_length - taken = now available length to fit all possibly shrinkable elements
                --   original_length - original_taken = total length the now possibly shrinkable elements took in the first attempt
                --   (original_length - original_taken) * factor = available_length - taken
                local factor = (available_length - taken) / (original_length - original_taken)
                thickness = 0
                length = 0
                for i = 1, #sizes do
                    local len, thick = wh2lt(self.elements[i].width, self.elements[i].height)
                    local target_length = sizes[i] * factor
                    -- only recalculate possibly shrinkable element layouts
                    if not too_large_set[i] then
                        len, thick = wh2lt(self.elements[i]:calculate_layout(lt2wh(target_length)))
                    end
                    if len > target_length then
                        too_large_set[i] = true
                        new_sizes[i] = len
                    else
                        -- keep array dimensions and order consistent
                        new_sizes[i] = 0
                    end
                    -- transform the element to its new position
                    local transform = self.elements[i]._transform
                    transform:reset()
                    transform:translate(lt2wh(length, 0))
                    length = length + len
                    thickness = math.max(thickness, thick)
                end
                -- stop if sizes didn't change from the last iteration
                must_stop = true
                for i = 1, #new_sizes do
                    if new_sizes[i] ~= last_sizes[i] then
                        must_stop = false
                        last_sizes[i] = new_sizes[i]
                    end
                end
            until length <= available_length or must_stop
        end
        -- default flex layout calculation done
        final_length = length
        final_thickness = thickness
    end

    -- align_relative_to example:
    -- available area:
    -- +-----------+
    -- |           |
    -- |           |
    -- |           |
    -- +-----------+
    -- without align:
    -- +---+---+---+
    -- |   +---+   |
    -- +---+   |   |
    -- |       +---+
    -- +-----------+
    -- align end relative to area
    -- +-----------+ ^
    -- |       +---+ |
    -- +---+   |   | | area height
    -- |   +---+   | |
    -- +---+---+---+ v
    -- align end relative to thickness
    -- +-------+---+ ^
    -- +---+   |   | |
    -- |   +---+   | | thickness
    -- +---+---+---+ v
    -- +-----------+
    if self.align_relative_to ~= "area" and self.align_relative_to ~= "thickness" then
        error("Invalid value for align_relative_to: '" .. self.align_relative_to .. "'.")
    end
    -- no need to do anything on "start" it's the default
    if self.align_items ~= "start" then
        if self.align_relative_to == "area" then
            final_thickness = math.max(final_thickness, available_thickness)
        end
    end
    if self.align_items == "stretch" then
        for i = 1, #self.elements do
            self.elements[i].flex_expand = nil
        end
    elseif self.align_items == "center" then
        for i = 1, #self.elements do
            local elem = self.elements[i]
            local _, thick = wh2lt(elem.width, elem.height)
            elem._transform:translate(lt2wh(0, final_thickness / 2 - thick / 2))
        end
    elseif self.align_items == "end" then
        for i = 1, #self.elements do
            local elem = self.elements[i]
            local _, thick = wh2lt(elem.width, elem.height)
            elem._transform:translate(lt2wh(0, final_thickness / 2 - thick / 2))
        end
    elseif self.align_items ~= "start" then
        error(
            "Invalid value for align_items option '"
                .. self.align_items
                .. "' possible values are: 'start', 'center', 'end' and 'stretch'"
        )
    end

    self.width, self.height = lt2wh(final_length, final_thickness)
    self.changed = false
    return self.width, self.height
end

---draw all the elements in the container
function flex:draw()
    love.graphics.push()
    love.graphics.applyTransform(self._transform)
    love.graphics.applyTransform(self.transform)
    for i = 1, #self.elements do
        self.elements[i]:draw()
    end
    love.graphics.pop()
end

return flex
