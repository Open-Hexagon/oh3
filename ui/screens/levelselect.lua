local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local dropdown = require("ui.elements.dropdown")
local level_preview = require("ui.elements.level_preview")
local game_handler = require("game_handler")

local cache_folder_flex = {}
local selected_pack
local root

--level element! if this is used in more than just the level select, this should be seperate ;o
local function make_level_element(pack, level, extra_info)
    extra_info = extra_info or {}
    extra_info.song = extra_info.song or "no song"
    extra_info.composer = extra_info.composer or "no composer"
    local music = extra_info.song .. "\n" .. extra_info.composer
    return quad:new({
        child_element = flex:new({
            quad:new({
                child_element = level_preview:new(pack.game_version, pack.id, level.id, { style = { padding = 0 } }),
                style = { background_color = { 0, 0, 0, 0 }, border_color = { 1, 1, 1, 1 } },
            }),
            flex:new({
                flex:new({
                    label:new(level.name, { font_size = 40, wrap = true }),
                    label:new(level.author, { font_size = 26, wrap = true }),
                }, { direction = "column", style = { padding = 5 } }),
                label:new(level.description, { font_size = 16, wrap = true }), -- future: use elements[2] to change this to only appear when selected
            }, { direction = "column" }),
            --flex:new({label:new(music, { font_size = 30, wrap = true })}, { align_items = "end", direction = "column" }),
        }, { direction = "row" }),
        style = { background_color = { 0, 0, 0, 0.7 }, border_color = { 0, 0, 0, 0.7 } },
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.background_color = { 0.2, 0.2, 0, 0.7 }
            else
                self.background_color = { 0, 0, 0, 0.7 }
            end
        end,
        click_handler = function()
            local ui = require("ui")
            game_handler.set_version(pack.game_version)
            game_handler.record_start(selected_pack.id, level.id, { difficulty_mult = 1 })
            ui.open_screen("game")
        end,
    })
end

local function area_equals(a1, a2)
    return a1.x == a2.x and a1.y == a2.y and a1.width == a2.width and a1.height == a2.height
end

local function make_pack_elements()
    local packs = game_handler.get_packs()
    local elements = {}
    for i = 1, #packs do
        local pack = packs[i]
        elements[i] = quad:new({
            child_element = label:new(pack.name, { font_size = 30, style = { color = { 0, 0, 0, 1 } }, wrap = true }),
            style = { background_color = { 1, 1, 1, 1 }, border_color = { 1, 1, 1, 1 } },
            selectable = true,
            selection_handler = function(self)
                if self.selected then
                    self.background_color = { 1, 1, 0, 1 }
                    local levels = cache_folder_flex[pack.id]
                    local last_levels = root.elements[2]
                    if levels then
                        -- element exists in cache, use it
                        -- recalculate layout if window size changed
                        if not area_equals(levels.last_available_area, last_levels.last_available_area) or root.scale ~= levels.scale then
                            levels:set_scale(root.scale)
                            levels:calculate_layout(last_levels.last_available_area)
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
                        levels.parent_index = 2
                        levels.parent = root
                        levels:set_scale(root.scale)
                        levels:calculate_layout(last_levels.last_available_area)
                        cache_folder_flex[pack.id] = levels
                    end
                    root.elements[2] = levels
                    selected_pack = pack
                else
                    self.background_color = { 1, 1, 1, 1 }
                end
            end,
        })
    end
    return elements
end

root = flex:new({
    --packs
    flex:new({
        dropdown:new({ "All Packs", "Favorites" }, { limit_to_inital_width = true }),
        flex:new(make_pack_elements(), { direction = "column", align_items = "stretch", scrollable = true }),
    }, { direction = "column", align_items = "stretch" }),

    --levels
    flex:new({}, { direction = "column", align_items = "stretch", scrollable = true }),

    --leaderboards
    flex:new({
        label:new("lbs"), --todo: "score" element similar to those other two, holds the score data like time, player, place, etc.
    }, { direction = "column", align_items = "stretch" }),
}, { size_ratios = { 1, 2, 1 }, scrollable = false })

return root
