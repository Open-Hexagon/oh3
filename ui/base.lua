local stack = require "ui.stack"
local settings = require "ui.overlay.settings"
local textbox = require "ui.element.textbox"
local layout = require "ui.layout"


local lefttab = layout.new_aligner(layout.LEFT, 50)
local leftbar = layout.new_aligner(lefttab, 100)
local rightbar = layout.new_aligner(layout.RIGHT, -50)


local centerx = layout.new_proportional_aligner(leftbar, rightbar, 0.5)
local centery = layout.new_proportional_aligner(layout.TOP, layout.BOTTOM, 0.5)

local centerboxleft = layout.new_aligner(centerx, -50)
local centerboxright = layout.new_aligner(centerx, 50)
local centerboxtop = layout.new_aligner(centery, -50)
local centerboxbottom = layout.new_aligner(centery, 50)

local tabs = textbox.new(
    "",
    layout.LEFT,
    lefttab,
    layout.TOP,
    layout.BOTTOM
)

local bar = textbox.new(
    "",
    lefttab,
    leftbar,
    layout.TOP,
    layout.BOTTOM
)

local center = textbox.new(
    "",
    centerboxleft,
    centerboxright,
    centerboxtop,
    centerboxbottom
)

local rbar = textbox.new(
    "",
    rightbar,
    layout.RIGHT,
    layout.TOP,
    layout.BOTTOM
)


-- TODO: something to keep track of what base screen we're on
local screen = "main_menu"

local base = {}

function base.update(dt)

end

function base.resize()
    lefttab:reset()
    leftbar:reset()
    rightbar:reset()
    centerx:reset()
    centery:reset()
    centerboxleft:reset()
    centerboxright:reset()
    centerboxtop:reset()
    centerboxbottom:reset()
end

function base.draw()
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    tabs:draw()
    bar:draw()
    center:draw()
    rbar:draw()
end

function base.handle_event(name, a, b, c, d, e, f)
    if name == "keypressed" and a == "tab" then
        stack.push(settings)
    elseif name == "mousereleased" then
    end
end

return base
