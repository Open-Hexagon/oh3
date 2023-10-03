local keyboard_navigation = require("ui.keyboard_navigation")
local overlay_module = {}
local overlays = {}
local free_overlay_indices = {}
local gui_scale = 1

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
    element:set_scale(gui_scale)
    element:mutated()
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

---set the gui scale
---@param scale number
function overlay_module.set_scale(scale)
    gui_scale = scale
    for i = 1, #overlays do
        if overlays[i] then
            overlays[i]:set_scale(scale)
            overlays[i]:mutated()
        end
    end
end

---process an event
---@param name string
---@param ... unknown
---@return boolean
function overlay_module.process_event(name, ...)
    for i = 1, #overlays do
        if overlays[i] then
            if overlays[i]:process_event(name, ...) then
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
