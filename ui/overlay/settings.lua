local stack = require "ui.list"
local hud = require "ui.overlay.hud"

local settings = {}

function settings.draw()
    love.graphics.print("This is the settings overlay", 0, 30)
end

function settings.handle_event(name, a, b, c, d, e, f)
    if name == "keypressed" then
        if a == "tab" then
            stack.pop()
        elseif a == "t" then
            stack.push(hud)
        end
    elseif name == "mousereleased" then

    end
end

return settings