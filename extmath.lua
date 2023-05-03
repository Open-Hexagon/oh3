local extmath = {}

-- The only useful constant from utils.lua
extmath.tau = 2 * math.pi

---sign function
---@param x number
---@return integer
function extmath.sgn(x)
    return x > 0 and 1 or x == 0 and 0 or -1
end

---clamp function
---@param t number
---@param a number
---@param b number
---@return number
function extmath.clamp(t, a, b)
    if t < a then
        return a
    end
    if t > b then
        return b
    end
    return t
end

---Linear interpolation between `a` and `b` with parameter `t`
---@param a number
---@param b number
---@param t number
---@return number
function extmath.lerp(a, b, t)
    return (1 - t) * a + t * b
end

---Inverse linear interpolation between `a` and `b` with parameter value `c`
---@param a number
---@param b number
---@param c number
---@return number
function extmath.inverse_lerp(a, b, c)
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
function extmath.map(t, a, b, c, d)
    return c + ((d - c) / (b - a)) * (t - a)
end

return extmath