local stack = require("ui.stack")
local settings = require("ui.overlay.settings")
local textbox = require("ui.element.textbox")
local layout = require("ui.layout")
local signal = require("anim.signal")
local ease = require("anim.ease")
local theme = require("ui.theme")
local button= require("ui.element.button")

local ENTRY_HEIGHT = 55

---@class Entry:Selectable
---@field offset Queue
local Entry = {}
Entry.__index = Entry

function Entry:draw()
    local left, top = self.left(), self.top()
    local right, bottom = self.right(), self.bottom()
    local height = bottom - top
    love.graphics.setColor(theme.background_color)
    love.graphics.polygon("fill", left, top, right, top, right, bottom, left + height, bottom)
end

function Entry:select()
    -- self.offset:stop()
    self.offset:keyframe(0.1, -50, ease.out_sine)
    self.selected = true
end

function Entry:deselect()
    -- self.offset:stop()
    self.offset:keyframe(0.1, 0, ease.out_sine)
    self.selected = false
end

local function new_entry(y)
    local offset = signal.new_queue()
    local top = signal.new_signal(y)
    local newinst = setmetatable({
        offset = offset,
        left = signal.new_sum(signal.new_lerp(layout.LEFT, layout.RIGHT, 0.65), offset),
        right = layout.RIGHT,
        top = top,
        bottom = signal.new_sum(top, ENTRY_HEIGHT),
        selected = false,
    }, Entry)
    return newinst
end

local entrylist = {}
local buttonlist = {}

for i = 0, 4 do
    local e = new_entry(70 * i + 150)
    table.insert(entrylist, e)
    table.insert(buttonlist, button.new_rectangle(e, function() print(i) end))
end




-- TODO: something to keep track of what base screen we're on
local screen = "main_menu"

local selection

local title = {}

function title.draw()
    for _, e in pairs(entrylist) do
        e:draw()
    end
end

function title.handle_event(name, a, b, c, d, e, f)
    if name == "keypressed" and a == "tab" then
        stack.push(settings)
    elseif name == "mousemoved" then
        selection = nil
        for _, btn in pairs(buttonlist) do
            if btn:check_cursor(a, b) then
                selection = btn
            end
        end
    elseif name == "mousereleased" then
        if selection then
            selection.event()
        end
    end
end

return title
