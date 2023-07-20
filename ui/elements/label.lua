local label = {}
label.__index = label
local default_font_size = 32
local default_font_file = "assets/font/OpenSquare-Regular.ttf"
local cached_fonts = {}
cached_fonts[default_font_size] = love.graphics.newFont(default_font_file, default_font_size)

---create a new label
---@param text string
---@param options table
---@return table
function label:new(text, options)
    options = options or {}
    local font_size = options.font_size or default_font_size
    if not cached_fonts[font_size] then
        cached_fonts[font_size] = love.graphics.newFont(default_font_file, font_size)
    end
    return setmetatable({
        raw_text = text,
        text = love.graphics.newText(cached_fonts[font_size], text),
        wrap = options.wrap or false,
        font = cached_fonts[font_size],
        font_size = font_size,
        padding = options.padding or 8,
        scale = 1,
        pos = { 0, 0 },
    }, label)
end

---set the gui scale for the label
---@param scale number
function label:set_scale(scale)
    local font_size = math.floor(self.font_size * scale)
    if not cached_fonts[font_size] then
        cached_fonts[font_size] = love.graphics.newFont(default_font_file, font_size)
    end
    self.font = cached_fonts[font_size]
    self.text:setFont(self.font)
    self.scale = scale
end

---recalculate position and size depending on available area for the label, returns width and height
---@param available_area table
---@return number
---@return number
function label:calculate_layout(available_area)
    -- * 2 as there should be padding on both sides
    local padding = self.padding * 2 * self.scale
    local width, height
    local function get_dimensions()
        width, height = self.text:getDimensions()
        width = width + padding
        height = height + padding
    end
    get_dimensions()
    if self.wrap and available_area.width < width then
        self.text:setf(self.raw_text, available_area.width - padding)
        get_dimensions()
    end
    self.pos[1] = available_area.x + self.padding * self.scale
    self.pos[2] = available_area.y + self.padding * self.scale
    return width, height
end

---draw the label
function label:draw()
    love.graphics.draw(self.text, unpack(self.pos))
end

return label
