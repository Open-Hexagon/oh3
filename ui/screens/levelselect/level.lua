local level_preview = require("ui.elements.level_preview")
local game_handler = require("game_handler")
local config = require("config")
local async = require("async")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local make_options_element = require("ui.screens.levelselect.options")
local make_localscore_element = require("ui.screens.levelselect.score")

local function update_element(self, parent, parent_index, layout)
    self.parent_index = parent_index
    self.parent = parent
    self:set_scale(parent.scale)
    self:calculate_layout(layout.last_available_area)
    return self
end

local function get_rect_bounds(bounds)
    local minmax = { math.huge, math.huge, -math.huge, -math.huge }
    for i = 1, #bounds, 2 do
        minmax[1] = math.min(bounds[i], minmax[1])
        minmax[2] = math.min(bounds[i + 1], minmax[2])
        minmax[3] = math.max(bounds[i], minmax[3])
        minmax[4] = math.max(bounds[i + 1], minmax[4])
    end
    return minmax
end

local pending_promise
local set_preview_level = async(function(pack, level)
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

return function(state, pack, level, extra_info)
    extra_info = extra_info or {}
    extra_info.song = extra_info.song or "no song"
    extra_info.composer = extra_info.composer or "no composer"
    local music = extra_info.song .. "\n" .. extra_info.composer
    local preview = level_preview:new(pack.game_version, pack.id, level.id, { style = { padding = 0, border_color = { 1, 1, 1, 1 }, border_thickness = 2 } })
    local elem = quad:new({
        child_element = flex:new({
            preview,
            flex:new({
                flex:new({
                    label:new(level.name, { font_size = 40, wrap = true }),
                    label:new(level.author, { font_size = 26, wrap = true }),
                }, { direction = "column", style = { padding = 5 } }),
                label:new(level.description, { font_size = 16, wrap = true }),
            }, { direction = "column" }),
            --flex:new({label:new(music, { font_size = 30, wrap = true })}, { align_items = "end", direction = "column" }),
        }, { direction = "row" }),
        style = { background_color = { 0, 0, 0, 0.7 }, border_color = { 0, 0, 0, 0.7 }, border_thickness = 5 },
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.border_color = { 0, 0, 1, 0.7 }
            else
                self.border_color = { 0, 0, 0, 0.7 }
            end
        end,
        click_handler = function(self)
            if level_element_selected ~= self then
                local elems = self.parent.elements
                for i = 1, #elems do
                    description = label:new("", { font_size = 16, wrap = true })
                    elems[i].margins = {0,0}
                    elems[i].border_color = { 0, 0, 0, 0.7 }
                    elems[i].element.elements[2].elements[2] = update_element(description, elems[i].element.elements[2], 2, elems[i].element.elements[2].elements[2])
                end
                description = label:new(level.description, { font_size = 16, wrap = true })
                self.border_color = { 0, 0, 1, 0.7 }
				self.margins = {0,32}
                self.element.elements[2].elements[2] = update_element(description, self.element.elements[2], 2, self.element.elements[2].elements[2])
				
				local width, height = self:calculate_layout(self.last_available_area)
				local visual_height = state.root.elements[2].canvas:getHeight()
				local minmax = get_rect_bounds(self.bounds)
				state.root.elements[2].scroll_target = minmax[4] - height/2 - visual_height/2
				state.root.elements[2].scroll:keyframe(0.2,scroll_target)
				
                state.root.elements[2] = update_element(state.root.elements[2], state.root, 2, state.root.elements[2])
                local score = flex:new({
                    make_localscore_element(pack.id, level.id, { difficulty_mult = 1 }),
                    make_options_element(state, pack, level),
                }, { direction = "column", align_items = "stretch" })
                if level_element_selected then
                    level_element_selected.border_color = { 0, 0, 0, 0.7 }
                end
                state.root.elements[3] = update_element(score, state.root, 3, state.root.elements[3])
                level_element_selected = self
                -- reset options (TODO: make options not be dm specific)
                state.level_options_selected = { difficulty_mult = 1 }
                set_preview_level(pack, level)
            else
                start_game(pack, level, state)
            end
        end,
    })
    return elem
end
