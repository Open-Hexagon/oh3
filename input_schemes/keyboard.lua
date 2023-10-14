local keyboard = {
    defaults = {
        focus = { "lshift", "rshift" },
        right = { "right", "d" },
        left = { "left", "a" },
        swap = { "space" },
        ui_up = { "up", "w" },
        ui_down = { "down", "s" },
        ui_left = { "left", "a" },
        ui_right = { "right", "d" },
        ui_click = { "return", "space" },
    },
}

function keyboard.is_down(key)
    return love.keyboard.isDown(key)
end

return keyboard
