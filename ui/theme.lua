-- For storing colors
local theme = {}
theme.text_color = { 1, 1, 1, 1 }
theme.border_color = { 1, 1, 1, 1 }

theme.element_background_color = { 0, 0, 0, 0.5 }

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
theme.img_font_height = 360

theme.font = love.graphics.newFont("assets/font/OpenSquare-Regular.ttf")


return theme
