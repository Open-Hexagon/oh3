local level_preview = require("ui.elements.level_preview")
local game_handler = require("game_handler")
local config = require("config")
local async = require("async")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local flex = require("ui.layout.flex")
local make_options_element = require("ui.screens.levelselect.options")
local make_localscore_element = require("ui.screens.levelselect.score")
local extmath = require("ui.extmath")

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
    local preview = level_preview:new(
        pack.game_version,
        pack.id,
        level.id,
        { style = { padding = 6, border_color = { 1, 1, 1, 1 }, border_thickness = 3 } }
    )
    return quad:new({
        child_element = flex:new({
            preview,
            flex:new({
                flex:new({
                    label:new(level.name, { font_size = 30, wrap = true }),
                    label:new(level.author, { font_size = 20, wrap = true }),
                }, { direction = "column", style = { padding = 5 } }),
                label:new("", { font_size = 20, wrap = true }),
            }, { direction = "column" }),
            --flex:new({label:new(music, { font_size = 30, wrap = true })}, { align_items = "end", direction = "column" }),
        }, { direction = "row" }),
        style = { background_color = { 0, 0, 0, 0.7 }, border_color = { 0, 0, 0, 0.7 }, border_thickness = 5 },
        selectable = true,
        selection_handler = function(self, keyboard_selected)
            if self.selected then
                self.style.border_color = { 0, 0, 1, 0.7 }
            else
                self.style.border_color = { 0, 0, 0, 0.7 }
            end
			if keyboard_selected and level_element_selected ~= self then self:click(false) end
            self:set_style(self.style)
        end,
        click_handler = function(self)
            if level_element_selected ~= self then
                local elems = self.parent.elements
                for i = 1, #elems do
                    local description = label:new("", { font_size = 20, wrap = true })
                    elems[i].margins = {16,0}
                    elems[i].border_color = { 0, 0, 0, 0.7 }
                    elems[i].element.elements[2].elements[2] = description
					elems[i].element.elements[2].elements[1].elements[1].font_size = 30
					elems[i].element.elements[2].elements[1].elements[2].font_size = 20
                end
                self.border_color = { 0, 0, 1, 0.7 }
				self.margins = {0,36}
				self.element.elements[2].elements[1].elements[1].font_size = 60
				self.element.elements[2].elements[1].elements[2].font_size = 40
                local description = label:new(level.description, { font_size = 20, wrap = true })
                self.element.elements[2].elements[2] = description
				--two things: 1) level select box gets shorter which is sad and 2) this should use a collapse elements :0
                self.parent:mutated()
				
				local x, y = self.transform:transformPoint(self._transform:transformPoint(0, 0))
				local bounds_start = state.root.elements[2].wh2lt(x, y)
				local visual_length = state.root.elements[2].wh2lt(state.root.elements[2].width, state.root.elements[2].height)
				local width, height = self:calculate_layout(self.width,self.height)
				local screen_bounds_start = state.root.elements[2].wh2lt(x, y)
				local screen_bounds_end = state.root.elements[2].wh2lt(x + state.root.elements[2].width, y + state.root.elements[2].height)
				state.root.elements[2].scroll_target = bounds_start + height/2 - visual_length/2
				state.root.elements[2].scroll_target = extmath.clamp(state.root.elements[2].scroll_target, 0, state.root.elements[2].max_scroll)
				state.root.elements[2].scroll_pos:keyframe(0.2,state.root.elements[2].scroll_target)
				
                local score = flex:new({
                    make_localscore_element(pack.id, level.id, { difficulty_mult = 1 }),
                    make_options_element(state, pack, level),
                }, { direction = "column", align_items = "stretch" })
                if level_element_selected then
                    level_element_selected.border_color = { 0, 0, 0, 0.7 }
                end
                state.root.elements[3] = score
                state.root:mutated()
				
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
