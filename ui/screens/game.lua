local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local game_handler = require("game_handler")

local timer = quad:new({
    child_element = label:new("", { font_size = 64 }),
    style = { padding = 0, border_thickness = 0 },
    vertex_offsets = { 0, 0, 40, 0, 0, 0, 0, 0 },
})

game_handler.onupdate = function()
    local score = game_handler.get_score()
    score = math.floor(score * 1000) / 1000
    local score_str = tostring(score)
    if score_str:match("%.") then
        -- find the amount of decimal digits
        local pos = score_str:find("%.")
        local places = #(score_str:sub(pos + 1))
        while places < 3 do
            places = places + 1
            score_str = score_str .. "0"
        end
    else
        -- no decimal digits, append .000
        score_str = score_str .. ".000"
    end
    timer.element.raw_text = score_str
    timer:calculate_layout()
end

return timer
