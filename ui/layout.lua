local extmath = require "extmath"

-- weak table containing all existing aligners
local aligners = setmetatable({}, {__mode = "k"})

local Aligner = {}
Aligner.__index = Aligner

function Aligner:reset()
    self.value = nil
end

function Aligner:get()
    if not self.value then
        self.value = self.align:get() + self.offset
    end
    return self.value
end

local ProportionalAligner = {}
ProportionalAligner.__index = ProportionalAligner

function ProportionalAligner:reset()
    self.value = nil
end

function ProportionalAligner:get()
    if not self.value then
        self.value = extmath.lerp(self.align1:get(), self.align2:get(), self.t)
    end
    return self.value
end

local Grid = {}
Grid.__index = Grid

function Grid:resize()
    
end

local layout = {}

do
    local function zero(_)
        return 0
    end
    layout.LEFT = { get = zero }
    layout.TOP = { get = zero }
    layout.RIGHT = {
        get = function(_)
            return layout.width
        end
    }
    layout.BOTTOM = {
        get = function(_)
            return layout.height
        end
    }
end

function layout.new_aligner(align, offset)
    local newinst = setmetatable({
        align = align,
        offset = offset
    }, Aligner)
    aligners[newinst] = true;
    return newinst
end

function layout.new_proportional_aligner(align1, align2, t)
    local newinst = setmetatable({
        align1 = align1,
        align2 = align2,
        t = t
    }, ProportionalAligner)
    aligners[newinst] = true;
    return newinst
end

function layout.new_grid(x, y)
    local newinst = setmetatable({

    }, Grid)
    return newinst
end

function layout.resize()
    layout.width, layout.height = love.graphics.getDimensions()
    layout.center_x, layout.center_y = layout.width * 0.5, layout.height * 0.5
    for align, _ in pairs(aligners) do
       align:reset()
    end
end

return layout
