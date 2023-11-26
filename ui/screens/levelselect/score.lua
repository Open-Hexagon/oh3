local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local profile = require("game_handler.profile")

return function(pack, level, level_options)
    local data = profile.get_scores(pack, level, level_options)
    local score = 0
    for i = 1, #data do
        if data[i].score > score then
            score = data[i].score
        end
    end
    return flex:new({
        quad:new({
            child_element = flex:new({
                label:new("Your Score:", { font_size = 16, wrap = true }),
                label:new(tostring(math.floor(score * 1000) / 1000), { font_size = 60, cutoff_suffix = "..." }),
            }, { direction = "column", align_items = "stretch", align_relative_to = "area" }),
            style = { background_color = { 0, 0, 0, 0.7 }, border_color = { 0, 0, 0, 0.7 }, border_thickness = 5 },
        }),
    }, { direction = "column", align_items = "stretch", align_relative_to = "area" })
end
