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

    ---A signal that outputs the larger screen dimension.
    layout.MAJOR = function()
        return layout.major
    end

    ---A signal that outputs the smaller screen dimension.
    layout.MINOR = function()
        return layout.minor
    end

    ---A signal that outputs the X coordinate of the CENTER of the screen.
    layout.CENTER_X = function()
        return layout.center_x
    end

    ---A signal that outputs the Y coordinate of the CENTER edge of the screen.
    layout.CENTER_Y = function()
        return layout.center_y
    end
end

function layout.resize()
    layout.width, layout.height = love.graphics.getDimensions()
    layout.center_x, layout.center_y = layout.width * 0.5, layout.height * 0.5
    if layout.width < layout.height then
        layout.minor, layout.major = layout.width, layout.height
    else
        layout.minor, layout.major = layout.height, layout.width
    end
end

return layout
