local overlay = require("ui.overlay")
local transitions = require("ui.anim.transitions")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local config = require("config")
local scroll = require("ui.layout.scroll")
local toggle = require("ui.elements.toggle")
local slider = require("ui.elements.slider")
local entry = require("ui.elements.entry")
local fzy = require("extlibs.fzy_lua")

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
                config.set(name, state)
                text.raw_text = property.display_name .. ": " .. state
                text.changed = true
                layout:mutated()
            end
        else
            -- TODO: implement all settings to remove need for placeholder
            -- (need to populate setting_layouts list fully for search to work)
            layout = flex:new({})
        end
    else
        -- TODO: implement all settings to remove need for placeholder
        -- (need to populate setting_layouts list fully for search to work)
        layout = flex:new({})
    end
    setting_layouts[#setting_layouts + 1] = layout
end

local settings_column = flex:new(setting_layouts, { direction = "column" })

local content = flex:new({
    flex:new({
        entry:new({
            no_text_text = "Search",
            change_handler = function(text)
                if text == "" then
                    -- no search, show all settings
                    settings_column.elements = setting_layouts
                    settings_column:mutated()
                    return
                end
                -- search settings by scoring the display name with fuzzy search
                local result_indices = {}
                local score_list = {}
                for i = 1, #names do
                    local score = fzy.score(text, names[i])
                    if score ~= fzy.get_score_min() then
                        local added = false
                        for j = #score_list, 1, -1 do
                            local next_score = score_list[j]
                            if next_score > score then
                                table.insert(score_list, j + 1, score)
                                table.insert(result_indices, j + 1, i)
                                added = true
                                break
                            end
                        end
                        if not added then
                            table.insert(score_list, 1, score)
                            table.insert(result_indices, 1, i)
                        end
                    end
                end
                -- show the results
                local new_layouts = {}
                for i = 1, #result_indices do
                    local ind = result_indices[i]
                    print(names[ind], setting_layouts[ind])
                    new_layouts[i] = setting_layouts[result_indices[i]]
                end
                settings_column.elements = new_layouts
                settings_column:mutated()
            end,
        }),
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
    }),
    scroll:new(settings_column),
}, { direction = "column" })
settings.layout = quad:new({
    child_element = content,
    style = { padding = 0 },
})
content:set_style({ padding = 8 })

settings.transition = transitions.slide

return settings
