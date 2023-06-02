local signal = require("anim.signal")
local layout = require("ui.layout")
local theme = require("ui.theme")
local image = require("ui.image")

-- Assets
local img_open = love.graphics.newImage("assets/image/text/open.png")
local img_open_centering = image.get_centering_transform(img_open:getDimensions())
local img_hex = love.graphics.newImage("assets/image/text/hexagon.png")
local img_hex_centering = image.get_centering_transform(img_hex:getDimensions())

-- Game title text
---@type Screen
local title = {}

title.pass = false
title.position = signal.new_queue(0.25)

title.y_open = signal.lerp(layout.TOP, layout.BOTTOM, title.position)
title.y_hex = signal.lerp(layout.BOTTOM, layout.TOP, title.position)
-- Both of these aren't true signals so mul has to be explicitly called
title.scale = signal.mul(layout.MINOR, 0.00045)

function title.draw()
    love.graphics.setShader(theme.bicolor_shader)
    theme.bicolor_shader:send(theme.TEXT_COLOR_UNIFORM, theme.background_main_color)
    theme.bicolor_shader:send(theme.TEXT_OUTLINE_COLOR_UNIFORM, theme.border_color)

    love.graphics.push()
    love.graphics.translate(layout.center_x, title.y_open())
    love.graphics.scale(title.scale())
    love.graphics.draw(img_open, img_open_centering)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(layout.center_x, title.y_hex())
    love.graphics.scale(title.scale())
    love.graphics.draw(img_hex, img_hex_centering)
    love.graphics.pop()

    love.graphics.setShader()
end

function title.handle_event(name, a, b, c, d, e, f)
    if name == "keyreleased" or name == "mousereleased" then
        return "title_to_menu"
    end
end

return title
