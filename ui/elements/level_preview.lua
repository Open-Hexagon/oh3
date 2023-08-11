local element = require("ui.elements.element")
local game_handler = require("game_handler")
local signal = require("ui.anim.signal")
local level_preview = {}
level_preview.__index = setmetatable(level_preview, {
    __index = element,
})
local SIZE = 96
local GAME_SCALE = 3
local canvas = love.graphics.newCanvas(SIZE, SIZE, { msaa = 4 })
-- TODO: make msaa configurable

local function set_canvas_scale(scale)
    local size = math.floor(scale * SIZE + 0.5)
    if canvas:getWidth() ~= size then
        canvas = love.graphics.newCanvas(size, size, { msaa = 4 })
    end
end

local function redraw(self)
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 1)
    local half_size = canvas:getWidth() / 2
    love.graphics.translate(half_size, half_size)
    love.graphics.scale(GAME_SCALE, GAME_SCALE)
    love.graphics.setColor(1, 1, 1, 1)
    local promise = game_handler.draw_preview(canvas, self.game_version, self.pack, self.level)
    love.graphics.setCanvas()
    if promise then
        -- styles not loaded yet
        promise:done(function()
            -- redraw once styles are loaded
            redraw(self)
        end)
        return
    end
    self.image = love.graphics.newImage(canvas:newImageData())
end

function level_preview:new(game_version, pack, level, options)
    local obj = element.new(
        setmetatable({
            game_version = game_version,
            pack = pack,
            level = level,
            last_scale = 1,
            angle = signal.new_waveform(1, function(x)
                return x * 2 * math.pi
            end),
        }, level_preview),
        options
    )
    redraw(obj)
    return obj
end

function level_preview:calculate_element_layout()
    -- * 2 as there should be padding on both sides
    local padding = self.padding * 2 * self.scale
    return SIZE * self.scale + padding, SIZE * self.scale + padding
end

function level_preview:draw()
    if self.last_scale ~= self.scale then
        set_canvas_scale(self.scale)
        redraw(self)
    end
    self.last_scale = self.scale
    local pos_x, pos_y = self.bounds[1] + self.padding * self.scale, self.bounds[2] + self.padding * self.scale
    if self.image then
        love.graphics.draw(
            self.image,
            self.bounds[1] + self.padding * self.scale,
            self.bounds[2] + self.padding * self.scale
        )
    else
        -- loading circle (TODO: replace hardcoded colors and line width maybe)
        local half_size = SIZE * self.scale / 2
        local center_x, center_y = pos_x + half_size, pos_y + half_size
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(self.scale * 5)
        love.graphics.circle("line", center_x, center_y, half_size / 2, 100)
        love.graphics.setColor(0, 0, 0, 1)
        local half_sector_size = math.pi / 4
        local radius = half_size
        love.graphics.polygon(
            "fill",
            center_x, center_y,
            center_x + math.cos(self.angle() - half_sector_size) * radius, center_y + math.sin(self.angle() - half_sector_size) * radius,
            center_x + math.cos(self.angle() + half_sector_size) * radius, center_y + math.sin(self.angle() + half_sector_size) * radius
        )
    end
end

return level_preview
