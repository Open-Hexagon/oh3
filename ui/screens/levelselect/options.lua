local quad = require("ui.elements.quad")
local label = require("ui.elements.label")
local flex = require("ui.layout.flex")
local make_localscore_element = require("ui.screens.levelselect.score")

return function(state, pack, level)
    local selections = {}
    local selections_index = 1
    --this has a weird forumla because: the last diff is always 1, but it should be the first diff.
    selections[1] = level.options.difficulty_mult[#level.options.difficulty_mult]
    for i = 1, #level.options.difficulty_mult - 1 do
        selections[i + 1] = level.options.difficulty_mult[i]
    end
    --this is for the level selection presets! the proper level settings need their own button and menu (see prototype)
    local selection_element = quad:new({
        child_element = label:new(
            selections[selections_index],
            { font_size = 30, style = { color = { 0, 0, 0, 1 } }, wrap = true }
        ),
        style = { background_color = { 1, 1, 1, 1 }, border_color = { 0, 0, 0, 1 }, border_thickness = 5 },
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.border_color = { 0, 0, 1, 1 }
            else
                self.border_color = { 0, 0, 0, 1 }
            end
        end,
        click_handler = function(self)
            selections_index = (selections_index % #selections) + 1
            local selections_element = label:new(
                selections[selections_index],
                { font_size = 30, style = { color = { 0, 0, 0, 1 }, padding = 8 }, wrap = true }
            )
            self.background_color = { 1, 1, 0, 1 }
            self.element = selections_element -- later mutated call on root will handle this
            state.level_options_selected = { difficulty_mult = selections[selections_index] }
            local score = flex:new({
                make_localscore_element(pack.id, level.id, state.level_options_selected),
            }, { direction = "column", align_items = "stretch" })
            state.leaderboards.elements[1] = score
            state.leaderboards:mutated()
        end,
    })
    return flex:new({
        selection_element,
    }, { direction = "column", align_items = "stretch" })
end
