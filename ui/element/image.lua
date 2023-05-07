local signal = require"anim.signal"

local Image = {}
Image.__index = Image

function Image:draw(x, y)

end

local image = {}

function image.new_image(x0, y0)
    local newinst = setmetatable({
        x0 = signal.new_signal(x0 or 0.5),
        y0 = signal.new_signal(y0 or 0.5)
    })

    return newinst
end

return image