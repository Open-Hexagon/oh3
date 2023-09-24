local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local dropdown = require("ui.elements.dropdown")
local scroll = require("ui.layout.scroll")
local make_pack_elements = require("ui.screens.levelselect.packs")

local state = {}
state.level_options_selected = { difficulty_mult = 1 }

local pack_elems = make_pack_elements(state)
state.root = flex:new({
    --packs
    flex:new({
        -- dropdowns are broken atm TODO: fix
        --dropdown:new({ "All Packs", "Favorites" }, { limit_to_inital_width = true, style = { border_thickness = 5 } }),
        scroll:new(flex:new(pack_elems, { direction = "column", align_items = "stretch" })),
    }, { direction = "column", align_items = "stretch" }),

    --levels
    scroll:new(flex:new({}, { direction = "column", align_items = "center" })),

    --leaderboards
    flex:new({
        label:new("", { font_size = 40, wrap = true }),
        label:new("", { font_size = 40, wrap = true }),
    }, { direction = "column", align_items = "stretch" }),
    --todo: "score" element similar to those other two, holds the score data like time, player, place, etc.
}, { size_ratios = { 1, 2, 1 } })

if #pack_elems > 0 then
    pack_elems[1]:click(false)
end

return state.root
