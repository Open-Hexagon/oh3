local signal = require("ui.anim.signal")
local overlays = require("ui.overlays")
local game_handler = require("game_handler")
local ui = {}
local keyboard_navigation = require("ui.keyboard_navigation")
local current_screen
local transform = love.math.newTransform()
local gui_scale = 1

---set gui scale
---@param scale number
function ui.set_scale(scale)
    gui_scale = scale
    if current_screen then
        current_screen:set_scale(scale)
        current_screen._transform:reset()
        current_screen._transform:apply(transform)
    end
end

local function calculate_layout(width, height)
    local game_width, game_height
    transform:reset()
    if game_handler.is_running() then
        game_width, game_height = game_handler.get_game_dimensions()
        transform:translate(game_handler.get_game_position())
    end
    current_screen._transform:reset()
    current_screen._transform:apply(transform)
    width = width or game_width or love.graphics.getWidth()
    height = height or game_height or love.graphics.getHeight()
    local res_width, res_height = current_screen:calculate_layout(width, height)
    -- as long as the resulting layout is smaller than the window, up gui scale (until user setting is reached)
    while res_width <= width and res_height <= height do
        local new_scale = current_screen.scale + 0.1
        if new_scale > gui_scale then
            break
        end
        current_screen:set_scale(new_scale)
        res_width, res_height = current_screen:calculate_layout(width, height)
    end
    -- as long as the resulting layout is too big for the window, lower gui scale
    while res_width > width or res_height > height do
        local new_scale = current_screen.scale - 0.1
        if new_scale <= 0.1 then
            return
        end
        current_screen:set_scale(new_scale)
        res_width, res_height = current_screen:calculate_layout(width, height)
    end
end

---open a menu screen
---@param name string
function ui.open_screen(name)
    current_screen = require("ui.screens." .. name)
    if current_screen then
        calculate_layout()
        keyboard_navigation.set_screen(current_screen)
    end
end

function ui.get_screen()
    return current_screen
end

---process a window event
---@param name string
---@param ... unknown
function ui.process_event(name, ...)
    love.graphics.origin()
    if current_screen then
        if name == "resize" then
            calculate_layout(...)
        end
    end
    local stop_propagation = overlays.process_event(name, ...)
    if current_screen then
        if not stop_propagation then
            stop_propagation = current_screen:process_event(name, ...)
        end
        if not stop_propagation and keyboard_navigation.get_screen() == current_screen then
            keyboard_navigation.process_event(name, ...)
        end
    end
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
