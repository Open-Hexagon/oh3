local flex = require("ui.layout.flex")
local quad = require("ui.elements.quad")
local label = require("ui.elements.label")
local overlay = require("ui.overlay")
local game_handler = require("game_handler")

local death = overlay:new()

death.layout = flex:new({
    flex:new({
        quad:new({
            child_element = label:new("Retry"),
            selectable = true,
            selection_handler = function(self)
                if self.selected then
                    self.border_color = { 0, 0, 1, 1 }
                else
                    self.border_color = { 1, 1, 1, 1 }
                end
            end,
            click_handler = function()
                game_handler.stop()
                death:close()
                game_handler.retry()
            end,
        }),
        quad:new({
            child_element = label:new("Back"),
            selectable = true,
            selection_handler = function(self)
                if self.selected then
                    self.border_color = { 0, 0, 1, 1 }
                else
                    self.border_color = { 1, 1, 1, 1 }
                end
            end,
            click_handler = function()
                death:close()
                local ui = require("ui")
                game_handler.preview_start("", "", {}, false, true)
                ui.open_screen("levelselect")
            end,
        }),
    }, { align_items = "center" }),
}, { direction = "column", align_items = "center" })

return death
