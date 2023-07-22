local point_in_polygon = require("ui.extmath").point_in_polygon
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
---@param name any
---@param ... unknown
---@return boolean
function overlay_module.process_event(name, ...)
    for i = 1, #overlays do
        if overlays[i] then
            overlays[i]:process_event(name, ...)
            if not overlays[i] then
                return true
            end
            if point_in_polygon(overlays[i].bounds, love.mouse.getPosition()) then
                return true
            end
        end
    end
    return false
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
