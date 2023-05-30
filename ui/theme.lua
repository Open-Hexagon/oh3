-- For storing colors, fonts, etc
local theme = {}
theme.img_font = love.graphics.newImageFont(
    "assets/font/open_square_image/font.png",
    [[ !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~]],
    0
)
theme.img_font_shader = love.graphics.newShader("assets/font/open_square_image/font.frag")
theme.font = love.graphics.newFont("assets/font/OpenSquare-Regular.ttf")
theme.text_color = { 1, 1, 1, 1 }
theme.border_color = { 1, 1, 1, 1 }
theme.background_color = { 0, 0, 0, 0.5 }

theme.title = {}
theme.title.main_color = { 1, 0.23, 0.13, 1 }
theme.title.panel_colors = {
    { 0.1, 0.02, 0.04, 1 },
    { 0.13, 0.02, 0.1, 1 },
}
theme.title.text_color = { 1, 1, 1, 1 }
theme.title.text_outline_color = theme.title.main_color

return theme
