-- For storing colors
local theme = {}
theme.text_color = { 1, 1, 1, 1 }
theme.border_color = { 1, 1, 1, 1 }
theme.element_background_color = {0.19, 0.07, 0.19, 1}

theme.background_main_color = { 1, 0.23, 0.13, 1 }
theme.background_panel_colors = {
    { 0.1, 0.02, 0.04, 1 },
    { 0.13, 0.02, 0.1, 1 },
}

theme.wheel_text_color = theme.background_main_color
theme.wheel_text_outline_color = { 1, 1, 1, 1 }

theme.bicolor_shader = love.graphics.newShader("assets/shader/bicolor.frag")

-- Fonts
theme.TEXT_COLOR_UNIFORM = "blue"
theme.TEXT_OUTLINE_COLOR_UNIFORM = "red"

theme.img_font = love.graphics.newImageFont(
    "assets/font/open_square_image/font.png",
    [[ !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~]],
    0
)
theme.IMG_FONT_HEIGHT = theme.img_font:getHeight()

---@type love.Font[]
theme.open_square_font = {}
setmetatable(theme.open_square_font, theme.open_square_font)
theme.open_square_font.__index = function (this, index)
    this[index] = love.graphics.newFont("assets/font/OpenSquare-Regular.ttf", index)
    return this[index]
end

---@type love.Font[]
theme.open_square_bold_font = {}
setmetatable(theme.open_square_bold_font, theme.open_square_bold_font)
theme.open_square_bold_font.__index = function (this, index)
    this[index] = love.graphics.newFont("assets/font/OpenSquare-Bold.ttf", index)
    return this[index]
end

return theme
