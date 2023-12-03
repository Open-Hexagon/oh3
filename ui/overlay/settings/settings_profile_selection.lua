local config = require("config")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local collapse = require("ui.layout.collapse")
local flex = require("ui.layout.flex")
local keyboard_navigation = require("ui.keyboard_navigation")

local settings_profile_selection = {}

local profile_list = flex:new({}, { direction = "column", align_items = "stretch", align_relative_to = "thickness" })
local dropdown = collapse:new(quad:new({
    child_element = profile_list,
}))

local button = quad:new({
    child_element = label:new(config.get_profile() or ""),
    selectable = true,
    selection_handler = function(self)
        if self.selected then
            self.border_color = { 0, 0, 1, 1 }
        else
            self.border_color = { 1, 1, 1, 1 }
        end
    end,
    click_handler = function()
        dropdown:toggle()
    end
})

local function refresh_list()
    local names = config.list_profiles()
    for i = 1, #names do
        profile_list.elements[i] = quad:new({
            child_element = label:new(names[i]),
            selectable = true,
            style = { border_thickness = 0, padding = 0 },
            selection_handler = function(self)
                if self.selected then
                    self.background_color = { 0.5, 0.5, 1, 1 }
                else
                    self.background_color = { 0, 0, 0, 1 }
                end
            end,
            click_handler = function()
                dropdown:toggle(false)
                keyboard_navigation.select_element(button)
                if config.get_profile() ~= names[i] then
                    config.open_profile(names[i])
                    for name, value in pairs(config.get_all()) do
                        require("ui.overlay.settings").set(name, value)
                    end
                end
                button.element.raw_text = config.get_profile()
                button.element:update_size()
            end
        })
    end
    profile_list:mutated(false)
    dropdown:mutated()
end

refresh_list()

settings_profile_selection.layout = flex:new({
    button,
    dropdown,
}, { direction = "column" })

return settings_profile_selection
