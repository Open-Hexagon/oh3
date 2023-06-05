local resize_list = require("ui.element").resize_list
local theme = require("ui.theme")
local signal = require("anim.signal")

local M = {}
M.MARGIN_WIDTH = 12
M.FONT = theme.open_square_font[20]

---@class TextBox:Element
---@field text string
---@field text_alignment "left"|"right"|"center"
---@field text_color number[]
---@field background_color number[]
---@field border_color number[]
---@field font love.Font
---@field margin_width number
local TextBox = {}
TextBox.__index = TextBox

function TextBox:draw()
    local x, y = self.x(), self.y()
    local width, height = self.width(), self.height()

    love.graphics.setColor(self.border_color)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height)

    love.graphics.setColor(self.background_color)
    love.graphics.rectangle("fill", x, y, width, height)

    love.graphics.setCanvas(self.text_canvas)
    love.graphics.clear()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(self.text_color)
    love.graphics.printf(
        self.text,
        M.FONT,
        M.MARGIN_WIDTH,
        M.MARGIN_WIDTH,
        width - 2 * M.MARGIN_WIDTH,
        self.text_alignment
    )
    love.graphics.pop()
    love.graphics.setCanvas()
    love.graphics.draw(self.text_canvas, x, y)
end

function TextBox:resize()
    local width, height = self.width(), self.height()
    print(width, height)
    self.text_canvas = love.graphics.newCanvas(width, height - M.MARGIN_WIDTH)
end

---Creates a new text-box
---@param text string Text
---@param x signalparam
---@param y signalparam
---@param width signalparam
---@param height signalparam
---@param text_alignment? "left"|"right"|"center"
---@param background_color? number[]
---@param text_color? number[]
---@param border_color? number[]
---@return table
function M.new(text, x, y, width, height, text_alignment, text_color, background_color, border_color)
    ---@type TextBox
    local newinst = setmetatable({
        text = text,
        x = signal.new_signal(x),
        y = signal.new_signal(y),
        width = signal.new_signal(width),
        height = signal.new_signal(height),
        text_alignment = text_alignment or "left",
        text_color = text_color or theme.text_color,
        background_color = background_color or theme.element_background_color,
        border_color = border_color or theme.border_color,
    }, TextBox)
    table.insert(resize_list, newinst)
    return newinst
end

return M
