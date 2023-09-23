local keyboard_navigation = require("ui.keyboard_navigation")
local overlay_module = {}
local overlays = {}
local free_overlay_indices = {}

---add an element to be rendered as overlay
---@param element any
---@return integer
function overlay_module.add_overlay(element)
    local index
    if #free_overlay_indices == 0 then
        index = #overlays + 1
    else
        index = free_overlay_indices[1]
        table.remove(free_overlay_indices, 1)
    end
    overlays[index] = element
    -- require here to avoid circular import (now require just returns the cached table)
    local ui = require("ui")
    element:set_scale(ui.get_screen().scale)
    return index
end

---remove an overlay
---@param index integer
function overlay_module.remove_overlay(index)
    if index ~= #overlays then
        free_overlay_indices[#free_overlay_indices + 1] = index
    end
    overlays[index] = nil
end

---process an event
---@param transform love.Transform
---@param name string
---@param ... unknown
---@return boolean
function overlay_module.process_event(transform, name, ...)
    for i = 1, #overlays do
        if overlays[i] then
            if name == "resize" then
                -- require here to avoid circular import (now require just returns the cached table)
                local ui = require("ui")
                overlays[i]:set_scale(ui.get_screen().scale)
            end
            if overlays[i]:process_event(transform, name, ...) then
                return true
            end
            if not overlays[i] then
                return true
            end
            if keyboard_navigation.get_screen() == overlays[i] then
                keyboard_navigation.process_event(name, ...)
            end
            if overlays[i].is_mouse_over then
                return true
            end
        end
    end
    return false
end

---update overlays
---@param dt number
function overlay_module.update(dt)
    for i = 1, #overlays do
        if overlays[i] and overlays[i].update then
            overlays[i]:update(dt)
        end
    end
end

---draw all overlays
function overlay_module.draw()
    for i = 1, #overlays do
        if overlays[i] then
            overlays[i]:draw()
        end
    end
end

return overlay_module
