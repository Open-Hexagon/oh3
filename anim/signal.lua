local extmath = require "extmath"
local signals = setmetatable({}, {__mode = "k"})

local Waveform = {}
Waveform.__index = Waveform
Waveform.__call = function (this)
    return this.value
end


function Waveform:update(dt)
    if self.suspended then
        return
    end
    self.t = self.t + self.freq() * dt
    if self.t > 1 then
        self.t = self.t - 1
    end
    self.value = self.curve(self.t)
end

function Waveform:suspend()
    self.suspended = true
end

function Waveform:resume()
    self.suspended = false
end

local Lerp = {}
Lerp.__call = function (this)
    return extmath.lerp(this.a(), this.b(), this.t())
end

local Offset = {}
Offset.__call = function (this)
    return this.a() + this.b()
end


-- Square wave function with period 1 and amplitude 1 at value <x> with duty cycle <d>
local square = function (x, d)
    return -extmath.sgn(x % 1 - extmath.clamp(d, 0, 1))
end

-- Asymmetrical triangle wave function with period 1 and amplitude 1 at value <x>
-- Asymmetry can be adjusted with <d>
-- An asymmetry of 1 is equivalent to sawtooth wave
-- An asymmetry of 0 is equivalent to a reversed sawtooth wave
local triangle = function (x, d)
    x = x % 1
    d = extmath.clamp(d, 0, 1)
    local p, x2 = 1 - d, 2 * x
    return (x < 0.5 * d) and (x2 / d) or (0.5 * (1 + p) <= x) and ((x2 - 2) / d) or ((1 - x2) / p)
end

-- Sawtooth wave function with period 1 and amplitude 1 at value x
local sawtooth = function (x)
    return 2 * (x - math.floor(0.5 + x))
end


local M = {}

function M.new_signal(value)
    if type(value) == "number" then
        -- Create a new constant signal
        return function ()
            return value
        end
    end
    -- Value is already a signal
    return value
end

function M.new_waveform(freq, curve)
    local newinst = setmetatable({
        t = 0,
        freq = M.new_signal(freq),
        curve = curve,
        suspended = false
    }, Waveform)
    signals[newinst] = true
    newinst:update(0)
    return newinst
end

function M.new_lerp(a, b, t)
    local newinst = setmetatable({
        a = M.new_signal(a),
        b = M.new_signal(b),
        t = M.new_signal(t)
    }, Lerp)
    return newinst
end

function M.new_offset(a, b)
    local newinst = setmetatable({
        a = M.new_signal(a),
        b = M.new_signal(b)
    }, Offset)
    return newinst
end

function M.update(dt)
    for sig, _ in pairs(signals) do
        sig:update(dt)
    end
end

return M