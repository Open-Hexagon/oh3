local extmath = require "extmath"

---@class Signal
---@alias signalparam number|function|table|Signal

local signals = setmetatable({}, { __mode = "k" })

local get_value = function(this)
    return this.value
end

---@class Waveform:Signal
---@field private freq Signal
---@field private curve function
---@field private t number
---@field private value number
---@field private suspended boolean
local Waveform = {}
Waveform.__index = Waveform
Waveform.__call = get_value

---Updates the signal
---@param dt number
function Waveform:update(dt)
    if self.suspended then return end
    self.t = self.t + self.freq() * dt
    if self.t >= 1 then
        self.t = self.t - 1
    end
    self.value = self.curve(self.t)
end

---Suspends updates
function Waveform:suspend()
    self.suspended = true
end

---Resumes updates
function Waveform:resume()
    self.suspended = false
end

---@class Lerp:Signal
---@field private a Signal
---@field private b Signal
---@field private t Signal
local Lerp = {}
Lerp.__index = Lerp
Lerp.__call = get_value

function Lerp:update()
    self.value = extmath.lerp(self.a(), self.b(), self.t())
end

---@class Sum:Signal
---@field private a Signal
---@field private b Signal
local Sum = {}
Sum.__index = Sum
Sum.__call = get_value

function Sum:update()
    self.value = self.a() + self.b()
end

local KEYFRAME_EVENT, WAVEFORM_EVENT, WAIT_EVENT, SET_VALUE_EVENT, CALL_EVENT = 1, 2, 3, 4, 5

---@class Event
---@field type `KEYFRAME_EVENT`|`WAVEFORM_EVENT`|`WAIT_EVENT`|`SET_VALUE_EVENT`|`CALL_EVENT`
---@field next Event?
---@field value number?
---@field fn function?
---@field freq number?

---@class Queue:Signal
---@field private current_event Event
---@field private last_event Event
---@field private value number
---@field private processing `KEYFRAME_EVENT`|`WAVEFORM_EVENT`|`WAIT_EVENT`|nil
---@field private start_value number
local Queue = {}
Queue.__index = Queue
Queue.__call = get_value

---Adds a keyframe event
---@param duration number Event duration
---@param value number Target value
---@param ease function Easing function
function Queue:keyframe(duration, value, ease)
    ---@type Event
    local newevent = {
        type = KEYFRAME_EVENT,
        value = value,
        fn = ease,
        freq = 1 / duration
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

---Adds a waveform event. The value will be set to what `curve` returns for the duration of the event.
---@param duration number Event duration
---@param curve function A function that accepts one argument ranging from [0, 1] and returns a number.
function Queue:waveform(duration, curve)
    ---@type Event
    local newevent = {
        type = WAVEFORM_EVENT,
        fn = curve,
        freq = 1 / duration
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

---Adds a wait event.
---@param duration number
function Queue:wait(duration)
    ---@type Event
    local newevent = {
        type = WAIT_EVENT,
        freq = 1 / duration
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

---Adds an event that instantly sets the value of the signal to `value`
---@param value number
function Queue:set_value(value)
    ---@type Event
    local newevent = {
        type = SET_VALUE_EVENT,
        value = value
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

---Adds a function call event.
---@param fn function
function Queue:call(fn)
    ---@type Event
    local newevent = {
        type = CALL_EVENT,
        fn = fn
    }
    self.last_event.next = newevent
    self.last_event = newevent
end

---Stops the queue and deletes all events. The value remains at its last value.
function Queue:stop()
    self.current_event = self.last_event
end

---Updates the signal.
---@param dt number
function Queue:update(dt)
    if self.suspended then return end
    if self.processing then
        self.t = self.t + self.current_event.next.freq * dt
        if self.t < 1 then
            if self.processing == KEYFRAME_EVENT then
                self.value = extmath.lerp(
                    self.start_value,
                    self.current_event.next.value,
                    self.current_event.next.fn(self.t)
                )
            elseif self.processing == WAVEFORM_EVENT then
                self.value = self.current_event.next.fn(self.t)
            end
            return
        end
        if self.processing == KEYFRAME_EVENT then
            self.value = self.current_event.next.value
        elseif self.processing == WAVEFORM_EVENT then
            self.value = self.current_event.next.fn(1)
        end
        self.current_event = self.current_event.next
    end
    if not self.current_event.next then
        self.t, self.processing = 1, nil
        return
    end
    while self.current_event.next.type == CALL_EVENT or self.current_event.next.type == SET_VALUE_EVENT do
        if self.current_event.next.type == CALL_EVENT then
            self.current_event.next.fn()
        else
            self.value = self.current_event.next.value
        end
        self.current_event = self.current_event.next
        if not self.current_event.next then
            self.t, self.processing = 1, nil
            return
        end
    end
    self.t = self.t - 1
    self.processing = self.current_event.next.type
    if self.processing == KEYFRAME_EVENT then
        self.start_value = self.value
        self.value = extmath.lerp(
            self.start_value,
            self.current_event.next.value,
            self.current_event.next.fn(self.t)
        )
    elseif self.processing == WAVEFORM_EVENT then
        self.value = self.current_event.next.fn(self.t)
    end
end

---Suspends updates
function Queue:suspend()
    self.suspended = true
end

---Resumes updates
function Queue:resume()
    self.suspended = false
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
        return function()
            return value
        end
    end
    return value
end

---Creates a new looping signal with frequency `freq` defined by the function `curve`.
---@param freq signalparam Waveform frequency
---@param curve function A function that accepts one argument ranging from [0, 1] and returns a number.
---@return Signal
function M.new_waveform(freq, curve)
    local newinst = setmetatable({
        t = 0,
        freq = M.new_signal(freq),
        curve = curve,
        suspended = false,
        value = 0
    }, Waveform)
    signals[newinst] = true
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
        t = M.new_signal(t),
        value = 0
    }, Lerp)
    signals[newinst] = true
    return newinst
end

---Creates a new signal that is the sum of two signals `a` and `b`.
---@param a signalparam
---@param b signalparam
---@return Signal
function M.new_sum(a, b)
    local newinst = setmetatable({
        a = M.new_signal(a),
        b = M.new_signal(b),
        value = 0
    }, Sum)
    signals[newinst] = true
    return newinst
end

function M.new_queue()
    local dummy_event = {}
    local newinst = setmetatable({
        t = 1,
        current_event = dummy_event,
        last_event = dummy_event,
        value = 0
    }, Queue)
    signals[newinst] = true
    return newinst
end

---Updates all signals
---@param dt number
function M.update(dt)
    for sig, _ in pairs(signals) do
        sig:update(dt)
    end
end

return M
