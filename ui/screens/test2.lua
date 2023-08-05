-- just another test screen
-- TODO: remove once we start working on new screens
local flex = require("ui.layout.flex")
local quad = require("ui.elements.quad")
local function center_horizontally(elem)
    return flex:new({elem}, { direction = "column", align_items = "center" })
end
return flex:new({
    center_horizontally(quad:new()),
    center_horizontally(quad:new()),
    center_horizontally(quad:new()),
}, { size_ratios = { 1, 2, 1 }, align_items = "center" })
