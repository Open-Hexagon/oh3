local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local dropdown = require("ui.elements.dropdown")
local level_preview = require("ui.elements.level_preview")
local game_handler = require("game_handler")
local profile = require("game_handler.profile")

local cache_folder_flex = {}
local root
local level_element_selected
local level_options_selected = { difficulty_mult = 1 }

local function update_element(self, parent, parent_index, layout)
    self.parent_index = parent_index
    self.parent = parent
    self:set_scale(parent.scale)
    self:calculate_layout(layout.last_available_area)
    return self
end

local function make_localscore_elements(pack, level, level_options)
    local data = profile.get_scores(pack, level, level_options)
    local score = 0
    for i = 1, #data do
        if data[i].score > score then
            score = data[i].score
        end
    end
    return flex:new({
		quad:new({
			child_element = flex:new({
				label:new("Your Score:", { font_size = 16, wrap = true }),
				label:new(tostring(math.floor(score * 1000) / 1000), { font_size = 60, cutoff_suffix = "..." })
			}, { direction = "column", align_items = "stretch" }),
			style = { background_color = { 0, 0, 0, 0.7 }, border_color = { 0, 0, 0, 0.7 }, border_thickness = 5 }
		})
    }, { direction = "column", align_items = "stretch" })
end

local function make_options_elements(pack, level)
    local selections = {}
    local selections_index = 1
    --this has a weird forumla because: the last diff is always 1, but it should be the first diff.
    selections[1] = level.options.difficulty_mult[#level.options.difficulty_mult]
    for i = 1, #level.options.difficulty_mult - 1 do
        selections[i + 1] = level.options.difficulty_mult[i]
    end
    --this is for the level selection presets! the proper level settings need their own button and menu (see prototype)
    local selection_element = quad:new({
        child_element = label:new(
            selections[selections_index],
            { font_size = 30, style = { color = { 0, 0, 0, 1 } }, wrap = true }
        ),
        style = { background_color = { 1, 1, 1, 1 }, border_color = { 0, 0, 0, 1 }, border_thickness = 5 },
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.border_color = { 0, 0, 1, 1 }
            else
                self.border_color = { 0, 0, 0, 1 }
            end
        end,
        click_handler = function(self)
            selections_index = (selections_index % #selections) + 1
            local selections_element = label:new(
                selections[selections_index],
                { font_size = 30, style = { color = { 0, 0, 0, 1 }, padding = 8 }, wrap = true }
            )
            self.background_color = { 1, 1, 0, 1 }
            self.element = update_element(selections_element, self, 1, self.element)
            level_options_selected = { difficulty_mult = selections[selections_index] }
            local score = flex:new({
                make_localscore_elements(pack.id, level.id, level_options_selected),
            }, { direction = "column", align_items = "stretch" })
            root.elements[3].elements[1] = update_element(score, root, 3, root.elements[3].elements[1])
        end,
    })
    return flex:new({
        selection_element,
    }, { direction = "column", align_items = "stretch" })
end

local function make_level_element(pack, level, extra_info)
    extra_info = extra_info or {}
    extra_info.song = extra_info.song or "no song"
    extra_info.composer = extra_info.composer or "no composer"
    local music = extra_info.song .. "\n" .. extra_info.composer
    local preview = level_preview:new(pack.game_version, pack.id, level.id, { style = { padding = 0 } })
    local elem = quad:new({
        child_element = flex:new({
            quad:new({
                child_element = preview,
                style = { background_color = { 0, 0, 0, 0 }, border_color = { 1, 1, 1, 1 } },
            }),
            flex:new({
                flex:new({
                    label:new(level.name, { font_size = 40, wrap = true }),
                    label:new(level.author, { font_size = 26, wrap = true }),
                }, { direction = "column", style = { padding = 5 } }),
                label:new(level.description, { font_size = 16, wrap = true }), -- the future is now!
            }, { direction = "column" }),
            --flex:new({label:new(music, { font_size = 30, wrap = true })}, { align_items = "end", direction = "column" }),
        }, { direction = "row" }),
        style = { background_color = { 0, 0, 0, 0.7 }, border_color = { 0, 0, 0, 0.7 }, border_thickness = 5 },
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.border_color = { 0, 0, 1, 0.7 }
            else
                self.border_color = { 0, 0, 0, 0.7 }
            end
        end,
        click_handler = function(self)
            if level_element_selected ~= self then
                local elems = self.parent.elements
                for i = 1, #elems do
					if(elems[i] == self) then 
						description = label:new(level.description, { font_size = 16, wrap = true })
						self.background_color = { 0.5, 0.5, 0, 0.7 }
					else
						--description = label:new("", { })
						text = elems[i].element.elements[2].elements[2].raw_text
						if(string.find(text,"\n") == nil) then description = label:new(text, { font_size = 16, wrap = true })
						else description = label:new(string.sub(text,1,string.find(text,"\n")-1) .. "\nRead more...", { font_size = 16, wrap = true }) end
						elems[i].background_color = { 0, 0, 0, 0.7 }
					end
					elems[i].element.elements[2].elements[2] = update_element(description, elems[i].element.elements[2], 2, elems[i].element.elements[2].elements[2])
                end
                root.elements[2] = update_element(root.elements[2], root, 2, root.elements[2])
                local score = flex:new({
                    make_localscore_elements(pack.id, level.id, { difficulty_mult = 1 }),
                    make_options_elements(pack, level),
                }, { direction = "column", align_items = "stretch" })
                if level_element_selected then
                    level_element_selected.background_color = { 0, 0, 0, 0.7 }
                end
                root.elements[3] = update_element(score, root, 3, root.elements[3])
                level_element_selected = self
                -- reset options (TODO: make options not be dm specific)
                level_options_selected = { difficulty_mult = 1 }
            else
                local ui = require("ui")
                game_handler.set_version(pack.game_version)
                game_handler.record_start(pack.id, level.id, level_options_selected)
                ui.open_screen("game")
            end
        end,
    })
    -- store in here for better access
    elem.preview = preview
    return elem
end

local function area_equals(a1, a2)
    return a1.x == a2.x and a1.y == a2.y and a1.width == a2.width and a1.height == a2.height
end

local function make_pack_elements()
    -- table structure is the same as https://tech-cmp.lambdacraft.dev:8001/get_packs
    local packs = game_handler.get_packs()
    local elements = {}
    for i = 1, #packs do
        local pack = packs[i]
        if #pack.levels > 0 then
            elements[#elements + 1] = quad:new({
                child_element = label:new(pack.name, { font_size = 30, style = { color = { 0, 0, 0, 1 } }, wrap = true }),
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
                    local last_levels = root.elements[2]
                    if levels then
                        -- element exists in cache, use it
                        -- recalculate layout if window size changed
                        if
                            not area_equals(levels.last_available_area, last_levels.last_available_area)
                            or root.scale ~= levels.scale
                        then
                            levels:set_scale(root.scale)
                            levels:calculate_layout(last_levels.last_available_area)
                        end
                        -- check if previews need redraw (happens when game is started during load)
                        for j = 1, #levels.elements do
                            local preview = levels.elements[j].preview
                            if not preview.image then
                                preview:redraw()
                            end
                        end
                    else
                        -- element does not exist in cache, create it
                        local level_elements = {}
                        for j = 1, #pack.levels do
                            local level = pack.levels[j]
                            level_elements[j] = make_level_element(pack, level)
                        end
                        levels = flex:new(
                            level_elements,
                            { direction = "column", align_items = "stretch", scrollable = true }
                        )
                        cache_folder_flex[pack.id] = update_element(levels, root, 2, last_levels)
                    end
                    if root.elements[2] ~= levels then
                        levels.elements[1]:click(false)
                    end
                    root.elements[2] = levels
                end
            })
        end
    end
    return elements
end

local pack_elems = make_pack_elements()
root = flex:new({
    --packs
    flex:new({
        dropdown:new({ "All Packs", "Favorites" }, { limit_to_inital_width = true, style = { border_thickness = 5 } }),
        flex:new(pack_elems, { direction = "column", align_items = "stretch", scrollable = true }),
    }, { direction = "column", align_items = "stretch" }),

    --levels
    flex:new({}, { direction = "column", align_items = "center" }),

    --leaderboards
    flex:new({
        label:new("", { font_size = 40, wrap = true }),
        label:new("", { font_size = 40, wrap = true }),
    }, { direction = "column", align_items = "stretch" }),
    --todo: "score" element similar to those other two, holds the score data like time, player, place, etc.
}, { size_ratios = { 1, 2, 1 }, scrollable = false })

if #pack_elems > 0 then
    pack_elems[1]:click(false)
end

return root
