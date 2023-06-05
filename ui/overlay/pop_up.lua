local layout = require("ui.layout")
local text_box = require("ui.element.text_box")
local theme = require("ui.theme")
local button = require("ui.element.button")
local list = require("ui.list")
local signal = require("anim.signal")

local M = {}
M.BUTTON_SPACING = text_box.MARGIN_WIDTH
M.BUTTON_HEIGHT = text_box.MARGIN_WIDTH * 2 + text_box.FONT:getHeight()

---@class PopUp:Screen
---@field scale Queue
---@field text_box TextBox
---@field buttons TextBox[]
local PopUp = {}
PopUp.__index = PopUp

function PopUp:draw()
    love.graphics.setColor(0, 0, 0, 0.4 * self.scale())
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.height)

    love.graphics.translate(layout.center_x, layout.center_y)
    love.graphics.scale(self.scale())

    self.text_box:draw()
    -- for _, btn in pairs(self.buttons) do
    --     btn:draw()
    -- end

    love.graphics.origin()
end

function PopUp:open()
    self.pass = false
    self.scale:fast_forward()
    self.scale:keyframe(0.05, 1)
end

function PopUp:handle_event(name, a, b, c, d, e, f)
    if name == "keyreleased" then
        if a == "escape" then
            self.down:open()
            self.pass = true
            self.scale:fast_forward()
            self.scale:keyframe(0.05, 0)
            self.scale:call(function()
                list.remove(self)
            end)
        end
    end
end

-- TODO: testing for now...

---Creates a new pop-up screen. A close button is always present. Its text can be overridden.
---Any number of extra buttons and events can be specified.
---@param text string
---@param ... string|function
function M.new_pop_up(text, ...)
    local new_screen = setmetatable({}, PopUp)

    -- local width = theme.open_square_font[20]:getWidth(close_text_override or "CLOSE") + 2 * M.BUTTON_SPACING
    -- if button_text then
    --     assert(event, "Pop-up secondary action function required.")
    --     width = width + theme.open_square_font[20]:getWidth(button_text) + M.BUTTON_SPACING
    -- end

    -- local close_button = button.new_rectangular_button(text_box.new("CLOSE", x, y,  ), function()
    --     list.remove(new_screen)
    -- end)

    local width = 300
    local height = 300

    ---@type PopUp

    new_screen.text_box = text_box.new(text, width / -2, height / -2, width, height, "center")
    new_screen.scale = signal.new_queue(0)

    return new_screen
end

return M
