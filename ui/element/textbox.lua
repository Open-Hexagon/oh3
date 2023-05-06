local theme = require "ui.theme"
local signal = require "anim.signal"
local edge   = require "ui.element.edge"

-- TODO: Still unfinished. Needs refinement

local TextBox = {}
TextBox.__index = TextBox

function TextBox:draw()
    local x, y = self.left(), self.top()
    local width, height = self.right() - x, self.bottom() - y

    love.graphics.setColor(theme.background_color)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(theme.border_color)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, width, height)
end

local M = {}

---Creates a new textbox
---@param text string Text
---@param position signalparam[] Signals for the left, right, top, and bottom edges respectively
---@param align? "left"|"right"|"center" Text alignment
---@param borders? boolean[] Boolean toggles for the left, right, top, and bottom edges respectively
---@param border_width? number Border width
---@param margin_width? number Text margin width
---@return table
function M.new(text, position, borders, align, border_width, margin_width)
    local newinst = setmetatable({
        text = text,
        left = signal.new_signal(position[edge.LEFT]),
        right = signal.new_signal(position[edge.RIGHT]),
        top = signal.new_signal(position[edge.TOP]),
        bottom = signal.new_signal(position[edge.BOTTOM]),
        borders = borders,
        align = align,
        border_width = border_width or 2,
        margin_width = margin_width or 5
    }, TextBox)
    return newinst
end

return M
