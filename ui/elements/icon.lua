local label = require("ui.elements.label")
local json = require("extlibs.json.json")

local mapping = json.decode(love.filesystem.read("assets/font/bootstrap-icons.json"))

local icon = {}
icon.__index = setmetatable(icon, {
    __index = label,
})

function icon:new(id, options)
    options = options or {}
    options.font_file = "assets/font/bootstrap-icons.woff2"
    local utf8_encoded_char = love.data.decode("string", "hex", mapping[id])
    return setmetatable(label:new(utf8_encoded_char, options), icon)
end

function icon:set(id)
    self.raw_text = love.data.decode("string", "hex", mapping[id])
    self.changed = true
end

return icon
