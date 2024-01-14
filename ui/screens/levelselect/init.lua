local flex = require("ui.layout.flex")
local icon = require("ui.elements.icon")
local quad = require("ui.elements.quad")
local hexagon = require("ui.elements.hexagon")
local scroll = require("ui.layout.scroll")
local settings = require("ui.overlay.settings")
local pack_overlay = require("ui.overlay.packs")
local pack_elements = require("ui.screens.levelselect.packs")
local score = require("ui.screens.levelselect.score")
local options = require("ui.screens.levelselect.options")

local state = {}

local pack_elems = pack_elements.init(state)

state.packs = flex:new(pack_elems, { direction = "column", align_items = "stretch", align_relative_to = "area" })

state.levels = scroll:new(flex:new({}, { direction = "column", align_items = "center" }))


local packs = quad:new({
    child_element = scroll:new(state.packs),
})
packs.padding = 0

state.columns = flex:new({
    packs,
    state.levels,
    quad:new({
        child_element = flex:new({
            score.layout,
            options.layout,
        }, { direction = "column", align_items = "stretch", align_relative_to = "area" }),
    }),
}, { size_ratios = { 1, 2, 1 } })

state.top_bar = quad:new({
    child_element = flex:new({
        hexagon:new({
            child_element = icon:new("gear"),
            selectable = true,
            click_handler = function()
                settings:open()
            end,
        }),
        hexagon:new({
            child_element = icon:new("download"),
            selectable = true,
            click_handler = function()
                pack_overlay:open()
            end,
        }),
    }),
})
state.top_bar.padding = 0

state.root = flex:new({
    state.top_bar,
    state.columns,
}, { direction = "column", align_items = "stretch", align_relative_to = "area" })

if #pack_elems > 0 then
    pack_elems[1]:click(false)
end

state.root.state = state

return state.root
