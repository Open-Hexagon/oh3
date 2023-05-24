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

local y_open = signal.lerp(layout.TOP, layout.BOTTOM, title.position)
local y_hex = signal.lerp(layout.BOTTOM, layout.TOP, title.position)
local scale = signal.mul(layout.MINOR, 0.00045)

function title.enter()
    title.position:keyframe(0.2, 0.25, ease.out_back)
end

function title.exit()
    title.position:keyframe(0.2, -0.1, ease.out_back)
end

function title.draw()
    love.graphics.setShader(bicolor_shader)
    bicolor_shader:send("red", theme.title.text_color)
    bicolor_shader:send("blue", theme.title.text_outline_color)

    love.graphics.push()
    love.graphics.translate(layout.center_x, y_open())
    love.graphics.scale(scale())
    love.graphics.draw(img_open, img_open_centered)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(layout.center_x, y_hex())
    love.graphics.scale(scale())
    love.graphics.draw(img_hex, img_hex_centered)
    love.graphics.pop()

    love.graphics.setShader()
end

function title.handle_event(name, a, b, c, d, e, f)
    --TODO: if any button is pressed, go to title menu
    if name == "mousereleased" then

    end
end

return title
