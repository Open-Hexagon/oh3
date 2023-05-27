-- TODO: UI stuff
-- This module oversees the rest of the ui systems

local list = require("ui.list")
local layout = require("ui.layout")
local animate = require("ui.animate")

local screen = require("ui.screen")

local ui = {}

function ui.load()
    list.emplace_top(screen.background)
    list.emplace_top(screen.title)
end

function ui.draw()
    list.draw()
end

function ui.update(dt)
    list.update(dt)
end

function ui.handle_event(name, a, b, c, d, e, f)
    -- Returns something if a state change is requested
    local change = list.handle_event(name, a, b, c, d, e, f)
    if change then
        animate[change]()
    end
end

-- Reevaluates all element sizes and positions
-- Should be called after a window resize
function ui.resize()
    layout.resize()
end

return ui
