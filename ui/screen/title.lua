local signal = require("anim.signal")
local layout = require("ui.layout")
local ease = require("anim.ease")
local theme = require("ui.theme")

-- Assets
local bicolor_shader = love.graphics.newShader("assets/image/title/bicolor.frag")
local img_open = love.graphics.newImage("assets/image/title/open.png")
local img_open_centered = love.math.newTransform()
do
    local width, height = img_open:getDimensions()
    img_open_centered:translate(width / -2, height / -2)
end
local img_hex = love.graphics.newImage("assets/image/title/hexagon.png")
local img_hex_centered = love.math.newTransform()
do
    local width, height = img_hex:getDimensions()
    img_hex_centered:translate(width / -2, height / -2)
end

-- Game title text
---@type Screen
local title = {}

title.pass = false
title.position = signal.new_queue(0.25)

local dimension = {}
dimension.y_open = signal.lerp(layout.TOP, layout.BOTTOM, title.position)
dimension.y_hex = signal.lerp(layout.BOTTOM, layout.TOP, title.position)
-- Both of these aren't true signals so mul has to be explicitly called
dimension.scale = signal.mul(layout.MINOR, 0.00045)

function title.draw()
    love.graphics.setShader(bicolor_shader)
    bicolor_shader:send("red", theme.title.text_color)
    bicolor_shader:send("blue", theme.title.text_outline_color)

    love.graphics.push()
    love.graphics.translate(layout.center_x, dimension.y_open())
    love.graphics.scale(dimension.scale())
    love.graphics.draw(img_open, img_open_centered)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(layout.center_x, dimension.y_hex())
    love.graphics.scale(dimension.scale())
    love.graphics.draw(img_hex, img_hex_centered)
    love.graphics.pop()

    love.graphics.setShader()
end

function title.handle_event(name, a, b, c, d, e, f)
    --TODO: if any button is pressed, go to title menu
    if name == "mousereleased" then
        return "title_to_menu"
    end
end

return {screen = title, dimension = dimension}
