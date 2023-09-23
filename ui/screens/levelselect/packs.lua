local game_handler = require("game_handler")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local make_level_element = require("ui.screens.levelselect.level")

local function update_element(self, parent, parent_index, layout)
    self.parent_index = parent_index
    self.parent = parent
    self:set_scale(parent.scale)
    self:calculate_layout(layout.last_available_area)
    return self
end

local function area_equals(a1, a2)
    return a1.x == a2.x and a1.y == a2.y and a1.width == a2.width and a1.height == a2.height
end

local cache_folder_flex = {}

return function(state)
    -- table structure is the same as https://tech-cmp.lambdacraft.dev:8001/get_packs
    local packs = game_handler.get_packs()
    local elements = {}
    for i = 1, #packs do
        local pack = packs[i]
        if #pack.levels > 0 then
            elements[#elements + 1] = quad:new({
                child_element = label:new(
                    pack.name,
                    { font_size = 30, style = { color = { 0, 0, 0, 1 } }, wrap = true }
                ),
                style = { background_color = { 1, 1, 1, 1 }, border_color = { 0, 0, 0, 1 }, border_thickness = 4 },
                selectable = true,
                selection_handler = function(self)
                    if self.selected then
                        self.border_color = { 0, 0, 1, 0.7 }
                    else
                        self.border_color = { 0, 0, 0, 0.7 }
                    end
                end,
                click_handler = function(self)
                    for j = 1, #elements do
                        elements[j].background_color = { 1, 1, 1, 1 }
                    end
                    self.background_color = { 1, 1, 0, 1 }
                    local levels = cache_folder_flex[pack.id]
                    local last_levels = state.root.elements[2]
                    if levels then
                        -- element exists in cache, use it
                        -- recalculate layout if window size changed
                        if
                            not area_equals(levels.last_available_area, last_levels.last_available_area)
                            or state.root.scale ~= levels.scale
                        then
                            levels:set_scale(state.root.scale)
                            levels:calculate_layout(last_levels.last_available_area)
                        end
                    else
                        -- element does not exist in cache, create it
                        local level_elements = {}
                        for j = 1, #pack.levels do
                            local level = pack.levels[j]
                            level_elements[j] = make_level_element(state, pack, level)
                        end
                        levels = flex:new(
                            level_elements,
                            { direction = "column", align_items = "stretch", scrollable = true }
                        )
                        cache_folder_flex[pack.id] = update_element(levels, state.root, 2, last_levels)
                    end
                    local pack_changed = levels ~= state.root.elements[2]
                    state.root.elements[2] = levels
                    if pack_changed then
                        levels.elements[1]:click(false)
                    end
                end,
            })
        end
    end
    return elements
end
