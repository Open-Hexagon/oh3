local config = require("config")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local collapse = require("ui.layout.collapse")
local flex = require("ui.layout.flex")
local entry = require("ui.elements.entry")
local keyboard_navigation = require("ui.keyboard_navigation")
local dialogs = require("ui.overlay.dialog")
local global_config = require("global_config")

local settings_profile_selection = {}

local profile_list = flex:new({}, { direction = "column", align_items = "stretch", align_relative_to = "thickness" })
local dropdown = collapse:new(quad:new({
    child_element = profile_list,
}))

local profile_name_label = label:new(config.get_profile() or "")
local button = quad:new({
    child_element = profile_name_label,
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
    end,
})

local function refresh_list()
    local names = config.list_profiles()
    for i = 1, #names do
        profile_list.elements[i] = quad:new({
            child_element = flex:new({
                label:new(names[i]),
                quad:new({
                    child_element = label:new("-"),
                    click_handler = function()
                        dialogs.yes_no("Do you really want to delete '" .. names[i] .. "'?"):done(function(confirmed)
                            if confirmed then
                                local open_later
                                if i == 1 and names[2] then
                                    open_later = names[2]
                                elseif i ~= 1 and names[1] then
                                    open_later = names[1]
                                else
                                    dialogs.alert("Cannot have no profiles.")
                                    return
                                end
                                config.delete_profile(names[i])
                                global_config.set_settings_profile(open_later)
                                profile_name_label.raw_text = config.get_profile()
                                profile_name_label.changed = true
                                profile_name_label:update_size()
                                refresh_list()
                                for name, value in pairs(config.get_all()) do
                                    require("ui.overlay.settings").set(name, value)
                                end
                            end
                        end)
                        return true
                    end,
                }),
            }, { justify_content = "between" }),
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
                    global_config.set_settings_profile(names[i])
                    for name, value in pairs(config.get_all()) do
                        require("ui.overlay.settings").set(name, value)
                    end
                    button.element.raw_text = config.get_profile()
                    button.element:update_size()
                end
            end,
        })
    end
    local profile_name_entry = entry:new({
        no_text_text = "Profile name",
    })
    profile_list.elements[#names + 1] = flex:new({
        profile_name_entry,
        quad:new({
            child_element = label:new("+"),
            selectable = true,
            selection_handler = function(self)
                if self.selected then
                    self.border_color = { 0, 0, 1, 1 }
                else
                    self.border_color = { 1, 1, 1, 1 }
                end
            end,
            click_handler = function()
                local name = profile_name_entry.text
                if name == "" then
                    dialogs.alert("Settings profile name can't be empty.")
                    return
                end
                local profile_names = config.list_profiles()
                for i = 1, #profile_names do
                    if name == profile_names[i] then
                        dialogs.alert('Settings profile with name "' .. name .. '" already exists.')
                        return
                    end
                end
                config.save()
                config.set_defaults()
                config.create_profile(name)
                refresh_list()
                for setting_name, value in pairs(config.get_all()) do
                    require("ui.overlay.settings").set(setting_name, value)
                end
            end,
        }),
    })
    -- remove leftovers
    while profile_list.elements[#names + 2] ~= nil do
        table.remove(profile_list.elements, #names + 2)
    end
    profile_list:mutated(false)
    require("ui.elements.element").update_size(profile_list)
end

refresh_list()

settings_profile_selection.layout = flex:new({
    button,
    dropdown,
}, { direction = "column" })

return settings_profile_selection
