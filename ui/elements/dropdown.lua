local keyboard_navigation = require("ui.keyboard_navigation")
local overlays = require("ui.overlays")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local dropdown = {}

local function table_plus(t1, t2)
    local new = {}
    for k, v in pairs(t1) do
        new[k] = v
    end
    for k, v in pairs(t2) do
        new[k] = v
    end
    return new
end

function dropdown:new(selections, options)
    options = options or {}
    local selected_label = label:new(selections[1], table_plus(options, { selectable = false }))
    for i = 1, #selections do
        selections[i] = label:new(selections[i], table_plus(options, { selectable = true }))
    end
    local obj = quad:new(table_plus(options, {
        selectable = true,
        child_element = selected_label,
        selection_handler = function(elem)
            -- TODO: replace temporary hardcoded selection color
            if elem.selected then
                elem.border_color = { 0, 0, 1, 1 }
            else
                elem.border_color = { 1, 1, 1, 1 }
                elem.toggle(false)
            end
        end,
        click_handler = function(elem)
            elem.toggle()
        end,
    }))
    obj.is_opened = false
    obj.selections = selections
    obj.selection_quad = quad:new({
        child_element = flex:new(selections, { direction = "column", scrollable = true }),
    })
    local function update_dropdown_layout()
        local padding = obj.element.padding
        local area = {
            x = obj.vertices[7] + math.abs(obj.vertex_offsets[7]) - padding - obj.scroll_offset[1],
            y = obj.vertices[8] - math.abs(obj.vertex_offsets[8]) - padding - obj.scroll_offset[2],
        }
        local other_corner_x = obj.vertices[3] - math.abs(obj.vertex_offsets[3]) + padding
        area.width = other_corner_x - area.x
        area.height = love.graphics.getHeight() - area.y
        obj.selection_quad:calculate_layout(area)
    end
    local quad_scale = obj.set_scale
    obj.set_scale = function(elem, scale)
        quad_scale(elem, scale)
        elem.selection_quad:set_scale(scale)
    end
    local quad_layout = obj.calculate_layout
    obj.calculate_layout = function(elem, available_area)
        local w, h = quad_layout(elem, available_area)
        update_dropdown_layout()
        return w, h
    end
    obj.set_scroll_offset = function(elem, scroll_offset)
        elem.scroll_offset = scroll_offset
        update_dropdown_layout()
    end
    obj.toggle = function(bool)
        local previous_state = obj.is_opened
        if bool == nil then
            obj.is_opened = not obj.is_opened
        else
            obj.is_opened = bool
        end
        if obj.is_opened ~= previous_state then
            if obj.is_opened then
                update_dropdown_layout()
                obj.overlay_index = overlays.add_overlay(obj.selection_quad)
                obj.last_screen = keyboard_navigation.get_screen()
                keyboard_navigation.set_screen(obj.selection_quad)
                local elements = obj.selection_quad.element.elements
                for i = 1, #elements do
                    if elements[i].raw_text == obj.element.raw_text then
                        keyboard_navigation.select_element(elements[i])
                        break
                    end
                end
            else
                local elements = obj.selection_quad.element.elements
                for i = 1, #elements do
                    if elements[i].selected then
                        obj.element.raw_text = elements[i].raw_text
                        obj:calculate_layout()
                        break
                    end
                end
                overlays.remove_overlay(obj.overlay_index)
                keyboard_navigation.set_screen(obj.last_screen)
                keyboard_navigation.select_element(obj)
                obj.last_screen = nil
                obj.elements = nil
                obj.overlay_index = nil
            end
        end
    end
    return obj
end

return dropdown
