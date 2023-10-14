local input = require("input")
local config = require("config")
local key_repeat = {}
local keys = { "ui_up", "ui_down", "ui_left", "ui_right", "ui_click" }
local states = {}
local press_timers = {}
local press_timer_repeat = {}

function key_repeat.update(dt)
    for i = 1, #keys do
        local state = input.get(config.get("input_" .. keys[i]))
        if state then
            press_timers[i] = (press_timers[i] or 0) + dt
            if press_timers[i] > (press_timer_repeat[i] or 0.4) then
                press_timers[i] = 0
                press_timer_repeat[i] = math.max(press_timer_repeat[i] - 0.05, 0.1)
                require("ui").process_event("customkeyrepeat", keys[i])
            end
        else
            press_timers[i] = 0
            press_timer_repeat[i] = 0.4
        end
        if state ~= states[i] then
            if state then
                require("ui").process_event("customkeydown", keys[i])
            else
                require("ui").process_event("customkeyup", keys[i])
            end
        end
        states[i] = state
    end
end

return key_repeat
