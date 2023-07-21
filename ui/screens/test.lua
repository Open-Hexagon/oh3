-- just a test screenX
-- TODO: remove once we start working on new screens
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
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
})
