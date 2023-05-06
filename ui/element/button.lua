---@class Selectable
---@field left Signal
---@field right Signal
---@field top Signal
---@field bottom Signal
---@field selected boolean
---@field select function
---@field deselect function

---Aligned rectangular button
---@class Rectangle
---@field element Selectable
local Rectangle = {}
Rectangle.__index = Rectangle

---Check whether the cursor overlaps. Returns true if so.
---Also toggles element selection
---@param x number cursor x coordinate
---@param y number cursor y corrdinate
---@return boolean
function Rectangle:check_cursor(x, y)
    local left, top = self.element.left(), self.element.top()
    local right, bottom = self.element.right(), self.element.bottom()
    if left <= x and x < right and top <= y and y < bottom then
        if not self.element.selected then
            self.element:select()
        end
        return true
    else
        if self.element.selected then
            self.element:deselect()
        end
    end
    return false
end

---Circular button
---@class Circle
local Circle = {}
Circle.__index = Circle

function Circle.check_cursor(x, y) end

---Button matrix
local Matrix = {}

local button = {}

function button.new_rectangle(element, event)
    local newinst = setmetatable({
        element = element,
        event = event,
    }, Rectangle)

    return newinst
end

function button.new_matrix() end

return button
