
local TextBox = {}
TextBox.__index = TextBox

function TextBox:draw()
    local x, y = self.left:get(), self.top:get()
    local width, height = self.right:get() - x, self.bottom:get() - y

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, width, height)
end

local M = {}

function M.new(text, left, right, top, bottom)
    local newinst = setmetatable({
        text = text,
        left = left,
        right = right,
        top = top,
        bottom = bottom
    }, TextBox)
    return newinst
end

return M