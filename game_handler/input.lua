-- wrapper for game inputs to automate replay recording
local input = {
    replay = nil,
}
local recording = false
local input_state = {}
local time = 0
local replaying = false
local seed_index = 0

---starts recording all new inputs
function input.record_start()
    input.replay_stop()
    recording = true
    time = 0
    input_state = {}
end

---stops recording inputs
function input.record_stop()
    recording = false
end

---start replaying the active replay
function input.replay_start()
    input.record_stop()
    replaying = true
    time = 0
    seed_index = 0
    input_state = {}
end

---save the next seed when recording or get the next seed when replaying
---@param seed number
---@return number?
function input.next_seed(seed)
    if recording then
        input.replay:record_seed(seed)
        return seed
    elseif replaying then
        seed_index = seed_index + 1
        return input.replay.data.seeds[seed_index]
    else
        return seed
    end
end

---stops replaying
function input.replay_stop()
    replaying = false
end

---increments the timer for the input timestamps when recording and updates the input state when replaying
function input.update()
    if recording then
        time = time + 1
        input.replay.input_tick_length = time
    end
    if replaying then
        time = time + 1
        for key, state in input.replay:get_key_state_changes(time) do
            input_state[key] = state
        end
    end
end

---gets the down state of any key
---records changes if recording
---gets input state from replay if replaying
---@param key love.KeyConstant|number use number for mouse buttons
---@return boolean
function input.get(key)
    if replaying then
        return input_state[key] or false
    end
    local state
    if type(key) == "number" then
        state = love.mouse.isDown(key)
    else
        state = love.keyboard.isDown(key)
    end
    if recording then
        if input.replay == nil then
            error("attempted to record input without active replay")
        end
        if input_state[key] ~= state then
            input_state[key] = state
            input.replay:record_input(key, state, time)
        end
    end
    return state
end

return input
