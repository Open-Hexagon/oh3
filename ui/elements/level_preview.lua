local element = require("ui.elements.element")
local game_handler = require("game_handler")
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
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.translate(canvas:getWidth() / 2, canvas:getHeight() / 2)
    love.graphics.scale(GAME_SCALE, GAME_SCALE)
    game_handler.draw_preview(canvas, self.game_version, self.pack, self.level)
    love.graphics.setCanvas()
    self.image = love.graphics.newImage(canvas:newImageData())
end

function level_preview:new(game_version, pack, level, options)
    local obj = element.new(
        setmetatable({
            game_version = game_version,
            pack = pack,
            level = level,
            last_scale = 1,
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
    love.graphics.draw(
        self.image,
        self.bounds[1] + self.padding * self.scale,
        self.bounds[2] + self.padding * self.scale
    )
end

return level_preview
