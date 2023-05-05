local extmath = require "extmath"

---@class Signal
---@alias signalparam number|function|table|Signal

local signals = setmetatable({}, { __mode = "k" })

local Waveform = {}
Waveform.__index = Waveform
Waveform.__call = function(this)
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
Lerp.__call = function(this)
    return extmath.lerp(this.a(), this.b(), this.t())
end

local Offset = {}
Offset.__call = function(this)
    return this.a() + this.b()
end


-- Square wave function with period 1 and amplitude 1 at value <x> with duty cycle <d>
local square = function(x, d)
    local _, frac = math.modf(x)
    if x < 0 then
        frac = 1 + frac
    end
    return -extmath.sgn(frac - extmath.clamp(d, 0, 1))
end

-- Asymmetrical triangle wave function with period 1 and amplitude 1 at value <x>
-- Asymmetry can be adjusted with <d>
-- An asymmetry of 1 is equivalent to sawtooth wave
-- An asymmetry of 0 is equivalent to a reversed sawtooth wave
local triangle = function(x, d)
    x = x % 1
    d = extmath.clamp(d, 0, 1)
    local p, x2 = 1 - d, 2 * x
    return (x < 0.5 * d) and (x2 / d) or (0.5 * (1 + p) <= x) and ((x2 - 2) / d) or ((1 - x2) / p)
end

-- Sawtooth wave function with period 1 and amplitude 1 at value x
local sawtooth = function(x)
    return 2 * (x - math.floor(0.5 + x))
end


local M = {}

---Create a new signal.
---If value is a `number`, returns the constant signal of that number.
---If value is already a signal, returns that signal.
---@param value signalparam
---@return Signal|function
function M.new_signal(value)
    if type(value) == "number" then
        return (function()
            return value
        end)
    end

    return value
end

---Creates a new looping signal with frequency `freq` defined by the function `curve`.
---`curve` should accept one argument ranging from [0, 1] and return a number.
---@param freq signalparam
---@param curve function
---@return Signal
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

---Creates a new signal that is the lerp of 3 signals `a`, `b`, and `t`.
---@param a signalparam
---@param b signalparam
---@param t signalparam
---@return Signal
function M.new_lerp(a, b, t)
    local newinst = setmetatable({
        a = M.new_signal(a),
        b = M.new_signal(b),
        t = M.new_signal(t)
    }, Lerp)
    return newinst
end

---Creates a new signal that is the sum of two signals `a` and `b`.
---@param a signalparam
---@param b signalparam
---@return Signal
function M.new_sum(a, b)
    local newinst = setmetatable({
        a = M.new_signal(a),
        b = M.new_signal(b)
    }, Offset)
    return newinst
end

function M.new_event_queue()

end

---Updates all signals
---@param dt number
function M.update(dt)
    for sig, _ in pairs(signals) do
        sig:update(dt)
    end
end

return M
