local log = require("log")(...)
local overlay = require("ui.overlay")
local keyboard_navigation = require("ui.keyboard_navigation")
local transitions = require("ui.anim.transitions")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local config = require("config")
local scroll = require("ui.layout.scroll")
local toggle = require("ui.elements.toggle")
local slider = require("ui.elements.slider")
local entry = require("ui.elements.entry")
local icon = require("ui.elements.icon")
local search = require("ui.search")
local input_setting = require("ui.overlay.settings.input")
local settings_profile_selection = require("ui.overlay.settings.settings_profile_selection")
local theme = require("ui.theme")
local element = require("ui.elements.element")

local name_layout_map = {}
local all_setting_layouts = {}
local dependency_setting_map = {}
local disabled_updaters = {}
local gui_setters = {}

---create a setting element
---@param name string
---@param property table
---@param value any
---@return flex
local function create_setting(name, property, value)
    -- dependency disable management
    for dependency in pairs(property.dependencies or {}) do
        dependency_setting_map[dependency] = dependency_setting_map[dependency] or {}
        dependency_setting_map[dependency][#dependency_setting_map[dependency] + 1] = property
    end
    local function onchange()
        local props = dependency_setting_map[property.name] or {}
        for i = 1, #props do
            local disable = false
            for dependency, val in pairs(props[i].dependencies) do
                if config.get(dependency) ~= val then
                    disable = true
                    break
                end
            end
            local elem = name_layout_map[props[i].name]
            if elem then
                elem:set_style({ disabled = disable })
            end
        end
    end
    disabled_updaters[#disabled_updaters + 1] = onchange

    local layout
    if type(property.default) == "boolean" then
        -- toggle with text
        local setter = toggle:new()
        layout = flex:new({
            setter,
            label:new(property.display_name, {
                click_handler = function()
                    setter:click()
                end,
            }),
        })
        if value then
            setter:click(false)
        end
        setter.change_handler = function(state)
            config.set(name, state)
            onchange()
            if property.onchange then
                if property.onchange(state) then
                    return true
                end
            end
        end
        gui_setters[name] = function(state)
            setter:set(state)
        end
    elseif type(property.default) == "number" then
        if property.min and property.max and property.step then
            -- slider with text
            local steps = (property.max - property.min) / property.step + 1
            local setter = slider:new({
                step_size = 200 / steps,
                steps = steps,
                initial_state = (value - property.min) * (steps - 1) / (property.max - property.min),
            })
            local text = label:new(property.display_name .. ": " .. value, {
                click_handler = function()
                    setter:click()
                end,
            })
            layout = flex:new({
                setter,
                text,
            })
            setter.change_handler = function(state)
                state = state * (property.max - property.min) / (steps - 1) + property.min
                if property.name == "fps_limit" and state == 1001 then
                    state = 0
                end
                config.set(name, state)
                onchange()
                if property.name == "fps_limit" and state == 0 then
                    text.raw_text = property.display_name .. ": Unlimited"
                else
                    text.raw_text = property.display_name .. ": " .. state
                end
                text:update_size()
                if property.onchange then
                    if property.onchange(state) then
                        return true
                    end
                end
            end
            gui_setters[name] = function(state)
                if name == "fps_limit" and state == 0 then
                    state = 1001
                end
                state = (state - property.min) * (steps - 1) / (property.max - property.min)
                setter:set(state)
            end
        end
    elseif property.category == "Input" then
        layout = input_setting:new(property)
        gui_setters[name] = function()
            layout:init_bindings()
        end
    end
    name_layout_map[name] = layout
    all_setting_layouts[#all_setting_layouts + 1] = layout
    return layout
end

local settings = overlay:new()

function settings.set(name, value)
    if gui_setters[name] then
        gui_setters[name](value)
    else
        log("Missing setter for setting: '" .. name .. "'")
    end
end

local categories = config.get_definitions(true)
local category_icons = {
    Gameplay = "hexagon",
    UI = "stack",
    Audio = "volume-up",
    General = "gear",
    Display = "display",
    Input = "controller",
}
local category_layouts = {}
local category_indicators = {}

-- custom category order
local category_names = {
    "General",
    "UI",
    "Display",
    "Audio",
    "Gameplay",
    "Input",
}

for i = 1, #category_names do
    local category = category_names[i]
    local setting_definitions = categories[category]
    local setting_layouts = {}
    local setting_names = {}
    for name in pairs(setting_definitions) do
        setting_names[#setting_names + 1] = name
    end
    -- remove pairs randomness
    table.sort(setting_names)
    for j = 1, #setting_names do
        local name = setting_names[j]
        setting_layouts[#setting_layouts + 1] = create_setting(name, setting_definitions[name], config.get(name))
    end
    -- call all disabled handlers once initially
    for j = 1, #disabled_updaters do
        disabled_updaters[j]()
    end

    local elements = {
        label:new(category),
        unpack(setting_layouts),
    }
    local category_settings = quad:new({
        child_element = flex:new(elements, { direction = "column" }),
    })
    -- save for usage in search
    category_settings.elements = elements

    category_layouts[#category_layouts + 1] = category_settings
    category_indicators[#category_indicators + 1] = quad:new({
        child_element = icon:new(category_icons[category]),
        selectable = true,
        selection_handler = function(self)
            theme.get_selection_handler()(self)
            keyboard_navigation.scroll_into_view(category_settings)
            -- make keyboard navigation go into the category and not wherever it was last when going into the settings column
            category_settings.parent.last_selection = category_settings
        end,
    })
end

local settings_column = flex:new(category_layouts, { direction = "column", align_items = "stretch" })
local category_column = flex:new(category_indicators, { direction = "column" })
local settings_body = flex:new({
    scroll:new(category_column),
    scroll:new(settings_column),
})

local content = flex:new({
    flex:new({
        entry:new({
            no_text_text = "Search",
            change_handler = function(text)
                if text == "" then
                    category_column.elements = category_indicators
                else
                    category_column.elements = {}
                end
                category_column:mutated(false)
                element.update_size(category_column)
                search.create_result_layout(text, all_setting_layouts, settings_column)
            end,
        }),
        settings_profile_selection.layout,
        quad:new({
            child_element = icon:new("x-lg"),
            selectable = true,
            click_handler = function()
                settings:close()
                config.save()
            end,
        }),
    }, { justify_content = "between" }),
    settings_body,
}, { direction = "column" })
settings.layout = quad:new({
    child_element = content,
    style = { padding = 0 },
})
content:set_style({ padding = 6 })

settings.transition = transitions.slide

return settings
