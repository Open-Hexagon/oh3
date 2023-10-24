local overlay = require("ui.overlay")
local transitions = require("ui.anim.transitions")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local config = require("config")
local scroll = require("ui.layout.scroll")
local toggle = require("ui.elements.toggle")

local settings = overlay:new()

local settings_column = flex:new({}, { direction = "column" })

for name, property in pairs(config.get_definitions()) do
    local value = config.get(name)
    local layout = flex:new({})
    if type(property.default) == "boolean" then
        local setter = toggle:new()
        layout.elements[1] = setter
        layout.elements[2] = label:new(property.display_name)
        if value then
            setter:click(false)
        end
        setter.change_handler = function(state)
            config.set(name, state)
        end
    end
    settings_column.elements[#settings_column.elements+1] = layout
end

settings.layout = quad:new({
    child_element = flex:new({
        flex:new({
            quad:new({
                child_element = label:new("X"),
                selectable = true,
                click_handler = function()
                    settings:close()
                end,
            }),
        }, { direction = "column"}),
        scroll:new(settings_column),
    }, { direction = "column" }),
})

settings.transition = transitions.slide

return settings
