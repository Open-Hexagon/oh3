local keyboard_navigation = require("ui.keyboard_navigation")
local point_in_polygon = require("ui.extmath").point_in_polygon
local element = {}
element.__index = element

function element:new(options)
    options = options or {}
    self.style = options.style or {}
    self.scale = 1
    self.padding = 8
	self.margins = { 0, 0 }
    self.color = { 1, 1, 1, 1 }
    self.selectable = options.selectable or false
    self.is_mouse_over = false
    self.selected = false
    self.selection_handler = options.selection_handler
    self.click_handler = options.click_handler
    self.scroll_offset = { 0, 0 }
    self.bounds = {}
    self.last_available_area = { x = 0, y = 0, width = 0, height = 0 }
    if options.style then
        self:set_style(options.style)
    end
    return self
end

function element:set_style(style)
    self.padding = self.style.padding or style.padding or self.padding
    self.margins = self.style.margins or style.margins or self.margins
    self.color = self.style.color or style.color or self.color
end

function element:set_scale(scale)
    self.scale = scale
end

function element:set_scroll_offset(scroll_offset)
    self.scroll_offset = scroll_offset
end

function element:_update_last_available_area(available_area)
    for k, v in pairs(available_area) do
        self.last_available_area[k] = v
    end
end

function element:calculate_layout(available_area)
    available_area = available_area or self.last_available_area
    if self.calculate_element_layout then
        local x, y = available_area.x, available_area.y
        local width, height = self:calculate_element_layout(available_area)
        self.bounds = { x, y, x + width, y, x + width, y + height, x, y + height }
        self:_update_last_available_area(available_area)
        return width, height
    end
end

function element:get_root()
    local function get_parent(elem)
        if elem.parent then
            return get_parent(elem.parent)
        end
        return elem
    end
    return get_parent(self)
end

function element:check_screen()
    return self:get_root() == keyboard_navigation.get_screen()
end

function element:click(select)
    if select == nil then
        select = true
    end
    if not self.selected and select then
        keyboard_navigation.select_element(self, true, self.click_handler)
    end
    if self.click_handler then
        self.click_handler(self)
    end
end

function element:process_event(name, ...)
    if name == "mousemoved" or name == "mousepressed" or name == "mousereleased" then
        local x, y = ...
        if self.scroll_offset then
            x = x + self.scroll_offset[1]
            y = y + self.scroll_offset[2]
        end
        self.is_mouse_over = point_in_polygon(self.bounds, x, y)
        if name == "mousereleased" and self.selectable then
            if self.selected ~= self.is_mouse_over then
                self.selected = self.is_mouse_over
                if self.selected then
                    keyboard_navigation.select_element(self, true, false)
                else
                    keyboard_navigation.deselect_element(self, true, true)
                end
            end
            if self.click_handler and self.is_mouse_over then
                if self.click_handler(self) == true then
                    return true
                end
            end
        end
    end
    if name == "keypressed" then
        local key = ...
        if key == "return" or key == "space" then
            if self.selected then
                if self.click_handler then
                    if self.click_handler(self) == true then
                        return true
                    end
                end
            end
        end
    end
end

return element
