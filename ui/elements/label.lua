local element = require("ui.elements.element")
local label = {}
label.__index = setmetatable(label, {
    __index = element,
})
local default_font_size = 32
local default_font_file = "assets/font/OpenSquare-Regular.ttf"
local cached_fonts = {}
cached_fonts[default_font_file] = {}
cached_fonts[default_font_file][default_font_size] = love.graphics.newFont(default_font_file, default_font_size)

---create a new label
---@param text string
---@param options table?
---@return table
function label:new(text, options)
    options = options or {}
    local font = cached_fonts[default_font_file]
    if options.font_file then
        if not cached_fonts[options.font_file] then
            cached_fonts[options.font_file] = {}
        end
        font = cached_fonts[options.font_file]
    end
    local font_size = options.font_size or default_font_size
    if not font[font_size] then
        font[font_size] = love.graphics.newFont(options.font_file or default_font_file, font_size)
    end
    return element.new(
        setmetatable({
            raw_text = text,
            text = love.graphics.newText(font[font_size], text),
            wrap = options.wrap or false,
            font = font,
            font_file = options.font_file or default_font_file,
            font_size = font_size,
            pos = { 0, 0 },
        }, label),
        options
    )
end

---set the gui scale for the label
---@param scale number
function label:set_scale(scale)
    local font_size = math.floor(self.font_size * scale)
    if not self.font[font_size] then
        self.font[font_size] = love.graphics.newFont(self.font_file, font_size)
    end
    self.text:setFont(self.font[font_size])
    self.scale = scale
end

---recalculate position and size depending on available area for the label, returns width and height
---@param available_area table
---@return number
---@return number
function label:calculate_element_layout(available_area)
    -- * 2 as there should be padding on both sides
    local padding = self.padding * 2 * self.scale
    local width, height
    local function get_dimensions()
        width, height = self.text:getDimensions()
        width = width + padding
        height = height + padding
    end
    self.text:set(self.raw_text)
    get_dimensions()
    if self.wrap and available_area.width < width then
        self.text:setf(self.raw_text, available_area.width - padding, "left")
        get_dimensions()
    end
    self.pos[1] = available_area.x + self.padding * self.scale
    self.pos[2] = available_area.y + self.padding * self.scale
    return width, height
end

---draw the label
function label:draw()
    -- TODO: replace temporary visual selection state
    if self.selected then
        love.graphics.setColor(0, 0, 1, 1)
    else
        love.graphics.setColor(self.color)
    end
    love.graphics.draw(self.text, unpack(self.pos))
end

return label
