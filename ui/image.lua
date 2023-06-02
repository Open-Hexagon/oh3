-- Image utilities

local image = {}

---@param width number
---@param height number
---@return love.Transform
function image.get_centering_transform(width, height)
    local t = love.math.newTransform()
    t:translate(width / -2, height / -2)
    return t
end

return image