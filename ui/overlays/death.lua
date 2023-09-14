local flex = require("ui.layout.flex")
local quad = require("ui.elements.quad")
local label = require("ui.elements.label")

return function(back_func, retry_func)
    return flex:new({
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
                click_handler = retry_func,
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
                click_handler = back_func,
            }),
        }, { align_items = "center" }),
    }, { direction = "column", align_items = "center" })
end
