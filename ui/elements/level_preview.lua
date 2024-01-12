local element = require("ui.elements.element")
local game_handler = require("game_handler")
local signal = require("ui.anim.signal")
local level_preview = {}
level_preview.__index = setmetatable(level_preview, {
    __index = element,
})
local SIZE = 96

function level_preview:new(game_version, pack, level, options)
    local obj = element.new(
        setmetatable({
            game_version = game_version,
            pack = pack,
            level = level,
            angle = signal.new_waveform(1, function(x)
                return x * 2 * math.pi
            end),
        }, level_preview),
        options
    )
    local promise = game_handler.get_preview_data(game_version, pack, level)
    if promise then
        promise:done(function(data)
            obj.data = data
        end)
    end
    return obj
end

function level_preview:set_style(style)
    self.border_thickness = self.style.border_thickness or style.border_thickness or self.border_thickness
    self.border_color = self.style.border_color or style.border_color or self.border_color
    element.set_style(self, style)
end

function level_preview:calculate_element_layout()
    return SIZE * self.scale, SIZE * self.scale
end

function level_preview:draw_element()
    local half_size = SIZE * self.scale / 2
    if self.data then
        love.graphics.translate(half_size, half_size)
        love.graphics.scale(self.scale, self.scale)
        self.vertices = self.vertices or {}
        local distance = 48
        local pivot_thickness = 2
        for i = 1, self.data.sides do
            local angle1 = i * 2 * math.pi / self.data.sides - math.pi / 2
            local cos1 = math.cos(angle1)
            local sin1 = math.sin(angle1)
            local angle2 = angle1 + 2 * math.pi / self.data.sides
            local cos2 = math.cos(angle2)
            local sin2 = math.sin(angle2)
            -- background
            love.graphics.setColor(self.data.background_colors[i])
            love.graphics.polygon("fill", 0, 0, cos1 * distance, sin1 * distance, cos2 * distance, sin2 * distance)
            self.vertices[(i - 1) * 2 + 1] = cos1 * distance
            self.vertices[i * 2] = sin1 * distance
        end
        -- pivot
        love.graphics.setColor(self.data.pivot_color)
        local pivot_mult = 1 / 3 + 1 / distance
        love.graphics.scale(pivot_mult, pivot_mult)
        love.graphics.setLineWidth(pivot_thickness / pivot_mult)
        love.graphics.polygon("line", self.vertices)
        love.graphics.scale(1 / pivot_mult, 1 / pivot_mult)
        -- cap
        local cap_mult = 1 / 3
        love.graphics.scale(cap_mult, cap_mult)
        love.graphics.setColor(self.data.cap_color)
        love.graphics.polygon("fill", self.vertices)
        love.graphics.scale(1 / cap_mult, 1 / cap_mult)
        -- border
        love.graphics.setColor(self.border_color)
        love.graphics.setLineWidth(self.border_thickness)
        love.graphics.polygon("line", self.vertices)
    else
        -- loading circle (TODO: replace hardcoded colors and line width maybe)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(self.scale * 5)
        love.graphics.circle("line", half_size, half_size, half_size / 2, 100)
        local half_sector_size = math.pi / 4
        local radius = half_size
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.polygon(
            "fill",
            half_size,
            half_size,
            half_size + math.cos(self.angle() - half_sector_size) * radius,
            half_size + math.sin(self.angle() - half_sector_size) * radius,
            half_size + math.cos(self.angle() + half_sector_size) * radius,
            half_size + math.sin(self.angle() + half_sector_size) * radius
        )
    end
end

return level_preview
