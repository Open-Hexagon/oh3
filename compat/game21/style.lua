local set_color = require("compat.game21.color_transform")
local get_color_from_hue = require("compat.game21.hue").get_color
local style = {}
style.__index = style

local function set_color_data_defaults(data)
    data.main = data.main or false
    data.dynamic = data.dynamic or false
    data.dynamic_offset = data.dynamic_offset or false
    data.dynamic_darkness = data.dynamic_darkness or 1
    data.hue_shift = data.hue_shift or 0
    data.offset = data.offset or 0
    data.color = data.value or { 0, 0, 0, 255 }
    data.pulse = data.pulse or { 0, 0, 0, 255 }
    data.result = { 0, 0, 0, 0 }

    -- removes a runtime check
    if data.dynamic and not data.dynamic_offset and data.dynamic_darkness == 0 then
        data.main = true
    end
end

local function parse_cap_color(obj)
    if type(obj) == "string" then
        if obj == "main" then
            return 1 -- just use main color
        elseif obj == "main_darkened" then
            return 2 -- use main color but divide rgb by 1.4
        end
    else
        local legacy = obj.legacy
        if legacy == nil then
            legacy = true
        end
        if legacy then
            return 4 -- use the color of the 1st background panel (5 would be 2nd)
        else
            set_color_data_defaults(obj)
            return 3 -- custom color
        end
    end
end

function style:select(style_data)
    self._current_hue = style_data.hue_min or 0
    self._current_swap_time = 0
    self._pulse_factor = 0
    self.id = style_data.id or "nullId"
    self.hue_min = style_data.hue_min or 0
    self.hue_max = style_data.hue_max or 360
    self.hue_increment = style_data.hue_increment or 0
    self.hue_ping_pong = style_data.hue_ping_pong
    self.pulse_min = style_data.pulse_min or 0
    self.pulse_max = style_data.pulse_max or 0
    self.pulse_increment = style_data.pulse_increment or 0
    self.max_swap_time = style_data.max_swap_time or 100
    self._3D_depth = style_data["3D_depth"] or 15
    self._3D_skew = style_data["3D_skew"] or 0.18
    self._3D_spacing = style_data["3D_spacing"] or 1
    self._3D_darken_mult = style_data["3D_darken_multiplier"] or 1.5
    self._3D_alpha_mult = style_data["3D_alpha_multiplier"] or 0.5
    self._3D_alpha_falloff = style_data["3D_alpha_falloff"] or 3
    self._3D_pulse_max = style_data["3D_pulse_max"] or 3.2
    self._3D_pulse_min = style_data["3D_pulse_min"] or 0
    self._3D_pulse_speed = style_data["3D_pulse_speed"] or 0.01
    self._3D_perspective_mult = style_data["3D_perspective_multiplier"] or 1
    self.bg_tile_radius = 10000
    self.bg_color_offset = 0
    self.bg_rot_off = 0
    self._3D_override_color = style_data["3D_override_color"] or { 0, 0, 0, 0 }
    self._current_3D_override_color = { 0, 0, 0, 0 }
    self._main_color_data = style_data.main
    self._player_color_data = style_data.player_color or style_data.main
    self._text_color = style_data.text_color or style_data.main
    self._wall_color = style_data.wall_color or style_data.main
    self._cap_color = parse_cap_color(style_data.cap_color)
    self._cap_color_obj = style_data.cap_color
    self._color_datas = {}
    self._colors = {}
    self._color_start_index = 0
    self._current_hue_color = { 0, 0, 0, 0 }
    set_color_data_defaults(self._main_color_data)
    set_color_data_defaults(self._player_color_data)
    set_color_data_defaults(self._text_color)
    set_color_data_defaults(self._wall_color)
    local colors = style_data.colors
    for i = 1, #colors do
        set_color_data_defaults(colors[i])
        table.insert(self._color_datas, colors[i])
        table.insert(self._colors, colors[i].result)
    end
end

function style:calculate_color(color_data)
    if color_data.dynamic then
        get_color_from_hue(math.fmod(self._current_hue + color_data.hue_shift, 360) / 360, self._current_hue_color)
        if color_data.main then
            for i = 1, 4 do
                color_data.result[i] = self._current_hue_color[i]
            end
        else
            if color_data.dynamic_offset then
                if color_data.offset == 0 then
                    for i = 1, 3 do
                        color_data.result[i] = color_data.value[i]
                    end
                else
                    for i = 1, 3 do
                        color_data.result[i] = color_data.value[i] + self._current_hue_color[i] / color_data.offset
                    end
                    -- hue color alpha is always 255
                    color_data.result[4] = color_data.value[4] + 255
                end
            else
                -- usually wouldn't divide if color_data.dynamic_darkness == 0 but we already checked for that while setting defaults
                for i = 1, 3 do
                    color_data.result[i] = self._current_hue_color[i] / color_data.dynamic_darkness
                end
                -- hue color alpha is always 255
                color_data.result[4] = 255
            end
        end
    end
    for i = 1, 4 do
        local value = color_data.result[i] + color_data.pulse[i] * self._pulse_factor
        if value > 255 then
            value = 255
        elseif value < 0 then
            value = 0
        end
        color_data.result[i] = value
    end
end

function style:update(frametime, mult)
    self._current_swap_time = self._current_swap_time + frametime * mult
    if self._current_swap_time > self.max_swap_time then
        self._current_swap_time = 0
    end
    self._current_hue = self._current_hue + self.hue_increment * frametime * mult
    if self._current_hue < self.hue_min then
        if self.hue_ping_pong then
            self._current_hue = self.hue_min
            self.hue_increment = -self.hue_increment
        else
            self._current_hue = self.hue_max
        end
    elseif self._current_hue > self.hue_max then
        if self.hue_ping_pong then
            self._current_hue = self.hue_max
            self.hue_increment = -self.hue_increment
        else
            self._current_hue = self.hue_min
        end
    end
    self._pulse_factor = self._pulse_factor + self.pulse_increment * frametime
    if self._pulse_factor < self.pulse_min then
        self.pulse_increment = -self.pulse_increment
        self._pulse_factor = self.pulse_min
    elseif self._pulse_factor > self.pulse_max then
        self.pulse_increment = -self.pulse_increment
        self._pulse_factor = self.pulse_max
    end
end

function style:compute_colors()
    self:calculate_color(self._main_color_data)
    self:calculate_color(self._player_color_data)
    self:calculate_color(self._text_color)
    self:calculate_color(self._wall_color)
    if self._3D_override_color[4] == 0 then
        self._current_3D_override_color = self._main_color_data.result
    else
        self._current_3D_override_color = self._3D_override_color
    end
    for i = 1, #self._color_datas do
        self:calculate_color(self._color_datas[i])
    end
    local rotation = 2 * self._current_swap_time / self.max_swap_time
    self._color_start_index = math.floor(rotation + self.bg_color_offset)
end

function style:draw_background(center_pos, sides, darken_uneven_background_chunk, black_and_white)
    if #self._color_datas ~= 0 then
        local sin, cos = math.sin, math.cos
        local div = 2 * math.pi / sides
        local half_div = div * 0.5
        local distance = self.bg_tile_radius
        for i = 0, sides - 1 do
            local angle = math.rad(self.bg_rot_off) + div * i
            local color = self:_get_color(i) or { 0, 0, 0, 1 }
            local must_darken = (i % 2 == 0 and i == sides - 1) and darken_uneven_background_chunk
            if black_and_white then
                for j = 1, 3 do
                    color[j] = 0
                end
                color[4] = 1
            elseif must_darken then
                for j = 1, 3 do
                    color[j] = color[j] / 1.4
                end
            end
            set_color(unpack(color))
            local angle0, angle1 = angle + half_div, angle - half_div
            love.graphics.polygon(
                "fill",
                center_pos[1] + cos(angle0) * distance,
                center_pos[2] + sin(angle0) * distance,
                center_pos[1] + cos(angle1) * distance,
                center_pos[2] + sin(angle1) * distance,
                center_pos[1],
                center_pos[2]
            )
        end
    end
end

function style:_get_color(index)
    return self._colors[(self._color_start_index + index) % #self._colors + 1]
end

function style:set_cap_color(mode)
    self._cap_color = mode
end

function style:get_main_color()
    return unpack(self._main_color_data.result)
end

function style:get_player_color()
    return unpack(self._player_color_data.result)
end

function style:get_text_color()
    return unpack(self._text_color.result)
end

function style:get_wall_color()
    return unpack(self._wall_color.result)
end

function style:get_color(index)
    return unpack(self:_get_color(index) or { 0, 0, 0, 255 })
end

function style:get_current_hue()
    return self._current_hue
end

function style:get_current_swap_time()
    return self._current_swap_time
end

function style:get_3D_override_color()
    return unpack(self._current_3D_override_color)
end

function style:get_cap_color_result()
    if self._cap_color == 1 then
        return self:get_main_color()
    elseif self._cap_color == 2 then
        local r, g, b, a = self:get_main_color()
        return r / 1.4, g / 1.4, b / 1.4, a
    elseif self._cap_color == 3 then
        self:calculate_color(self._cap_color_obj)
        return unpack(self._cap_color_obj.result)
    else
        return self:get_color(self._cap_color - 4)
    end
end

return style
