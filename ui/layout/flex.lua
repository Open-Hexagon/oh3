local flex = {}
flex.__index = flex

function flex:new(options, elements)
    return setmetatable({}, flex)
end

return flex
