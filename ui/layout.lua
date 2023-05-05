local signal = require "anim.signal"

local Grid = {}
Grid.__index = Grid

function Grid:resize()
    
end

local layout = {}

do
    local zero = signal.new_signal(0)
    layout.LEFT = zero
    layout.TOP = zero
    layout.RIGHT = function()
        return layout.width
    end
    layout.BOTTOM = function()
        return layout.height
    end
    layout.CENTER_X = function ()
        return layout.center_x
    end
    layout.CENTER_Y = function ()
        return layout.center_x
    end
end

function layout.new_grid(x, y)
    local newinst = setmetatable({

    }, Grid)
    return newinst
end

function layout.resize()
    layout.width, layout.height = love.graphics.getDimensions()
    layout.center_x, layout.center_y = layout.width * 0.5, layout.height * 0.5
end

return layout
