local signal = require("ui.anim.signal")
local point_in_polygon = require("ui.extmath").point_in_polygon
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
        align_items = options.align_items or "start",
        elements = elements,
        scale = 1,
        scrollable = options.scrollable or false,
        needs_scroll = false,
        last_scroll_value = 0,
        scroll_target = 0,
        scroll = signal.new_queue(0),
        max_scroll = 0,
        external_scroll_offset = { 0, 0 },
        own_scroll_offset = { 0, 0 },
        scrollbar_visibility_timer = 0,
        scrollbar_vanish = true,
        scrollbar_color = { 1, 1, 1, 1 },
        scrollbar_width = 10,
        scrollbar_area = { x = 0, y = 0, width = 0, height = 0 },
        scrollbar_grabbed = false,
        last_mouse_pos = { 0, 0 },
        bounds = {},
        last_available_area = { x = 0, y = 0, width = 0, height = 0 },
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
    self.scrollbar_vanish = style.scrollbar_vanish or self.scrollbar_vanish
    self.scrollbar_color = style.scrollbar_color or self.scrollbar_color
    self.scrollbar_width = style.scrollbar_width or self.scrollbar_width
end

---set the gui scale of all elements in the flex container
---@param scale number
function flex:set_scale(scale)
    for i = 1, #self.elements do
        self.elements[i]:set_scale(scale)
    end
    self.scale = scale
end

local function clamp_scroll_target(self)
    if self.scroll_target > self.max_scroll then
        self.scroll_target = self.max_scroll
    elseif self.scroll_target < 0 then
        self.scroll_target = 0
    end
end

local function get_rect_bounds(bounds)
    local minmax = { math.huge, math.huge, -math.huge, -math.huge }
    for i = 1, #bounds, 2 do
        minmax[1] = math.min(bounds[i], minmax[1])
        minmax[2] = math.min(bounds[i + 1], minmax[2])
        minmax[3] = math.max(bounds[i], minmax[3])
        minmax[4] = math.max(bounds[i + 1], minmax[4])
    end
    return minmax
end

---scroll some bounds from this container into view
---@param bounds table
---@param instant boolean
function flex:scroll_into_view(bounds, instant)
    local minmax = get_rect_bounds(bounds)
    if self.needs_scroll then
        local scroll_before = self.scroll_target
        if self.direction == "row" then
            local visual_width = self.canvas:getWidth()
            if self.scroll_target + self.bounds[1] > minmax[1] then
                self.scroll_target = minmax[1] - self.bounds[1]
            elseif self.scroll_target + visual_width + self.bounds[1] < minmax[3] then
                self.scroll_target = minmax[3] - visual_width - self.bounds[1]
            end
        elseif self.direction == "column" then
            local visual_height = self.canvas:getHeight()
            if self.scroll_target + self.bounds[2] > minmax[2] then
                self.scroll_target = minmax[2] - self.bounds[2]
            elseif self.scroll_target + visual_height + self.bounds[2] < minmax[4] then
                self.scroll_target = minmax[4] - visual_height - self.bounds[2]
            end
        end
        clamp_scroll_target(self)
        if scroll_before ~= self.scroll_target then
            self.scroll:stop()
            if instant then
                self.scroll:set_immediate_value(self.scroll_target)
            else
                self.scroll:keyframe(0.2, self.scroll_target)
            end
            self.scrollbar_visibility_timer = love.timer.getTime()
        end
    end
end

local function point_in_scrollbar(self, x, y)
    return x >= self.scrollbar_area.x
        and y >= self.scrollbar_area.y
        and x <= self.scrollbar_area.x + self.scrollbar_area.width
        and y <= self.scrollbar_area.y + self.scrollbar_area.height
end

---have all children process an event
---@param name string
---@param ... unknown
function flex:process_event(name, ...)
    if flex.scrolled_already == nil then
        flex.scrolled_already = false
    end
    local propagate = true
    if name == "mousepressed" then
        local x, y = ...
        if point_in_scrollbar(self, x, y) then
            propagate = false
            self.scrollbar_grabbed = true
        end
        self.last_mouse_pos[1], self.last_mouse_pos[2] = x, y
    end
    if propagate then
        for i = 1, #self.elements do
            if self.elements[i]:process_event(name, ...) then
                return true
            end
        end
    end
    if name == "mousereleased" then
        self.scrollbar_grabbed = false
    end
    if name == "touchmoved" and self.needs_scroll and not self.scrollbar_grabbed then
        local mx, my = love.mouse.getPosition()
        local mouse_over_container = point_in_polygon(self.bounds, mx + self.external_scroll_offset[1], my + self.external_scroll_offset[2])
        local finger, x, y = ...
        if finger == self.last_finger and mouse_over_container then
            local dx = x - self.last_finger_x
            local dy = y - self.last_finger_y
            if self.direction == "row" then
                self.scroll_target = self.scroll_target - dx
            elseif self.direction == "column" then
                self.scroll_target = self.scroll_target - dy
            end
            flex.scrolled_already = true
            self.scrollbar_visibility_timer = love.timer.getTime()
            clamp_scroll_target(self)
            self.scroll:stop()
            self.scroll:set_immediate_value(self.scroll_target)
        end
        self.last_finger_x = x
        self.last_finger_y = y
        self.last_finger = finger
    end
    if name == "touchreleased" then
        self.last_finger = nil
        self.last_finger_x = nil
        self.last_finger_y = nil
    end
    if name == "mousemoved" and self.needs_scroll then
        local x, y = ...
        if self.scrollbar_grabbed and not flex.scrolled_already then
            local dx = x - self.last_mouse_pos[1]
            local dy = y - self.last_mouse_pos[2]
            if self.direction == "row" then
                local max_move = self.canvas:getWidth() - self.scrollbar_area.width
                self.scroll_target = self.scroll_target + dx * self.max_scroll / max_move
            elseif self.direction == "column" then
                local max_move = self.canvas:getHeight() - self.scrollbar_area.height
                self.scroll_target = self.scroll_target + dy * self.max_scroll / max_move
            end
            flex.scrolled_already = true
            self.scrollbar_visibility_timer = love.timer.getTime()
            clamp_scroll_target(self)
            self.scroll:stop()
            self.scroll:set_immediate_value(self.scroll_target)
        elseif point_in_scrollbar(self, x, y) then
            self.scrollbar_visibility_timer = love.timer.getTime()
        end
        self.last_mouse_pos[1], self.last_mouse_pos[2] = ...
    end
    if name == "wheelmoved" and self.needs_scroll and not flex.scrolled_already then
        local x, y = love.mouse.getPosition()
        if point_in_polygon(self.bounds, x + self.external_scroll_offset[1], y + self.external_scroll_offset[2]) then
            local _, direction = ...
            self.scroll_target = self.scroll_target - 30 * direction
            flex.scrolled_already = true
            self.scrollbar_visibility_timer = love.timer.getTime()
            clamp_scroll_target(self)
            self.scroll:stop()
            self.scroll:keyframe(0.1, self.scroll_target)
        end
    end
end

local function update_scrollbar_area(self)
    local normalized_scroll = self.scroll() / self.max_scroll
    local bar_width = math.floor(self.scrollbar_width * self.scale)
    local x = self.bounds[1] - self.external_scroll_offset[1]
    local y = self.bounds[2] - self.external_scroll_offset[2]
    if self.direction == "row" then
        local visible_width = self.canvas:getWidth()
        local scrollbar_size = visible_width ^ 2 / (visible_width + self.max_scroll)
        local max_move = visible_width - scrollbar_size
        self.scrollbar_area.x = normalized_scroll * max_move + x
        self.scrollbar_area.y = self.canvas:getHeight() - bar_width + y
        self.scrollbar_area.width = scrollbar_size
        self.scrollbar_area.height = bar_width
        self.own_scroll_offset[1] = self.scroll()
    elseif self.direction == "column" then
        local visible_height = self.canvas:getHeight()
        local scrollbar_size = visible_height ^ 2 / (visible_height + self.max_scroll)
        local max_move = visible_height - scrollbar_size
        self.scrollbar_area.x = self.canvas:getWidth() - bar_width + x
        self.scrollbar_area.y = normalized_scroll * max_move + y
        self.scrollbar_area.width = bar_width
        self.scrollbar_area.height = scrollbar_size
        self.own_scroll_offset[2] = self.scroll()
    end
end

---set scroll offset for this and child elements
---@param scroll_offset any
function flex:set_scroll_offset(scroll_offset)
    scroll_offset = scroll_offset or self.external_scroll_offset
    self.external_scroll_offset = scroll_offset
    local new_scroll_offset = { unpack(scroll_offset) }
    for i = 1, 2 do
        new_scroll_offset[i] = new_scroll_offset[i] + self.own_scroll_offset[i]
    end
    for i = 1, #self.elements do
        self.elements[i]:set_scroll_offset(new_scroll_offset)
    end
    if self.needs_scroll then
        update_scrollbar_area(self)
    end
end

---calculate the positions and size of the elements in the container (returns total width and height)
---@param available_area table
---@return number
---@return number
function flex:calculate_layout(available_area)
    available_area = available_area or self.last_available_area
    for k, v in pairs(available_area) do
        self.last_available_area[k] = v
    end
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
    if self.align_items == "stretch" then
        for i = 1, #self.elements do
            local elem = self.elements[i]
            if self.direction == "row" then
                elem.last_available_area.height = final_height
                if self.elements[i + 1] then
                    elem.last_available_area.width = self.elements[i + 1].last_available_area.x - elem.last_available_area.x
                else
                    elem.last_available_area.width = available_area.x + final_width - elem.last_available_area.x
                end
            elseif self.direction == "column" then
                elem.last_available_area.width = final_width
                if self.elements[i + 1] then
                    elem.last_available_area.height = self.elements[i + 1].last_available_area.y - elem.last_available_area.y
                else
                    elem.last_available_area.height = available_area.y + final_height - elem.last_available_area.y
                end
            end
            elem.flex_expand = true
            elem:calculate_layout()
            elem.flex_expand = nil
        end
    elseif self.align_items == "center" then
        for i = 1, #self.elements do
            local elem = self.elements[i]
            local minmax = get_rect_bounds(elem.bounds)
            if self.direction == "row" then
                local empty_space = elem.last_available_area.y + elem.last_available_area.height - minmax[4]
                elem.last_available_area.y = elem.last_available_area.y + empty_space / 2
            elseif self.direction == "column" then
                local empty_space = elem.last_available_area.x + elem.last_available_area.width - minmax[3]
                elem.last_available_area.x = elem.last_available_area.x + empty_space / 2
            end
            elem:calculate_layout()
        end
    elseif self.align_items == "end" then
        for i = 1, #self.elements do
            local elem = self.elements[i]
            local minmax = get_rect_bounds(elem.bounds)
            if self.direction == "row" then
                local empty_space = elem.last_available_area.y + elem.last_available_area.height - minmax[4]
                elem.last_available_area.y = elem.last_available_area.y + empty_space
            elseif self.direction == "column" then
                local empty_space = elem.last_available_area.x + elem.last_available_area.width - minmax[3]
                elem.last_available_area.x = elem.last_available_area.x + empty_space
            end
            elem:calculate_layout()
        end
    elseif self.align_items ~= "start" then
        error("Invalid value for align_items option '" .. self.align_items .. "' possible values are: 'start', 'center', 'end' and 'stretch'")
    end
    self.needs_scroll = false
    if self.scrollable then
        if self.direction == "row" then
            if final_width > available_area.width then
                self.max_scroll = final_width - available_area.width
                final_width = available_area.width
                self.needs_scroll = true
            end
        elseif self.direction == "column" then
            if final_height > available_area.height then
                self.max_scroll = final_height - available_area.height
                final_height = available_area.height
                self.needs_scroll = true
            end
        end
        if not self.is_animating and (not self.canvas or self.canvas:getWidth() ~= final_width or self.canvas:getHeight() ~= final_height) then
            local width, height = final_width, final_height
            width = math.max(width, 1)
            height = math.max(height, 1)
            self.canvas = love.graphics.newCanvas(width, height, {
                -- TODO: make configurable
                msaa = 4,
            })
        end
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
    if not self.is_animating then
        if not self.needs_scroll then
            self.scroll_target = 0
            self.scroll:set_value(0)
            self.scroll:fast_forward()
            self.own_scroll_offset = { 0, 0 }
        end
        self:set_scroll_offset()
        if self.needs_scroll then
            self.scrollbar_visibility_timer = -2
        end
    end
    return final_width, final_height
end

---draw all the elements in the container
function flex:draw()
    if self.needs_scroll then
        if self.scroll() ~= self.last_scroll_value then
            update_scrollbar_area(self)
            self:set_scroll_offset()
            self.last_scroll_value = self.scroll()
        end
        love.graphics.push()
        local before_canvas = love.graphics.getCanvas()
        love.graphics.setCanvas(self.canvas)
        love.graphics.origin()
        love.graphics.translate(-self.bounds[1], -self.bounds[2])
        love.graphics.clear(0, 0, 0, 0)
        if self.direction == "row" then
            love.graphics.translate(-math.floor(self.scroll()), 0)
        elseif self.direction == "column" then
            love.graphics.translate(0, -math.floor(self.scroll()))
        end
        for i = 1, #self.elements do
            self.elements[i]:draw()
        end
        love.graphics.setCanvas(before_canvas)
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.canvas, self.bounds[1], self.bounds[2])
        love.graphics.push()
        love.graphics.origin()
        if self.scrollbar_vanish then
            self.scrollbar_color[4] = math.max(1.5 - love.timer.getTime() + self.scrollbar_visibility_timer, 0)
            if self.scrollbar_color[4] > 1 then
                self.scrollbar_color[4] = 1
            end
        end
        love.graphics.setColor(self.scrollbar_color)
        love.graphics.rectangle(
            "fill",
            self.scrollbar_area.x,
            self.scrollbar_area.y,
            self.scrollbar_area.width,
            self.scrollbar_area.height
        )
        love.graphics.pop()
    else
        for i = 1, #self.elements do
            self.elements[i]:draw()
        end
    end
end

return flex
