local label = require("ui.elements.label")
local json = require("extlibs.json.json")

local bs_mapping = json.decode(love.filesystem.read("assets/font/bootstrap-icons.json"))
local prompt_mapping = json.decode(love.filesystem.read("assets/font/promptfont.json"))

local function map_with_font(id)
    local hex_str = bs_mapping[id]
    if hex_str then
        return hex_str, "assets/font/bootstrap-icons.woff2"
    else
        return prompt_mapping[id], "assets/font/promptfont.ttf"
    end
end

local icon = {}
icon.__index = setmetatable(icon, {
    __index = label,
})

function icon:new(id, options)
    local hex_str, font = map_with_font(id)
    options = options or {}
    if hex_str then
        options.font_file = font
        local utf8_encoded_char = love.data.decode("string", "hex", hex_str)
        return setmetatable(label:new(utf8_encoded_char, options), icon)
    else
        return setmetatable(label:new(id, options), icon)
    end
end

function icon:set(id)
    local hex_str, font = map_with_font(id)
    -- set text
    if hex_str then
        self.font_file = font
        self.raw_text = love.data.decode("string", "hex", hex_str)
    else
        self.font_file = "assets/font/OpenSquare-Regular.ttf"
        self.raw_text = id
    end
    -- reloads font if necessary
    self:set_scale(self.scale)
    self.changed = true
end

return icon
