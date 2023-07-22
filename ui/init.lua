local signal = require("ui.anim.signal")
local overlays = require("ui.overlays")
local flex = require("ui.layout.flex")
local ui = {}
local screens = {
    test = require("ui.screens.test"),
}
local keyboard_navigation = require("ui.keyboard_navigation")
local current_screen
local gui_scale = 1

---set gui scale
---@param scale number
function ui.set_scale(scale)
    gui_scale = scale
    if current_screen then
        current_screen:set_scale(scale)
    end
end

local function calculate_layout(width, height)
    local screen_area = {
        x = 0,
        y = 0,
        width = width or love.graphics.getWidth(),
        height = height or love.graphics.getHeight(),
    }
    if current_screen.scale ~= gui_scale then
        current_screen:set_scale(gui_scale)
    end
    local res_width, res_height = current_screen:calculate_layout(screen_area)
    -- as long as the resulting layout is too big for the window, lower gui scale
    while res_width > screen_area.width or res_height > screen_area.height do
        local new_scale = current_screen.scale - 0.1
        if new_scale <= 0.1 then
            return
        end
        current_screen:set_scale(new_scale)
        res_width, res_height = current_screen:calculate_layout(screen_area)
    end
end

---open a menu screen
---@param name string
function ui.open_screen(name)
    current_screen = screens[name]
    if current_screen then
        calculate_layout()
        keyboard_navigation.set_screen(current_screen)
    end
end

---process a window event
---@param name string
---@param ... unknown
function ui.process_event(name, ...)
    local stop_propagation = overlays.process_event(name, ...)
    if current_screen then
        if name == "resize" then
            calculate_layout(...)
        elseif name == "keypressed" then
            local key = ...
            if key == "left" then
                keyboard_navigation.move(-1, 0)
            elseif key == "right" then
                keyboard_navigation.move(1, 0)
            elseif key == "up" then
                keyboard_navigation.move(0, -1)
            elseif key == "down" then
                keyboard_navigation.move(0, 1)
            end
        end
        if not stop_propagation then
            current_screen:process_event(name, ...)
        end
    end
    flex.scrolled_already = nil
end

---update animations
---@param dt number
function ui.update(dt)
    signal.update(dt)
    overlays.update(dt)
end

---draw the ui
function ui.draw()
    if current_screen then
        current_screen:draw()
    end
    overlays:draw()
end

return ui
