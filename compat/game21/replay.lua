local bit = require("bit")

local replay = {}

---read the old replay format and convert the data which is then put into the passed replay object
---@param replay_obj Replay
---@param data string
---@param offset number
function replay.read(replay_obj, data, offset)
    replay_obj.game_version = 21
    replay_obj.data.keys = { "left", "right", "space", "lshift" }
    replay_obj.data.config = {
        key_left = "left",
        key_right = "right",
        key_swap = "space",
        key_focus = "lshift",
    }
    -- the old format is platform specific, so let's make some assumptions to make it more consistent:
    -- sizeof(size_t) = 8
    -- sizeof(unsigned long long) = 8
    local function read_str()
        local len, str
        len, offset = love.data.unpack("<I4", data, offset)
        str, offset = love.data.unpack("<c" .. len, data, offset)
        return str
    end
    local function read_uint64()
        local part1, part2
        part1, offset = love.data.unpack("<I4", data, offset)
        part2, offset = love.data.unpack("<I4", data, offset)
        return bit.lshift(part2 * 1ULL, 32) + part1 * 1ULL
    end
    replay_obj.player_name = read_str()
    local seed = read_uint64()
    -- even if not correct, the first seed is only used for music segment (which was random in replays from this version)
    replay_obj.data.seeds[1] = tonumber(seed)
    replay_obj.data.seeds[2] = seed
    local input_len
    -- may cause issues with replays longer than ~9000 years
    input_len = tonumber(read_uint64())
    local state = { 0, 0, 0, 0 }
    local last_tick = 0
    for tick = 1, input_len do
        last_tick = tick
        local input_bitmask
        input_bitmask, offset = love.data.unpack("<B", data, offset)
        local changed = {}
        for input = 1, 4 do
            local key_state = bit.band(bit.rshift(input_bitmask, input - 1), 1)
            if state[input] ~= key_state then
                state[input] = key_state
                changed[#changed + 1] = input
                changed[#changed + 1] = key_state == 1
            end
        end
        if #changed ~= 0 then
            replay_obj.data.input_times[#replay_obj.data.input_times + 1] = tick
            replay_obj.input_data[tick] = changed
        end
    end
    local need_change = {}
    for i = 1, 4 do
        if state[i] == 1 then
            need_change[#need_change + 1] = i
            need_change[#need_change + 1] = false
        end
    end
    if #need_change ~= 0 then
        replay_obj.input_data[last_tick + 1] = need_change
    end
    replay_obj.pack_id = read_str()
    replay_obj.level_id = read_str()
    -- no need to prefix level id with pack id
    replay_obj.level_id = replay_obj.level_id:sub(#replay_obj.pack_id + 2)

    replay_obj.first_play, offset = love.data.unpack("<B", data, offset)
    replay_obj.first_play = replay_obj.first_play == 1
    local dm
    -- TODO: check if this works on all platforms (float and double are native size)
    dm, offset = love.data.unpack("<f", data, offset)
    replay_obj.data.level_settings = { difficulty_mult = dm }
    replay_obj.score = love.data.unpack("<d", data, offset) / 60
end

return replay
