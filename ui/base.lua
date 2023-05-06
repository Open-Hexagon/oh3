local stack = require "ui.stack"
local settings = require "ui.overlay.settings"
local textbox = require "ui.element.textbox"
local layout = require "ui.layout"
local signal = require "anim.signal"
local ease = require "anim.ease"

local queue = signal.new_queue()
queue:call(function() print("Start at 200") end)
queue:set_value(200)
queue:call(function() print("In 0.5s, target 400, ease out_quad") end)
queue:keyframe(0.5, 400, ease.out_quad)
queue:call(function() print("In 2s, target 300, ease out_bounce") end)
queue:keyframe(2, 300, ease.out_bounce)
queue:call(function() print("In 1.5s, target 600, ease out_elastic") end)
queue:keyframe(1.5, 600, ease.out_elastic)
queue:call(function() print("Done") end)

local lefttab = signal.new_sum(layout.LEFT, queue)
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
