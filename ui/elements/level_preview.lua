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
        for i = 1, #self.data.polygons do
            love.graphics.setColor(self.data.colors[i])
            love.graphics.polygon("fill", self.data.polygons[i])
        end
        love.graphics.setColor(self.border_color)
        love.graphics.setLineWidth(self.scale * self.border_thickness)
        love.graphics.polygon("line", self.data.outline)
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
