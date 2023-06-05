local M = {}
M.KEYBOARD = 1
M.MOUSE = 2
M.JOYSTICK = 3
M.TOUCH = 4
M.last_used_controller = M.KEYBOARD

---Updates the last used controller
---@param event string
function M.update_last_used_controller(event)
    if
        event == "joystickpressed"
        or event == "joystickreleased"
        or event == "joystickaxis"
        or event == "joystickhat"
        or event == "gamepadpressed"
        or event == "gamepadreleased"
        or event == "gamepadaxis"
    then
        M.last_used_controller = M.JOYSTICK
    elseif event == "keypressed" or event == "keyreleased" then
        M.last_used_controller = M.KEYBOARD
    elseif
        event == "mousepressed"
        or event == "mousereleased"
        or event == "mousefocus"
        or event == "mousemoved"
        or event == "wheelmoved"
    then
        M.last_used_controller = M.MOUSE
    elseif event == "touchpressed" or event == "touchreleased" or event == "touchmoved" then
        M.last_used_controller = M.TOUCH
    end
end

return M
