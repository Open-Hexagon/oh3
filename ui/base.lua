local stack = require "ui.stack"
local settings = require "ui.overlay.settings"
local textbox = require "ui.element.textbox"
local layout = require "ui.layout"
local signal = require "anim.signal"

local lefttab = signal.new_sum(layout.LEFT, signal.new_waveform(1 / 4, function(t)
    return 100 + 50 * math.sin(2 * math.pi * t)
end))
local leftbar = signal.new_sum(lefttab, 100)
local rightbar = signal.new_sum(layout.RIGHT, -50)


local centerx = signal.new_lerp(leftbar, rightbar, 0.5)
local centery = signal.new_lerp(layout.TOP, layout.BOTTOM, 0.5)

local centerboxleft = signal.new_sum(centerx, -50)
local centerboxright = signal.new_sum(centerx, 50)
local centerboxtop = signal.new_sum(centery, -50)
local centerboxbottom = signal.new_sum(centery, 50)

local tabs = textbox.new(
    "",
    { layout.LEFT, lefttab, layout.TOP, layout.BOTTOM }
)

local bar = textbox.new(
    "",
    { lefttab, leftbar, layout.TOP, layout.BOTTOM }
)

local center = textbox.new(
    "",
    { centerboxleft, centerboxright, centerboxtop, centerboxbottom }
)

local rbar = textbox.new(
    "",
    { rightbar, layout.RIGHT, layout.TOP, layout.BOTTOM }
)


-- TODO: something to keep track of what base screen we're on
local screen = "main_menu"

local base = {}

function base.update(dt)

end

function base.resize()
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
