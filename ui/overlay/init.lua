local keyboard_navigation = require("ui.keyboard_navigation")
local game_handler = require("game_handler")
local flex = require("ui.layout.flex")

local overlays = {}

---@class overlay
---@field is_open boolean
---@field layout table
---@field transition table
local overlay = {}
overlay.__index = overlay

---create a new overlay
---@return overlay
function overlay:new()
    local obj = setmetatable({
        is_open = false,
        layout = flex:new({}),
        transition = nil,
        has_opened_before = false,
    }, overlay)
    overlays[#overlays + 1] = obj
    return obj
end

---calculate layout
function overlay:update_layout()
    self.layout._transform:reset()
    if game_handler.is_running() then
        self.layout._transform:translate(game_handler.get_game_position())
    end
    self.layout:calculate_layout(require("ui").get_dimensions())
end

---open the overlay
function overlay:open()
    if not self.is_open then
        self.is_open = true
        self:update_layout()
        self.last_screen = keyboard_navigation.get_screen()
        keyboard_navigation.set_screen(self.layout)
        if self.transition then
            if not self.has_opened_before then
                self.has_opened_before = true
                self.transition.reset(self.layout)
            end
            self.transition.open(self.layout)
        end
    end
end

---close the overlay
function overlay:close()
    if self.is_open then
        self.is_open = false
        keyboard_navigation.set_screen(self.last_screen)
        if self.transition then
            self.transition.close(self.layout)
        end
    end
end

---set the gui scale of the overlay
---@param scale number
function overlay:set_scale(scale)
    self.layout:set_scale(scale)
end

---let the overlay process an event
---@param name string
---@param ... unknown
---@return boolean?
function overlay:process_event(name, ...)
    if self.is_open then
        if self.layout:process_event(name, ...) then
            return true
        end
        -- overlay closed during event processing, stop propagation
        if not self.is_open then
            return true
        end
        -- update keyboard navigation if overlay is focused
        if keyboard_navigation.get_screen() == self.layout then
            keyboard_navigation.process_event(name, ...)
        end
        -- don't update stuff below if overlay is open
        return true
    end
end

---draw the overlay
function overlay:draw()
    if self.is_open or self.layout.transform:is_animating() then
        self.layout:draw()
    end
end

-- execute a function on all overlays with this metatable
overlay.overlays = setmetatable({}, {
    __index = function(_, fn)
        return function(...)
            local ret
            for i = 1, #overlays do
                ret = overlays[i][fn](overlays[i], ...) or ret
            end
            return ret
        end
    end,
})

return overlay
