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
local input = require("ui.elements.input")
local entry = require("ui.elements.entry")
local icon = require("ui.elements.icon")
local fzy = require("extlibs.fzy_lua")
local async = require("async")

local name_layout_map = {}
local dependency_setting_map = {}
local disabled_updaters = {}

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
        end
    elseif property.category == "Input" then
        local schemes = config.get(property.name)
        local item_layout
        local function new_binding(scheme_name, input_id)
            local function search_indices()
                local scheme_index, id_index
                for k = 1, #schemes do
                    if schemes[k].scheme == scheme_name then
                        scheme_index = k
                        break
                    end
                end
                for k = 1, #schemes[scheme_index].ids do
                    if schemes[scheme_index].ids[k] == input_id then
                        id_index = k
                        break
                    end
                end
                return scheme_index, id_index
            end
            return quad:new({
                    child_element = input:new(scheme_name, input_id, {
                        change_handler = function(id)
                            -- search scheme and id index as it may have change
                            local scheme_index, id_index = search_indices()
                            input_id = id
                            schemes[scheme_index].ids[id_index] = id
                        end,
                    }),
                    selectable = true,
                    selection_handler = function(self)
                        if self.selected then
                            self.border_color = { 0, 0, 1, 1 }
                        else
                            self.border_color = { 1, 1, 1, 1 }
                        end
                    end,
                    click_handler = function(self)
                        self.element:wait_for_input():done(function(btn)
                            local is_in = false
                            for i = 1, #item_layout.elements do
                                if item_layout.elements[i] == self then
                                    is_in = true
                                    break
                                end
                            end
                            if not is_in then
                                if btn then
                                    return
                                end
                                table.insert(item_layout.elements, #item_layout.elements, self)
                                item_layout:mutated(false)
                            end
                            if btn == "remove" then
                                -- search scheme and id index as it may have change
                                local scheme_index, id_index = search_indices()
                                table.remove(schemes[scheme_index].ids, id_index)
                                -- remove quad from parent
                                table.remove(self.parent.elements, self.parent_index)
                                item_layout:mutated(false)
                                layout.changed = true
                                require("ui.elements.element").update_size(item_layout)
                            else
                                self:update_size()
                            end
                        end)
                        return true
                    end,
                })
        end
        local items = { }
        for i = 1, #schemes do
            for j = 1, #schemes[i].ids do
                local scheme_name = schemes[i].scheme
                local input_id = schemes[i].ids[j]
                items[#items + 1] = new_binding(scheme_name, input_id)
            end
        end
        items[#items + 1] = quad:new({
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
                local scheme = "keyboard"
                local input_id = "a"
                local scheme_index
                for i = 1, #schemes do
                    if schemes[i].scheme == scheme then
                        scheme_index = i
                        break
                    end
                end
                if not scheme_index then
                    scheme_index = #schemes + 1
                    schemes[#schemes + 1] = {
                        scheme = scheme,
                        ids = { input_id }
                    }
                else
                    schemes[scheme_index].ids[#schemes[scheme_index].ids+1] = input_id
                end
                local elem = new_binding(scheme, input_id)
                elem:click()
                return true
            end
        })
        item_layout = flex:new(items, { align_items = "center" })
        layout = flex:new({ label:new(property.display_name), item_layout }, { justify_content = "between", align_items = "center" })
    end
    name_layout_map[name] = layout
    return layout
end

local settings = overlay:new()
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
            if self.selected then
                self.border_color = { 0, 0, 1, 1 }
            else
                self.border_color = { 1, 1, 1, 1 }
            end
            keyboard_navigation.scroll_into_view(category_settings)
            -- make keyboard navigation go into the category and not wherever it was last when going into the settings column
            category_settings.parent.last_selection = category_settings
        end,
    })
end

local settings_column = flex:new(category_layouts, { direction = "column", align_items = "stretch" })
local category_column = flex:new(category_indicators, { direction = "column" })
local settings_body = flex:new({
    category_column,
    scroll:new(settings_column),
})

local content = flex:new({
    flex:new({
        entry:new({
            no_text_text = "Search",
            change_handler = function(text)
                if text == "" then
                    -- no search, show all settings and show categories again
                    settings_column.elements = category_layouts
                    settings_column.changed = true
                    category_column.elements = category_indicators
                    category_column.changed = true
                    settings_body:mutated()
                    return
                end
                -- search settings by scoring the display name with fuzzy search
                local result = {}
                local score_list = {}
                for name in pairs(config.get_definitions(false)) do
                    local score = fzy.score(text, name)
                    if score ~= fzy.get_score_min() then
                        local added = false
                        for i = #score_list, 1, -1 do
                            local next_score = score_list[i]
                            if next_score > score then
                                table.insert(score_list, i + 1, score)
                                table.insert(result, i + 1, name)
                                added = true
                                break
                            end
                        end
                        if not added then
                            table.insert(score_list, 1, score)
                            table.insert(result, 1, name)
                        end
                    end
                end
                -- show the results
                local new_layouts = {}
                for i = 1, #result do
                    -- use `#new_layouts + 1` instead of `i` to prevent nil in list
                    new_layouts[#new_layouts + 1] = name_layout_map[result[i]]
                end
                settings_column.elements = new_layouts
                -- still need mutated to update child indices
                settings_column:mutated()
                settings_column.changed = true
                -- don't show categories in search result view
                category_column.elements = {}
                category_column.changed = true
                settings_body:mutated()
            end,
        }),
        quad:new({
            child_element = icon:new("x-lg"),
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
    }, { justify_content = "between" }),
    settings_body,
}, { direction = "column" })
settings.layout = quad:new({
    child_element = content,
    style = { padding = 0 },
})
content:set_style({ padding = 8 })

settings.transition = transitions.slide

return settings
