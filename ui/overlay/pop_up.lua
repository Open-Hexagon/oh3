local layout = require("ui.layout")
local text_box = require("ui.element.text_box")
local button = require("ui.element.button")
local list = require("ui.list")
local signal = require("anim.signal")

local mouse = require("mouse_button")
local controller = require("controller")

local M = {}
M.BUTTON_SPACING = 20
M.BUTTON_HEIGHT = text_box.MARGIN_WIDTH * 2 + text_box.FONT:getHeight()
M.BUTTON_WIDTH = 175
-- The maximum width a message can be made to be with just text formatting alone.
-- Does not include margins
-- Ignored if the buttons exceed this width.
M.MAX_TEXT_WIDTH = 500
M.MINIMUM_WIDTH = 500

---@class PopUp:Screen
---@field selection RectangularButton The currently selected button
---@field cursor_is_hovering boolean True when the cursor is hovering over any button
---@field default RectangularButton The default button
---@field buttons RectangularButton[]
---@field message TextBox
---@field scale Queue
local PopUp = {}
PopUp.__index = PopUp

function PopUp:draw()
    love.graphics.setColor(0, 0, 0, 0.4 * self.scale())
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.height)

    love.graphics.translate(layout.center_x, layout.center_y)
    love.graphics.scale(self.scale())

    self.message:draw()
    for _, btn in pairs(self.buttons) do
        btn:draw()
    end

    love.graphics.origin()
end

---Checks whether the cursor is overlapping any buttons and updates selection.
---Returns cursor_is_hovering.
---@param x number
---@param y number
---@return boolean
function PopUp:update_cursor_selection(x, y)
    for _, btn in ipairs(self.buttons) do
        if btn:check_cursor(x - layout.center_x, y - layout.center_y) then
            self.cursor_is_hovering = true
            if self.selection ~= btn then
                self.selection:deselect()
                btn:select()
                self.selection = btn
            end
            return self.cursor_is_hovering
        end
    end
    self.cursor_is_hovering = false
    return self.cursor_is_hovering
end

function PopUp:on_insert()
    -- Pop-ups reset to the default option once opened. Unless the mouse was last used and happens to be hovering over a button.
    if
        not (
            controller.last_used_controller == controller.MOUSE
            and self:update_cursor_selection(love.mouse.getPosition())
        )
    then
        self:select_default()
    end

    -- Play the opening animation
    self.pass = false
    self.scale:fast_forward()
    self.scale:keyframe(0.05, 1)
end

-- Selects current option and closes
function PopUp:close()
    if self.selection.event then
        self.selection.event()
    end

    -- Reinitialize the screen below
    self.down:on_insert()

    -- Play the closing animation and remove self once completed
    self.pass = true
    self.scale:fast_forward()
    self.scale:keyframe(0.05, 0)
    self.scale:call(function()
        list.remove(self)
    end)
end

-- Selects the default option
function PopUp:select_default()
    self.selection:deselect()
    self.selection = self.default
    self.selection:select()
end

-- Close while selecting the default option
function PopUp:default_close()
    self:select_default()
    self:close()
end

function PopUp:handle_event(name, a, b, c, d, e, f)
    if name == "keyreleased" then
        if a == "escape" then -- Enters the last option
            self:default_close()
        elseif a == "return" then -- Enters the currently selection
            self:close()
        end
    elseif name == "keypressed" then
        if a == "up" or a == "down" or a == "left" or a == "right" then
            local temp = self.selection[a]
            if not temp then
                return
            end
            self.selection:deselect()
            temp:select()
            self.selection = temp
        end
    elseif name == "mousemoved" or name == "mousepressed" then
        self:update_cursor_selection(a, b)
    elseif name == "mousereleased" then
        if c == mouse.LEFT and self.cursor_is_hovering then
            self:close()
        elseif c == mouse.BUTTON_4 then
            self:default_close()
        end
    end
end

---Creates a new pop-up screen. A close button is always present. Its text can be overridden.
---Any number of extra buttons and events can be specified.
---@param text string
---@param ... any
function M.new_pop_up(text, ...)
    local new_screen = setmetatable({}, PopUp)
    new_screen.buttons = {}

    local button_spec = { ... }
    local button_count = math.ceil(#button_spec * 0.5)

    assert(button_count >= 1, "Cannot create a pop-up with 0 buttons.")

    local wish_text_width = text_box.FONT:getWidth(text)
    local total_button_width = (M.BUTTON_SPACING + M.BUTTON_WIDTH) * button_count - M.BUTTON_SPACING

    local text_wrapping_width
    if total_button_width > M.MAX_TEXT_WIDTH then
        text_wrapping_width = total_button_width
    else
        if wish_text_width > M.MAX_TEXT_WIDTH then
            text_wrapping_width = M.MAX_TEXT_WIDTH
        else
            if wish_text_width > total_button_width then
                text_wrapping_width = wish_text_width
            else
                text_wrapping_width = total_button_width
            end
        end
    end
    local _, lines = text_box.FONT:getWrap(text, text_wrapping_width)
    local text_height = #lines * text_box.FONT:getHeight()
    local message_height = text_height + M.BUTTON_HEIGHT + text_box.MARGIN_WIDTH + 2 * M.BUTTON_SPACING

    local message_width = text_wrapping_width + 2 * text_box.MARGIN_WIDTH
    local initial_button_spacing = (message_width - total_button_width) / 2

    local origin_x, origin_y = message_width / -2, message_height / -2

    new_screen.message = text_box.new(text, origin_x, origin_y, message_width, message_height, "center")

    for i = 1, #button_spec, 2 do
        assert(type(button_spec[i]) == "string", "Pop-up button name must be a string.")
        if button_spec[i + 1] then
            assert(type(button_spec[i + 1]) == "function", "Pop-up button event must be a function.")
        end
        local btn = button.new_rectangular_button(
            text_box.new(
                button_spec[i],
                initial_button_spacing + (M.BUTTON_SPACING + M.BUTTON_WIDTH) * (i - 1) * 0.5 + origin_x,
                text_height + text_box.MARGIN_WIDTH + M.BUTTON_SPACING + origin_y,
                M.BUTTON_WIDTH,
                M.BUTTON_HEIGHT,
                "center"
            ),
            button_spec[i + 1]
        )
        table.insert(new_screen.buttons, btn)
    end

    for i = 1, button_count - 1 do
        new_screen.buttons[i].right = new_screen.buttons[i + 1]
        new_screen.buttons[button_count - (i - 1)].left = new_screen.buttons[button_count - (i - 1) - 1]
    end

    new_screen.default = new_screen.buttons[#new_screen.buttons]
    new_screen.selection = new_screen.default
    new_screen.selection:select()

    new_screen.scale = signal.new_queue(0)
    return new_screen
end

return M
