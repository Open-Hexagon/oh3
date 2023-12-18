local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local icon = require("ui.elements.icon")
local quad = require("ui.elements.quad")
local scroll = require("ui.layout.scroll")
local settings = require("ui.overlay.settings")
local pack_overlay = require("ui.overlay.packs")
local pack_elements = require("ui.screens.levelselect.packs")

local state = {}
state.level_options_selected = { difficulty_mult = 1 }

local pack_elems = pack_elements.init(state)

state.packs = flex:new(pack_elems, { direction = "column", align_items = "stretch", align_relative_to = "area" })

state.levels = scroll:new(flex:new({}, { direction = "column", align_items = "center" }))

state.leaderboards = flex:new({
    label:new("", { font_size = 40, wrap = true }),
    label:new("", { font_size = 40, wrap = true }),
}, { direction = "column", align_items = "stretch" })
--todo: "score" element similar to those other two, holds the score data like time, player, place, etc.

state.columns = flex:new({
    scroll:new(state.packs),
    state.levels,
    state.leaderboards,
}, { size_ratios = { 1, 2, 1 } })

state.top_bar = quad:new({
    child_element = flex:new({
        quad:new({
            child_element = icon:new("gear", { style = { padding = 8 } }),
            selectable = true,
            click_handler = function()
                settings:open()
            end,
        }),
        quad:new({
            child_element = icon:new("download", { style = { padding = 8 } }),
            selectable = true,
            click_handler = function()
                pack_overlay:open()
            end,
        }),
    }),
    style = { padding = 0, border_thickness = 0 },
})

state.root = flex:new({
    state.top_bar,
    state.columns,
}, { direction = "column", align_items = "stretch", align_relative_to = "area" })

if #pack_elems > 0 then
    pack_elems[1]:click(false)
end

state.root.state = state

return state.root
