local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local dropdown = require("ui.elements.dropdown")
local toggle = require("ui.elements.toggle")
local slider = require("ui.elements.slider")
local game_handler = require("game_handler")

local packs = game_handler.get_packs()

local level = {}
local pack = {}
local cache_objects = {}
local pack_index = 1

--level element! if this is used in more than just the level select, this should be seperate ;o
function level:new(info)
    info = info or {}
    local music = info.song .. "\n" .. info.composer

    return quad:new({
        child_element = flex:new({
            quad:new({
                child_element = label:new(info.image), --should be a preview of the level
                style = { background_color = { 0, 0, 0, 0 }, border_color = { 1, 1, 1, 1 } },
            }),
            flex:new({
                flex:new({
                    label:new(info.title, { font_size = 40 }),
                    label:new(info.author, { font_size = 30 }),
                }, { direction = "column", style = { padding = 5 } }),
                label:new(info.description, { font_size = 20, wrap = true }),
            }, { direction = "column" }),
            label:new(music, { font_size = 30 }),
        }, { direction = "row" }),
        style = { background_color = { 0, 0, 0, 0.7 }, border_color = { 0, 0, 0, 0.7 } },
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
                    flex_obj.elements[2] = flex:new(
                        pack:get_all_levels(packs[uid]),
                        { direction = "column", align_items = "start", scrollable = true }
                    )
                    flex_obj:calculate_layout(flex_obj.last_available_area)
                    cache_objects[uid] = flex_obj.elements[2]
                else
                    flex_obj.elements[2] = cache_objects[uid] --this would be where the cache is :(
                end --todo: set parent_index (useful when level keyboard navigation exists)
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
        })
    end
    return levellist
end

flex_obj = flex:new({
    --packs
    flex:new({
        dropdown:new({ "All Packs", "Favorites" }, { limit_to_inital_width = true }),
        flex:new(pack:get_all_packs(), { direction = "column", align_items = "stretch" }),
    }, { direction = "column", align_items = "stretch", scrollable = true }),

    --levels
    flex:new(pack:get_all_levels(packs[1]), { direction = "column", align_items = "start", scrollable = true }),

    --leaderboards
    flex:new({
        label:new("lbs"), --todo: "score" element similar to those other two, holds the score data like time, player, place, etc.
    }, { direction = "column", align_items = "start" }),
}, { size_ratios = { 1, 2, 1 }, scrollable = false })

return flex_obj
