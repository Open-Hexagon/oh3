local bit = require("bit")
local mcg_state = 0xcafef00dd15ea5e7ULL
local multiplier = 6364136223846793005ULL
-- only used to keep track of the given seed
local seed = 0
local rng = {}

local function pcg32_fast()
    local x = mcg_state
    local count = bit.rshift(x, 61)
    mcg_state = x * multiplier
    x = bit.bxor(x, bit.rshift(x, 22))
    return bit.rshift(x, 22 + count) % 2 ^ 32
end

function rng.set_seed(value)
    mcg_state = bit.bor(value, 3ULL)
    rng.advance(1)
    seed = value
end

function rng.get_seed()
    return tonumber(seed)
end

function rng.advance(delta)
    -- floor is ok, delta is always positive
    delta = math.floor(delta)
    local acc_mult = 1
    local cur_mult = multiplier
    while delta > 0 do
        if bit.band(delta, 1) == 1 then
            acc_mult = acc_mult * cur_mult
        end
        cur_mult = cur_mult ^ 2
        delta = bit.rshift(delta, 1)
    end
    mcg_state = acc_mult * mcg_state
end

local r = 4294967296
local m = 1
function rng.get_real(a, b)
    local sum = 0
    local tmp = 1
    for _ = 1, m do
        sum = sum + tonumber(pcg32_fast()) * tmp
        tmp = tmp * r
    end
    return sum / tmp * (b - a) + a
end

local function to_int(num)
    return num < 0 and math.ceil(num) or math.floor(num)
end

local rng_max = 4294967295
local rng_range = rng_max
function rng.get_int(a, b)
    a = to_int(a)
    b = to_int(b)
    local range = b - a
    local ret
    if rng_range > range then
        range = range + 1ULL
        local product = pcg32_fast() * range
        local low = product % 2 ^ 32
        if low < range then
            local threshold = -range % range
            while low < threshold do
                product = pcg32_fast() * range
                low = product % 2 ^ 32
            end
        end
        ret = tonumber(bit.rshift(product, 32))
    elseif rng_range < range then
        local tmp = 1
        ret = 0
        while ret > range or ret < tmp do
            tmp = ((rng_range + 1) * pcg32_fast()) % 2 ^ 32
            ret = tmp + pcg32_fast()
        end
    else
        ret = tonumber(pcg32_fast())
    end
    ret = ret + a
    if ret >= 2 ^ 31 then
        ret = ret - 2 ^ 32
    end
    return ret
end

return rng
