local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local game_handler = require("game_handler")
local get_death_overlay = require("ui.overlays.death")
local keyboard_navigation = require("ui.keyboard_navigation")
local overlays = require("ui.overlays")

local timer = quad:new({
    child_element = label:new("", { font_size = 64 }),
    style = { padding = 0, border_thickness = 0 },
    vertex_offsets = { 0, 0, 40, 0, 0, 0, 0, 0 },
})

local death_overlay_index

local function back_to_menu()
    if death_overlay_index then
        keyboard_navigation.set_screen()
        overlays.remove_overlay(death_overlay_index)
        death_overlay_index = nil
    end
    game_handler.stop()
    local ui = require("ui")
    ui.open_screen("levelselect")
end

local function retry()
    game_handler.stop()
    if death_overlay_index then
        keyboard_navigation.set_screen()
        overlays.remove_overlay(death_overlay_index)
        death_overlay_index = nil
    end
    game_handler.retry()
end

local death_overlay = get_death_overlay(back_to_menu, retry)

-- monkey patch layout calculation to add overlay (TODO: make this cleaner)
local old_calculate_layout = timer.calculate_layout
timer.calculate_layout = function(self, available_area)
    death_overlay:calculate_layout({
        x = 0,
        y = 0,
        width = love.graphics.getWidth(),
        height = love.graphics.getHeight(),
    })
    return old_calculate_layout(self, available_area)
end

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
    -- show death screen when dead
    if game_handler.is_dead() then
        if game_handler.is_replaying() then
            -- TODO: show appropriate ui when replay ends (retry/back buttons would be wrong here)
            back_to_menu()
        elseif keyboard_navigation.get_screen() ~= death_overlay then
            death_overlay_index = overlays.add_overlay(death_overlay)
            keyboard_navigation.set_screen(death_overlay)
        end
    end
end

return timer
