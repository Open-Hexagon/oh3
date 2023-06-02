local background = require("ui.screen.background")
local theme = require("ui.theme")
local transform = require("transform")
local ease = require("anim.ease")
local signal = require("anim.signal")
local extmath = require("extmath")
local layout = require("ui.layout")
local image = require("ui.image")

-- Title menu

---@type Screen
local wheel = {}
wheel.angle = 0

wheel.text_radius = signal.new_queue(0)
wheel.abs_text_radius = signal.lerp(layout.MAJOR, background.abs_pivot_radius * 2, wheel.text_radius)

---@type PanelButton?
local selection

-- Individual main menu buttons
---@class PanelButton
---@field a1 number
---@field a2 number
---@field condition function
---@field radius Queue
---@field atext number
---@field text_transform love.Transform
---@field icon love.Image
---@field icon_centering love.Transform
---@field icon_size number
---@field text string
---@field text_scale Signal
local PanelButton = {}
PanelButton.__index = PanelButton

function PanelButton:select()
    self.radius:stop()
    self.radius:keyframe(0.15, 0.985, ease.out_sine)
end

function PanelButton:deselect()
    self.radius:stop()
    self.radius:keyframe(0.15, 0, ease.out_sine)
end

function PanelButton:check_angle(angle)
    return self.condition(angle, self.a1, self.a2)
end

function PanelButton:draw()
    local radius = self.radius()

    if radius ~= 0 then
        local outer_radius = layout.major
        local inner_radius = extmath.lerp(outer_radius, background.abs_pivot_radius(), radius)

        local a1, a2 = self.a1, self.a2
        local x1, y1 = math.cos(a1), math.sin(a1)
        local x2, y2 = math.cos(a2), math.sin(a2)
        love.graphics.setColor(theme.background_main_color)
        local a, b, c, d = transform.scale(outer_radius, x1, y1, x2, y2)
        local e, f, g, h = transform.scale(inner_radius, x2, y2, x1, y1)
        love.graphics.polygon("fill", a, b, c, d, e, f, g, h)
    end

    love.graphics.setShader(theme.bicolor_shader)
    theme.bicolor_shader:send(theme.TEXT_COLOR_UNIFORM, theme.background_main_color)
    theme.bicolor_shader:send(theme.TEXT_OUTLINE_COLOR_UNIFORM, theme.text_color)

    love.graphics.setFont(theme.img_font)
    local text_radius = wheel.abs_text_radius()
    local xt, yt = math.cos(self.atext) * text_radius, math.sin(self.atext) * text_radius
    love.graphics.push()
    love.graphics.translate(xt, yt)
    love.graphics.scale(self.text_scale())
    love.graphics.print(self.text, self.text_transform)
    love.graphics.pop()

    if selection == self then
        theme.bicolor_shader:send("blue", theme.background_main_color)
        theme.bicolor_shader:send("red", { 0, 0, 0, 0 })
        love.graphics.push()
        love.graphics.scale(2 * background.abs_pivot_radius() / self.icon_size)
        love.graphics.draw(self.icon, self.icon_centering)
        love.graphics.pop()
    end
    love.graphics.setShader()
end

---@param a1 number
---@param a2 number
---@param condition function
---@param icon_path string
---@param atext number
---@param text string
---@param text_scale number
---@return PanelButton
local function new_panel_button(a1, a2, condition, icon_path, atext, text, text_scale)
    local newinst = setmetatable({
        radius = signal.new_queue(0),
        a1 = a1,
        a2 = a2,
        condition = condition,
        atext = atext,
        text = text,
    }, PanelButton)
    newinst.icon = love.graphics.newImage(icon_path)
    local width, height = newinst.icon:getDimensions()
    newinst.icon_centering = image.get_centering_transform(width, height)
    newinst.icon_size = width
    newinst.text_transform = love.math.newTransform()
    local text_width = theme.img_font:getWidth(text)
    newinst.text_transform:translate(text_width / -2, theme.img_font_height / -2)
    newinst.text_scale = signal.mul(layout.MINOR, text_scale)
    return newinst
end

--[[
    -5pi/6, -3pi/6
    -3pi/6, -pi/6
    pi/6, 3pi/6
    3pi/6, 5pi/6
    5pi/6, -5pi/6
]]

local panels = {}
do
    local function between(angle, a1, a2)
        return a1 <= angle and angle < a2
    end
    local function not_between(angle, a1, a2)
        return not (a1 <= angle and angle < a2)
    end
    local pi56, pi12, pi16 = 5 * math.pi / 6, math.pi / 2, math.pi / 6

    local play = new_panel_button(-pi16, pi16, between, "assets/image/main_menu_icons/play.png", 0, "PLAY", 0.0005)

    local exit =
        new_panel_button(pi16, pi12, between, "assets/image/main_menu_icons/exit.png", math.pi / 3, "EXIT", 0.00025)

    local settings = new_panel_button(
        -pi56,
        pi56,
        not_between,
        "assets/image/main_menu_icons/settings.png",
        math.pi,
        "SETTINGS",
        0.00015
    )

    panels.play = play
    panels.exit = exit
    panels.settings = settings
end

local function clear_selection()
    if selection then
        selection:deselect()
        selection = nil
    end
end

local function check_cursor(x, y)
    local x0, y0 = layout.width * 0.35, layout.center_y
    x, y = x - x0, y - y0
    if extmath.alpha_max_beta_min(x, y) < background.abs_pivot_radius() then
        -- Cursor is in center
    else
        local angle = math.atan2(y, x)
        for _, panel in pairs(panels) do
            if panel:check_angle(angle) then
                if selection ~= panel then
                    clear_selection()
                    panel:select()
                    selection = panel
                end
                return
            end
        end
    end
    clear_selection()
end

function wheel.open()
    local x, y = love.mouse.getPosition()
    check_cursor(x, y)
end

function wheel.draw()
    love.graphics.translate(background.abs_x(), background.abs_y())
    love.graphics.rotate(background.angle() + wheel.angle)
    for _, panel in pairs(panels) do
        panel:draw()
    end
    love.graphics.origin()
end

function wheel.handle_event(name, a, b, c, d, e, f)
    if name == "keyreleased" then
        if a == "escape" then
            clear_selection()
            return "menu_to_title"
        end
    elseif name == "mousefocus" and not a then
        clear_selection()
    elseif name == "mousemoved" then
        check_cursor(a, b)
    elseif name == "mousereleased" then
        if not selection then
            return "menu_to_title"
        elseif selection == panels.exit then
            love.event.quit()
        elseif selection == panels.play then
            -- TODO: level select
        elseif selection == panels.settings then
            -- TODO: settings menu
        end
    end
end

return wheel
