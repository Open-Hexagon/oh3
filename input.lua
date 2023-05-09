local Replay = require("replay")

-- wrapper for game inputs to automate replay recording
local input = {
    custom_keybinds = {}
}
local replay
local recording = false
local input_state = {}
local time = 0
local replaying = false

---creates a new replay file to store inputs in
function input.new_replay()
    replay = Replay:new()
end

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

---start replaying a replay object
---@param replay_obj Replay
function input.replay_start(replay_obj)
    input.record_stop()
    replay = replay_obj
    replaying = true
    time = 0
    input_state = {}
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
        local state_changes = replay:get_key_state_changes(time)
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
        if replay == nil then
            error("attempted to record input without active replay")
        end
        if input_state[key] ~= state then
            input_state[key] = state
            replay:record_input(key, state, time)
        end
    end
    return state
end

return input
