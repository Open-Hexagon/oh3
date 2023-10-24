local overlay = require("ui.overlay")
local transitions = require("ui.anim.transitions")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local config = require("config")
local scroll = require("ui.layout.scroll")
local toggle = require("ui.elements.toggle")

local settings = overlay:new()
local setting_layouts = {}
local definitions = config.get_definitions()
local names = {}
for name in pairs(definitions) do
    names[#names + 1] = name
end
-- remove pairs randomness
table.sort(names)
for i = 1, #names do
    local name = names[i]
    local property = definitions[name]
    local value = config.get(name)
    local row = {}
    if type(property.default) == "boolean" then
        local setter = toggle:new()
        row[1] = setter
        row[2] = label:new(property.display_name)
        if value then
            setter:click(false)
        end
        setter.change_handler = function(state)
            config.set(name, state)
        end
    end
    setting_layouts[#setting_layouts + 1] = flex:new(row)
end

local settings_column = flex:new(setting_layouts, { direction = "column" })

settings.layout = quad:new({
    child_element = flex:new({
        flex:new({
            quad:new({
                child_element = label:new("X"),
                selectable = true,
                selection_handler = function(self)
                    if self.selected then
                        self.border_color = { 0, 0, 1, 1 }
                    else
                        self.border_color = { 1, 1, 1, 1 }
                    end
                end,
                click_handler = function()
                    settings:close()
                end,
            }),
        }, { direction = "column" }),
        scroll:new(settings_column),
    }, { direction = "column" }),
})

settings.transition = transitions.slide

return settings
