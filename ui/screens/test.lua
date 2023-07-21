-- just a test screenX
-- TODO: remove once we start working on new screens
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
return flex:new({
    flex:new({
        label:new("Hello"),
        label:new("World"),
        label:new("This is some incredibly, unimaginably, unfathomably long wrapping text!!!!!!!!!!", { wrap = true }),
    }, { direction = "column" }),
    flex:new({
        label:new("Some"),
        label:new("Other"),
        label:new("Stuff"),
        label:new("With 5 and not 3 elements this time!", { wrap = true }),
        label:new("!!!!"),
    }, { direction = "column", style = { color = { 1, 0, 1, 1 } } }),
    flex:new({
        label:new("Look at that:"),
        quad:new({
            child_element = label:new("I'm in a quad!"),
            style = { background_color = { 0.5, 0, 0, 1 } },
        }),
        quad:new({
            child_element = label:new("I even have vertex offsets!"),
            style = { background_color = { 0.3, 0, 0.3, 1 } },
            vertex_offsets = { 30, 0, 5, 20, 0, 10, 0, 0 },
        }),
        quad:new({
            child_element = label:new("I have a thick border!"),
            style = { background_color = { 0.3, 0.4, 0.3, 1 }, border_thickness = 10 },
        }),
    }, { direction = "column", style = { border_thickness = 2 } }),
})
