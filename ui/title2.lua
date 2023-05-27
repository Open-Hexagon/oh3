local signal = require("anim.signal")
local layout = require("ui.layout")
local transform = require("transform")
local extmath = require("extmath")
local ease = require("anim.ease")

-- States
local STOP, TITLE, MENU = 1, 2, 3
local state = TITLE

-- Side count
local sides = 6
local ARC = extmath.tau / 6

-- Colors
local main_color = { 1, 0.23, 0.13, 1 }
local panel_colors = {
    { 0.1, 0.02, 0.04, 1 },
    { 0.13, 0.02, 0.1, 1 },
}

local bicolor_shader = love.graphics.newShader("assets/image/title/bicolor.frag")







local animate = {}

function animate.title_to_menu()
    title:exit()

    local time = 0.3

    screens.background.x:keyframe(time, 0.35, ease.out_back)
    screens.background.pivot_radius:keyframe(time, 0.2, ease.out_back)
    screens.background.angle:stop()
    local angle = screens.background.angle()
    local target = angle + math.pi
    target = target - target % (extmath.tau / 3) + math.pi / 6
    screens.background.angle:keyframe(time, target, ease.out_back)

    wheel.enable_drawing()
    wheel.enable_selection()
    local rotate = target - angle
    wheel.angle:set_value(-rotate)
    wheel.angle:keyframe(time, 0, ease.out_back)
end

function animate.menu_to_title()
    title:enter()

    screens.background.x:keyframe(0.3, 0.5, ease.out_back)
    screens.background.pivot_radius:keyframe(0.3, 0.1, ease.out_back)
    local angle = screens.background.angle()
    screens.background.angle:keyframe(0.3, angle + math.pi / 2, ease.out_sine)
    screens.background:loop()

    wheel.disable_selection()
    wheel.angle:keyframe(0.3, math.pi / 2, ease.out_sine)
    wheel.angle:set_value(0)
    wheel.angle:call(wheel.disable_drawing)
end

local M = {}
function M.load()
    title:load()
    screens.background:load()
    --wheel:load()
end

function M.draw()
    screens.background:draw()
    --wheel:draw()
    title:draw()
end

function M.handle_event(name, a, b, c, d, e, f)
    if state == STOP then
        return
    end
    if name == "keypressed" and a == "tab" then
    elseif name == "mousemoved" then
        --wheel:check_cursor(a, b)
        -- selection = nil
        -- for _, btn in pairs(buttonlist) do
        --     if btn:check_cursor(a, b) then
        --         selection = btn
        --     end
        -- end
    elseif name == "mousereleased" then
        if state == TITLE then
            animate.title_to_menu()
        else
            animate.menu_to_title()
        end
        --wheel:check_cursor(a, b)
    end
end

return M
