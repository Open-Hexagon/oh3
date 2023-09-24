-- just a test screen
-- TODO: remove once we start working on new screens
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local dropdown = require("ui.elements.dropdown")
local toggle = require("ui.elements.toggle")
local slider = require("ui.elements.slider")
local scroll = require("ui.layout.scroll")
return scroll:new(flex:new({
    flex:new({
        --dropdown:new({ "first", "second", "third", "and last selection!" }),
        label:new("Hello"),
        label:new("World", { selectable = true }),
        label:new("This is some incredibly, unimaginably, unfathomably long wrapping text!!!!!!!!!!", { wrap = true }),
        --[[dropdown:new({
            "this",
            "dropdown",
            "has",
            "many",
            "selections",
            "in",
            "order",
            "to",
            "test",
            "the",
            "scroll",
            "try some longer text as well",
            "maybe something weird will happen if it gets too long",
            "otherwise",
            "i really hope",
            "i have",
            "enough",
            "entries",
            "to try",
            "scrolling",
            "now",
        }),]]
        flex:new({
            label:new("You can toggle this one:"),
            toggle:new(),
        }),
        slider:new(),
    }, { direction = "column" }),
    flex:new({
        label:new("Some", { selectable = true }),
        label:new("Other", { selectable = true }),
        label:new("Stuff", { selectable = true }),
        label:new("With 5 and not 4 elements this time!", { wrap = true }),
        label:new("This column also has more padding"),
    }, { direction = "column", style = { color = { 1, 0, 1, 1 }, padding = 20 }, align_items = "center" }),
    scroll:new(flex:new({
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
            selectable = true,
            selection_handler = function(self)
                if self.selected then
                    self.border_color = { 0, 0, 1, 1 }
                else
                    self.border_color = { 1, 1, 1, 1 }
                end
            end,
        }),
        label:new(
            "This label is taking up a ton of space by spamming random characters: wezncr45ft5vbwa305ucntrwsczn6o9w3v8ed47chntefgv5t5xgncwxa795mrgc98wapxmrzfew894tgf98wa3p4zmgt89wzxrmf89syehrfx8wsycowyhxtogfhw39xstrfmwa30hrf,8x9w0atm09axu0w4e,trfß0yüxut50u,x5rtwaxmtgahzcw4rthxn97wrm9wct5e4t9gnwyecrtwe489ctgh89waxtwstcgmw9tnwz98xws9gvnt9wxr89qayznrhfmwyhxrfsyhnevrsylhnxri9syhncrywhxn89fsyhexrftm9yl9mwa3h98rx5aw89fmhwaez89taxn8w90xrzhwa89xmzwa89xzra8x5m89ctwaztx5rdwpa9mwezncr45ft5vbwa305ucntrwsczn6o9w3v8ed47chntefgv5t5xgncwxa795mrgc98wapxmrzfew894tgf98wa3p4zmgt89wzxrmf89syehrfx8wsycowyhxtogfhw39xstrfmwa30hrf,8x9w0atm09axu0w4e,trfß0yüxut50u,x5rtwaxmtgahzcw4rthxn97wrm9wct5e4t9gnwyecrtwe489ctgh89waxtwstcgmw9tnwz98xws9gvnt9wxr89qayznrhfmwyhxrfsyhnevrsylhnxri9syhncrywhxn89fsyhexrftm9yl9mwa3h98rx5aw89fmhwaez89taxn8w90xrzhwa89xmzwa89xzra8x5m89ctwaztx5rdwpa9m",
            { wrap = true }
        ),
        quad:new({
            child_element = flex:new({
                label:new("Hello", { selectable = true }),
                label:new("World", { selectable = true }),
            }),
        }),
    }, {
        direction = "column",
        style = { border_thickness = 2, background_color = { 0, 0, 0, 1 } },
    })),
}, { size_ratios = { 1, 1, 1 } }))
