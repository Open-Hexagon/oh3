-- TODO: UI stuff
-- This module oversees the rest of the ui systems

local stack = require "ui.stack"
local base = require "ui.base"
local background = require "ui.background"
local layout = require "ui.layout"

local ui = {}

function ui.load()
    stack.push(background)
    stack.push(base)
end

function ui.draw()
    stack.draw()
end

function ui.handle_event(name, a, b, c, d, e, f)
    stack.handle_event(name, a, b, c, d, e, f)
end

-- Reevaluates all element sizes and positions
-- Should be called after a window resize
function ui.resize()
    layout.resize()
end

return ui