local theme = require("ui.theme")

---@class Selectable
---@field select function The function that handles any selection tasks
---@field deselect function The function that handles any deselection tasks
---@field selected boolean True if this object is selected
---@field up Selectable? The selectable object to switch to when left is pressed
---@field down Selectable? The selectable object to switch to when down is pressed
---@field left Selectable? The selectable object to switch to when left is pressed
---@field right Selectable? The selectable object to switch to when right is pressed

local M = {}
M.HIGHLIGHT_COLOR = theme.background_main_color
M.HIGHLIGHT_WIDTH = 4

---Aligned rectangular button
---@class RectangularButton:Selectable
---@field element Element
---@field event function?
local RectangularButton = {}
RectangularButton.__index = RectangularButton

---Check whether the cursor overlaps. Returns true if so.
---Also toggles element selection
---@param x number cursor x coordinate
---@param y number cursor y corrdinate
---@return boolean
function RectangularButton:check_cursor(x, y)
    local left, top = self.element.x(), self.element.y()
    local right, bottom = left + self.element.width(), top + self.element.height()
    return left < x and x < right and top < y and y < bottom
end

function RectangularButton:select()
    self.selected = true
end

function RectangularButton:deselect()
    self.selected = false
end

function RectangularButton:draw()
    self.element:draw()
    if self.selected then
        love.graphics.setColor(M.HIGHLIGHT_COLOR)
        local offset = M.HIGHLIGHT_WIDTH * 0.5 + 1
        local x, y = self.element.x() - offset, self.element.y() - offset
        local width, height = self.element.width() + 2 * offset, self.element.height() + 2 * offset
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", x, y, width, height)
    end
end

---Creates a new rectangular button.
---@param element Element
---@param event function?
---@return RectangularButton
function M.new_rectangular_button(element, event)
    local newinst = setmetatable({
        element = element,
        selected = false,
        event = event,
    }, RectangularButton)
    return newinst
end

return M
