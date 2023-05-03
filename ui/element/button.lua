-- TODO: Button class, and other elements 
local button = {}
button.__index = button

function button:new(label, top, bottom, left, right)
    local newinst = setmetatable({
        label = label,
        top = top,
        bottom = bottom,
        left = left,
        right = right
    }, self)
end

function button:draw(x, y, width, height)
    --love.graphics.rectangle("fill")
end

return button