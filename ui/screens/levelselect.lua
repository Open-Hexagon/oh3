local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local dropdown = require("ui.elements.dropdown")
local level_preview = require("ui.elements.level_preview")
local toggle = require("ui.elements.toggle")
local slider = require("ui.elements.slider")
local game_handler = require("game_handler")
local config = require("config")
local global_config = require("global_config")

local packs = game_handler.get_packs()

local level = {}
local pack = {}
local cache_objects = {}
local pack_index = 1
local root

--level element! if this is used in more than just the level select, this should be seperate ;o
function level:new(info, uid)
    info = info or {}
    local music = info.song .. "\n" .. info.composer

    return quad:new({
        child_element = flex:new({
            quad:new({
                child_element = level_preview:new(info.game_version, info.pack_id, info.level_id, { style = { padding = 0 } }),
                style = { background_color = { 0, 0, 0, 0 }, border_color = { 1, 1, 1, 1 } },
            }),
            flex:new({
                flex:new({
                    label:new(info.title, { font_size = 40, wrap = true }),
                    label:new(info.author, { font_size = 26, wrap = true }),
                }, { direction = "column", style = { padding = 5 } }),
                label:new(info.description, { font_size = 16, wrap = true }), -- future: use elements[2] to change this to only appear when selected
            }, { direction = "column" }),
            label:new(music, { font_size = 30, wrap = true }),
        }, { direction = "row" }),
        style = { background_color = { 0, 0, 0, 0.7 }, border_color = { 0, 0, 0, 0.7 } },
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.background_color = { 0.2, 0.2, 0, 0.7 }
				local ui = require("ui")
				game_handler.set_version(21)
				game_handler.record_start(packs[pack_index].id, packs[pack_index].levels[uid].id, {difficulty_mult = 1})
				ui.open_screen("game")
            else
                self.background_color = { 0, 0, 0, 0.7 }
            end
        end,
    })
end

function pack:new(name, uid)
    return quad:new({
        child_element = label:new(name, { font_size = 30, style = { color = { 0, 0, 0, 1 } } }),
        style = { background_color = { 1, 1, 1, 1 }, border_color = { 1, 1, 1, 1 } },
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.background_color = { 1, 1, 0, 1 }
                if true then
                    root.elements[2] = flex:new(
                        pack:get_all_levels(packs[uid]),
                        { direction = "column", align_items = "stretch", scrollable = true }
                    )
                    root:calculate_layout(root.last_available_area)
                    cache_objects[uid] = root.elements[2]
					pack_index = uid
                else
                    root.elements[2] = cache_objects[uid] --this would be where the cache is :(
                end
            else
                self.background_color = { 1, 1, 1, 1 }
            end
        end,
    })
end

function pack:get_all_packs()
    local packlist = {}
    for i = 1, #packs do
        packlist[i] = pack:new(packs[i].name, i)
    end
    return packlist
end

function pack:get_all_levels(selected_pack)
    local levellist = {}
    for i = 1, #selected_pack.levels do
        levellist[i] = level:new({
            image = "",
            title = selected_pack.levels[i].name,
            author = selected_pack.levels[i].author,
            description = selected_pack.levels[i].description,
            song = "",
            composer = "", --these will be filled eventually
        }, i)
		levellist[i].parent_index = i -- this may or may not be the correct way to set parent_index
    end
    return levellist
end

root = flex:new({
    --packs
    flex:new({
        dropdown:new({ "All Packs", "Favorites" }, { limit_to_inital_width = true }),
        flex:new(pack:get_all_packs(), { direction = "column", align_items = "stretch" }),
    }, { direction = "column", align_items = "stretch", scrollable = true }),

    --levels
    flex:new({
        label:new("levels"),
        level:new({
            game_version = 192,
            pack_id = "Open Hexagon Community Tribute",
            level_id = "Open Hexagon Community Tribute_synergy_galaxy",
            title = "title",
            author = "author",
            description = "description is here!! and it is very long and detailed waaa and it even wraps!!",
            song = '"new song"',
            composer = "Theepicosity",
        }),
    }, { direction = "column", align_items = "stretch", scrollable = true }),

    --leaderboards
    flex:new({
        label:new("lbs"), --todo: "score" element similar to those other two, holds the score data like time, player, place, etc.
    }, { direction = "column", align_items = "stretch" }),
}, { size_ratios = { 1, 2, 1 }, scrollable = false })

return root
