---@class Element
---@field x Signal
---@field y Signal
---@field width Signal
---@field height Signal
---@field draw function
---@field resize function

local element = {}

---List of all elements that need resizing
---@type Element[]
element.resize_list = setmetatable({}, {__mode = "v"})

function element.resize()
    for _, el in pairs(element.resize_list) do
        el:resize()
    end
end

return element