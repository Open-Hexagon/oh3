-- just a test screenX
-- TODO: remove once we start working on new screens
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
return flex:new({
    label:new("Hello"),
    label:new("World"),
    label:new("This is some incredibly, unimaginably, unfathomably long wrapping text!!!!!!!!!!", { wrap = true }),
})
