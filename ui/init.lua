local ui = {}
local screens = {
    test = require("ui.screens.test"),
}
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
    end
end

---process a window event
---@param name string
---@param ... unknown
function ui.process_event(name, ...)
    if current_screen then
        if name == "resize" then
            calculate_layout(...)
        end
        current_screen:process_event(name, ...)
    end
end

---draw the ui
function ui.draw()
    if current_screen then
        current_screen:draw()
    end
end

return ui
