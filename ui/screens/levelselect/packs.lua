local game_handler = require("game_handler")
local keyboard_navigation = require("ui.keyboard_navigation")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local scroll = require("ui.layout.scroll")
local make_level_element = require("ui.screens.levelselect.level")

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
                selection_handler = function(self, first_time_loading)
					first_time_loading = first_time_loading or false
                    if self.selected or first_time_loading then
						local levels = cache_folder_flex[pack.id]
						if not levels then
							-- element does not exist in cache, create it
							local level_elements = {}
							for j = 1, #pack.levels do
								local level = pack.levels[j]
								level_elements[j] = make_level_element(state, pack, level)
							end
							levels = flex:new(level_elements, { direction = "column", align_items = "stretch" })
							cache_folder_flex[pack.id] = levels
						end
						local pack_changed = levels ~= state.root.elements[2].element
						if pack_changed then
							state.root.elements[2].element = levels
							state.root.elements[2]:mutated()
							keyboard_navigation.select_element(levels.elements[1], false)
							levels.elements[1].selection_handler(levels.elements[1], true)
							keyboard_navigation.select_element(self, false)
							-- reset scroll
							levels.parent.scroll_pos:stop()
							levels.parent.scrollbar_visibility_timer = -2
							levels.parent.scroll_pos:set_immediate_value(0)
							levels.parent.scroll_target = 0
						end
						if self.selected then
							self.style.background_color = { 1, 1, 0, 1 }
							self.style.border_color = { 0, 0, 1, 0.7 }
						end
                    else
						self.style.background_color = { 1, 1, 1, 1 }
                        self.style.border_color = { 0, 0, 0, 0.7 }
                    end
                    self:set_style(self.style)
                end,
                click_handler = function(self)
                end,
            })
        end
    end
    return elements
end
