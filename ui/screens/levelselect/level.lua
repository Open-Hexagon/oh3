local level_preview = require("ui.elements.level_preview")
local game_handler = require("game_handler")
local config = require("config")
local async = require("async")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local make_options_element = require("ui.screens.levelselect.options")
local make_localscore_element = require("ui.screens.levelselect.score")

local pending_promise
local last_pack, last_level
local set_preview_level = async(function(pack, level)
    last_pack = pack
    last_level = level
    if config.get("background_preview") then
        if pending_promise then
            async.await(pending_promise)
            pending_promise = nil
        end
        game_handler.set_version(pack.game_version)
        pending_promise = game_handler.preview_start(pack.id, level.id, {})
    end
end)

local start_game = async(function(pack, level, state)
    local ui = require("ui")
    ui.open_screen("loading")
    if pending_promise then
        async.await(pending_promise)
    end
    game_handler.set_version(pack.game_version)
    async.await(game_handler.record_start(pack.id, level.id, state.level_options_selected))
    ui.open_screen("game")
end)

local level_element_selected

local t = {}

function t.resume_preview()
    if last_pack and last_level then
        set_preview_level(last_pack, last_level)
    end
end

function t.create(state, pack, level, extra_info)
    extra_info = extra_info or {}
    extra_info.song = extra_info.song or "no song"
    extra_info.composer = extra_info.composer or "no composer"
    local music = extra_info.song .. "\n" .. extra_info.composer
    local preview = level_preview:new(
        pack.game_version,
        pack.id,
        level.id,
        { style = { padding = 4, border_color = { 1, 1, 1, 1 }, border_thickness = 2 } }
    )
    return quad:new({
        child_element = flex:new({
            preview,
            flex:new({
                label:new(level.name, { font_size = 40, wrap = true, style = { padding = 5 } }),
                label:new(level.author, { font_size = 26, wrap = true, style = { padding = 5 } }),
                label:new(level.description, { font_size = 16, wrap = true }),
            }, { direction = "column" }),
            --flex:new({label:new(music, { font_size = 30, wrap = true })}, { align_items = "end", direction = "column" }),
        }, { direction = "row" }),
        style = { background_color = { 0, 0, 0, 0.7 }, border_color = { 0, 0, 0, 0.7 }, border_thickness = 5 },
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.style.border_color = { 0, 0, 1, 0.7 }
            else
                self.style.border_color = { 0, 0, 0, 0.7 }
            end
            self:set_style(self.style)
        end,
        click_handler = function(self)
            if level_element_selected ~= self then
                local elems = self.parent.elements
                for i = 1, #elems do
                    elems[i].style.background_color = { 0, 0, 0, 0.7 }
                end
                self.style.background_color = { 0.5, 0.5, 0, 0.7 }
                local score = flex:new({
                    make_localscore_element(pack.id, level.id, { difficulty_mult = 1 }),
                    make_options_element(state, pack, level),
                }, { direction = "column", align_items = "stretch" })
                state.columns.elements[3] = score
                state.columns:mutated()
                level_element_selected = self
                -- reset options (TODO: make options not be dm specific)
                state.level_options_selected = { difficulty_mult = 1 }
                set_preview_level(pack, level)
            else
                start_game(pack, level, state)
            end
        end,
    })
end

return t
