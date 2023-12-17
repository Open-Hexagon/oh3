local overlay = require("ui.overlay")
local transitions = require("ui.anim.transitions")
local flex = require("ui.layout.flex")

local pack_overlay = overlay:new()
pack_overlay.layout = flex:new({})
pack_overlay.transition = transitions.slide

return pack_overlay
