local stack = require "ui.stack"

local hud = {}

function hud.draw()
    love.graphics.print("Here's another overlay", 0, 60)
end

function hud.handle_event(name, a, b, c, d, e, f)
    if name == "keypressed" then
        if a == 't' then
            stack.pop()
        end
    end
end

return hud