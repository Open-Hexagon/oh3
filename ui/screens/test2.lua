-- just another test screen
-- TODO: remove once we start working on new screens
local flex = require("ui.layout.flex")
local slider = require("ui.elements.slider")
local label = require("ui.elements.label")

-- reproduce flex wrap label sizing issue (fixed now)
return flex:new({
    flex:new({
        slider:new(),
        flex:new({
            label:new(
                "HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!! HELLO WORLD!!!",
                { wrap = true }
            ),
        }, { direction = "column" }),
        slider:new(),
    }),
}, { direction = "column", scrollable = true })
