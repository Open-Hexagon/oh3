local signal = require "anim.signal"

local layout = {}

do
    local zero = signal.new_signal(0)
    ---A signal that outputs the X coordinate of the LEFT edge of the screen (always 0).
    layout.LEFT = zero

    ---A signal that outputs the Y coordinate of the TOP edge of the screen (always 0).
    layout.TOP = zero

    ---A signal that outputs the X coordinate of the RIGHT edge of the screen.
    layout.RIGHT = function()
        return layout.width
    end

    ---A signal that outputs the Y coordinate of the BOTTOM edge of the screen.
    layout.BOTTOM = function()
        return layout.height
    end

    ---A signal that outputs the X coordinate of the CENTER of the screen.
    layout.CENTER_X = function()
        return layout.center_x
    end

    ---A signal that outputs the Y coordinate of the CENTER edge of the screen.
    layout.CENTER_Y = function()
        return layout.center_x
    end
end

function layout.resize()
    layout.width, layout.height = love.graphics.getDimensions()
    layout.center_x, layout.center_y = layout.width * 0.5, layout.height * 0.5
end

return layout
