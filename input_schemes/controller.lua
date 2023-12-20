local controller = {
    defaults = {
        focus = { "x" },
        right = { "rightshoulder", "dpright" },
        left = { "leftshoulder", "dpleft" },
        swap = { "a" },
        ui_up = { "dpup" },
        ui_down = { "dpdown" },
        ui_left = { "dpleft" },
        ui_right = { "dpright" },
        ui_click = { "a" },
    },
}

function controller.is_down(button)
    is_pressed = false

    for i, joystick in pairs(love.joystick.getJoysticks()) do
        if joystick:isGamepadDown(button) then
            is_pressed = true
        end
    end

    return is_pressed
end


return controller
