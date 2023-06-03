local extmath = require("extmath")
local ease = require("anim.ease")
local list = require("ui.list")
local signal = require("anim.signal")

local screen = require("ui.screen")

local timeline = signal.new_queue()

local animate = {
    running = false,
}

local function clear()
    animate.running = false
end

function animate.set_for(seconds)
    animate.running = true
    timeline:wait(seconds)
    timeline:call(clear)
end

function animate.title_to_menu()
    -- Title leaves screen and gets removed
    screen.title.position:fast_forward()
    screen.title.pass = true
    screen.title.position:keyframe(0.25, -0.1, ease.out_back)
    screen.title.position:call(function()
        list.remove(screen.title)
    end)

    -- Move the background left
    screen.background.x:fast_forward()
    screen.background.x:keyframe(0.25, 0.375, ease.out_back)

    -- Make the center polygon bigger
    screen.background.pivot_radius:fast_forward()
    screen.background.pivot_radius:keyframe(0.25, 0.175, ease.out_back)

    -- Set radian_speed to 0 to surrender control to direct angle control
    screen.background.radian_speed:fast_forward()
    screen.background.radian_speed:set_immediate_value(0)

    -- Move menu text
    screen.wheel.text_radius:fast_forward()
    screen.wheel.text_radius:keyframe(0.25, 1, ease.out_quint)

    -- This could possibly be simplified
    local angle = screen.background.angle()
    local target = angle + math.pi
    target = target - target % (extmath.tau / 3) + math.pi / 6
    screen.background.angle:keyframe(0.25, target, ease.out_back)
    -- Insert menu buttons under title
    list.emplace_top(screen.wheel, 1)
    screen.wheel.angle = extmath.tau - target

end

function animate.menu_to_title()
    -- Insert the title screen on top
    screen.title.position:fast_forward()
    screen.title.pass = false
    list.emplace_top(screen.title)
    screen.title.position:keyframe(0.25, 0.25, ease.out_back)

    -- Move the background back to the center
    screen.background.x:fast_forward()
    screen.background.x:keyframe(0.25, 0.5, ease.out_sine)

    -- Revert the pivot_radius
    screen.background.pivot_radius:fast_forward()
    screen.background.pivot_radius:keyframe(0.25, 0.1, ease.out_sine)

    -- Process all direct angle events to surrender control to radian_speed
    screen.background.angle:fast_forward()

    -- Increase radian_speed
    screen.background.radian_speed:set_immediate_value(4 * extmath.tau)
    screen.background.radian_speed:keyframe(0.25, math.pi / 2)

    -- Remove menu text
    screen.wheel.text_radius:fast_forward()
    screen.wheel.text_radius:keyframe(0.25, 0, ease.out_quint)
    screen.wheel.text_radius:call(function()
        list.remove(screen.wheel)
    end)
end

function animate.open_settings() end

function animate.close_settings() end

return animate
