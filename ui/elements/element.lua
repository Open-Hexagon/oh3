local keyboard_navigation = require("ui.keyboard_navigation")
local point_in_polygon = require("ui.extmath").point_in_polygon
local element = {}
element.__index = element

function element:new(options)
    options = options or {}
    self.style = options.style or {}
    self.scale = 1
    self.padding = 8
    self.color = { 1, 1, 1, 1 }
    self.selectable = options.selectable or false
    self.is_mouse_over = false
    self.selected = false
    self.selection_handler = options.selection_handler
    self.click_handler = options.click_handler
    self.scroll_offset = { 0, 0 }
    self.bounds = {}
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

function element:set_scroll_offset(scroll_offset)
    self.scroll_offset = scroll_offset
end

function element:calculate_layout(available_area)
    if self.calculate_element_layout then
        local x, y = available_area.x, available_area.y
        local width, height = self:calculate_element_layout(available_area)
        self.bounds = { x, y, x + width, y, x + width, y + height, x, y + height }
        return width, height
    end
end

function element:process_event(name, ...)
    if name == "mousemoved" or name == "mousepressed" then
        local x, y = ...
        if self.scroll_offset then
            x = x + self.scroll_offset[1]
            y = y + self.scroll_offset[2]
        end
        self.is_mouse_over = point_in_polygon(self.bounds, x, y)
        if name == "mousepressed" and self.selectable then
            if self.selected ~= self.is_mouse_over then
                self.selected = self.is_mouse_over
                if self.selected then
                    keyboard_navigation.select_element(self)
                else
                    keyboard_navigation.deselect_element(self)
                end
                if self.selection_handler then
                    self.selection_handler(self)
                end
            end
            if self.click_handler and self.is_mouse_over then
                self.click_handler()
            end
        end
    end
    if name == "keypressed" then
        local key = ...
        if key == "return" or key == "space" then
            if self.selected then
                if self.click_handler then
                    self.click_handler()
                end
            end
        end
    end
end

return element
