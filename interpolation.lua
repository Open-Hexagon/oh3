local int = {}

---Linear interpolation between `a` and `b` with parameter `t`
---@param a number
---@param b number
---@param t number
---@return number
function int.lerp(a, b, t)
    return (1 - t) * a + t * b
end

---Inverse linear interpolation between `a` and `b` with parameter value `c`
---@param a number
---@param b number
---@param c number
---@return number
function int.inverse_lerp(a, b, c)
    return (c - a) / (b - a)
end

---Takes a value `t` between `a` and `b` and proportionally maps it to a value between `c` and `d`
---`a` != `b`
---@param t number
---@param a number
---@param b number
---@param c number
---@param d number
---@return number
function int.map(t, a, b, c, d)
    return c + ((d - c) / (b - a)) * (t - a)
end

return int