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

local function make_options_elements(pack, level)
    local selections = {}
    for i = 1, #level.options.difficulty_mult do
        selections[i] = level.options.difficulty_mult[#level.options.difficulty_mult - i + 1]
    end
    --this is for the level selection presets! the proper level settings need their own button and menu (see prototype)
    local selection_element = dropdown:new(selections, { limit_to_inital_width = true })
    return flex:new({
        selection_element,
    }, { direction = "column", align_items = "stretch" })
end

local function make_localscore_elements(pack, level, level_options)
    local data = profile.get_scores(pack, level, level_options)
    local score = 0
    for i = 1, #data do
        if level == data[i].level then --now this is a little sus, maybe get_scores is incorrect?
            if data[i].score > score then
                score = data[i].score
            end
        end
    end
    return flex:new({
        label:new("Your Score:", { font_size = 16, wrap = true }),
        label:new(math.floor(score * 1000) / 1000, { font_size = 60, wrap = false }),
        --this is for the level selection presets! the proper level settings need their own button and menu (see prototype)
        --dropdown:new({level.options.difficulty_mult}, { limit_to_inital_width = true }),
    }, { direction = "column", align_items = "stretch" })
end

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
            if level_element_selected ~= self then
                self.background_color = { 0.2, 0.2, 0, 0.7 }
                local score = flex:new({
                    make_localscore_elements(pack.id, level.id, { difficulty_mult = 1 }),
                    make_options_elements(pack, level),
                }, { direction = "column", align_items = "stretch" })
                --local last
                score.parent_index = 3
                score.parent = root
                score:set_scale(root.scale)
                score:calculate_layout(root.elements[3].last_available_area)
                if level_element_selected then
                    level_element_selected.background_color = { 0, 0, 0, 0.7 }
                end
                root.elements[3] = score
                level_element_selected = self
            end
        end,
        click_handler = function(self)
            if level_element_selected == self then
                local ui = require("ui")
                game_handler.set_version(pack.game_version)
                game_handler.record_start(pack.id, level.id, { difficulty_mult = 1 })
                ui.open_screen("game")
            end
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
                        if
                            not area_equals(levels.last_available_area, last_levels.last_available_area)
                            or root.scale ~= levels.scale
                        then
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
    flex:new({ label:new("", { font_size = 40, wrap = true }) }, { direction = "column", align_items = "stretch" }),
    --todo: "score" element similar to those other two, holds the score data like time, player, place, etc.
}, { size_ratios = { 1, 2, 1 }, scrollable = false })

return root
