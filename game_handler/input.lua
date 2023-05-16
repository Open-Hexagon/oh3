-- wrapper for game inputs to automate replay recording
local input = {
    custom_keybinds = {},
    replay = nil,
}
local recording = false
local input_state = {}
local time = 0
local replaying = false
local seed_index = 0
local original = math.randomseed

---starts recording all new inputs
function input.record_start()
    input.replay_stop()
    recording = true
    time = 0
    input_state = {}
    math.randomseed = function(seed)
        input.replay:record_seed(seed)
        original(seed)
    end
end

---stops recording inputs
function input.record_stop()
    recording = false
    math.randomseed = original
end

---start replaying the active replay
function input.replay_start()
    input.record_stop()
    replaying = true
    time = 0
    seed_index = 0
    input_state = {}
    math.randomseed = function()
        seed_index = seed_index + 1
        original(input.replay.data.seeds[seed_index])
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
    end
    if replaying then
        time = time + 1
        local state_changes = input.replay:get_key_state_changes(time)
        if state_changes ~= nil then
            for i = 1, #state_changes, 2 do
                input_state[state_changes[i]] = state_changes[i + 1]
            end
        end
    end
end

---gets the down state of any key
---records changes if recording
---gets input state from replay if replaying
---@param key love.KeyConstant|number use number for mouse buttons
---@return boolean
function input.get(key)
    local key_name
    if input.custom_keybinds[key] ~= nil then
        key_name = input.custom_keybinds[key]
    else
        key_name = key
    end
    if replaying then
        return input_state[key] or false
    end
    local state
    if type(key) == "number" then
        state = love.mouse.isDown(key_name)
    else
        state = love.keyboard.isDown(key_name)
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
