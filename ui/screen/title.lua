local signal = require("anim.signal")
local layout = require("ui.layout")
local theme = require("ui.theme")
local image = require("ui.image")
local mouse = require("mouse_button")

-- local text_box = require("ui.element.text_box")
-- local button = require("ui.element.button")

-- local test = text_box.new([[
--     ==> Aut officia quia quis. Qui et atque enim. Pariatur illum officia voluptas ea deserunt quia. Qui consectetur sit dignissimos provident officia vel. Qui voluptas in dolorum.

-- Non laudantium necessitatibus debitis nobis voluptatem incidunt reiciendis. Maxime sed et sunt harum nihil. Dolores non sit pariatur repellat.

-- Ipsum ipsum iusto dignissimos consequatur omnis. Hic earum eos itaque. Reprehenderit sunt totam est enim ea. Sit facere quidem temporibus magnam voluptatem cumque.

-- Nostrum rem aut nemo modi aperiam in. Placeat dicta labore officiis reprehenderit et unde maiores debitis. Ut iste aliquam id architecto expedita autem. Impedit et doloremque aut deserunt assumenda. Repellendus ab cumque laborum. Et labore enim dolores quaerat molestiae ut.

-- Enim et aspernatur facere hic quia qui inventore officiis. Qui omnis rerum et nemo repellat id in. Et magnam laborum illum qui occaecati quisquam iusto. Ipsam qui minima eos dolorem ullam sapiente.
-- ]], 30, 30, layout.CENTER_X, layout.CENTER_Y)

-- local test_button = button.new_rectangular_button(test)
-- test_button:select()

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

function title:draw()
    love.graphics.setShader(theme.bicolor_shader)
    theme.bicolor_shader:send(theme.TEXT_COLOR_UNIFORM, theme.background_main_color)
    theme.bicolor_shader:send(theme.TEXT_OUTLINE_COLOR_UNIFORM, theme.border_color)

    love.graphics.push()
    love.graphics.translate(layout.center_x, self.y_open())
    love.graphics.scale(self.scale())
    love.graphics.draw(img_open, img_open_centering)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(layout.center_x, self.y_hex())
    love.graphics.scale(self.scale())
    love.graphics.draw(img_hex, img_hex_centering)
    love.graphics.pop()

    love.graphics.setShader()
end

function title:handle_event(name, a, b, c, d, e, f)
    if name == "keyreleased" then
        if a == "escape" or a == "return" then
            return "title_to_menu"
        end
    elseif name == "mousereleased" then
        if c == mouse.LEFT then
            return "title_to_menu"
        end
    end
end

return title
