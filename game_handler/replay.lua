local msgpack = require("extlibs.msgpack.msgpack")
local bit = require("bit")

---@class Replay
---@field data table
---@field input_data table
---@field game_version number
---@field first_play boolean
---@field pack_id string
---@field level_id string
---@field key_index_map table
local replay = {}
replay.__index = replay

---creates or loads a replay if path is given
---@param path string?
---@return Replay
function replay:new(path)
    local obj = setmetatable({
        data = {
            seeds = {},
            keys = {},
            input_times = {},
        },
        input_data = {},
        key_index_map = {},
    }, replay)
    if path ~= nil then
        obj:_read(path)
    end
    return obj
end

---gets the key state changes (not the key state) for a specified tick
---the return value is an iterator over: key, state
---@param time number
---@return function?
function replay:get_key_state_changes(time)
    local state_changes = self.input_data[time]
    if state_changes == nil then
        return function()
            return nil
        end
    end
    local index = -1
    return function()
        index = index + 2
        return self.data.keys[state_changes[index]], state_changes[index + 1]
    end
end

---set the level and the settings the game was started with
---@param game_version number
---@param config table global game settings (containing settings such as black and white mode)
---@param first_play boolean
---@param pack_id string
---@param level_id string
---@param level_settings table level specific settings (e.g. the difficulty mult in 21)
function replay:set_game_data(game_version, config, first_play, pack_id, level_id, level_settings)
    self.game_version = game_version
    self.pack_id = pack_id
    self.level_id = level_id
    self.first_play = first_play
    self.data.config = config
    self.data.level_settings = level_settings
end

---saves an input into the replay file
---@param key love.KeyConstant
---@param state boolean
---@param time number timestamp (in ticks)
function replay:record_input(key, state, time)
    if self.key_index_map[key] == nil then
        local len = #self.data.keys + 1
        self.data.keys[len] = key
        self.key_index_map[key] = len
    end
    self.input_data[time] = self.input_data[time] or {}
    local state_changes = self.input_data[time]
    state_changes[#state_changes + 1] = self.key_index_map[key]
    state_changes[#state_changes + 1] = state
end

---saves the seed a math.randomseed call was given (this way they can be the same when the replay is replayed even if the level is settings its own random seeds)
function replay:record_seed(seed)
    self.data.seeds[#self.data.seeds + 1] = seed
end

function replay:_get_compressed()
    local header = love.data.pack(
        "string",
        ">BBBzz",
        1, -- the old game's format version was 0, so we call this 1 now
        self.game_version,
        self.first_play and 1 or 0,
        self.pack_id,
        self.level_id
    )
    for time, _ in pairs(self.input_data) do
        self.data.input_times[#self.data.input_times + 1] = time
    end
    table.sort(self.data.input_times)
    local data = msgpack.pack(self.data)
    local input_data = ""
    for i = 1, #self.data.input_times do
        local time = self.data.input_times[i]
        local state_changes = self.input_data[time]
        input_data = input_data .. love.data.pack("string", ">B", #state_changes / 2)
        for j = 1, #state_changes, 2 do
            local key, state = state_changes[j], state_changes[j + 1]
            input_data = input_data .. love.data.pack("string", ">BB", key, state and 1 or 0)
        end
    end
    return love.data.compress("data", "zlib", header .. data .. input_data, 9)
end

---gets the hash of the replay and also returns the compressed data as it needs to be computed to get the hash already
---@return string
---@return love.CompressedData?
function replay:get_hash()
    local data = self:_get_compressed()
    return love.data.encode("string", "hex", love.data.hash("sha256", data)), data
end

---saves the replay into a file the data to write can optionally be specified if already gotten
---@param path string
---@param data string|love.CompressedData|nil
function replay:save(path, data)
    local file = love.filesystem.newFile(path)
    file:open("w")
    file:write(data or self:_get_compressed())
    file:close()
end

function replay:_read(path)
    if not love.filesystem.getInfo(path) then
        error("Could not find replay at '" .. path .. "'")
    end
    local file = love.filesystem.newFile(path)
    file:open("r")
    local data = love.data.decompress("string", "zlib", file:read("data"))
    file:close()
    local version, offset = love.data.unpack(">I4", data)
    if version == 0 then
        -- old replay format
        self.game_version = 21
        self.data.keys = { "left", "right", "space", "lshift" }
        self.data.config = {
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
        -- TODO: add player name property to replays
        local _ = read_str()
        local seed
        seed, offset = love.data.unpack("<I8", data, offset)
        for i = 1, 2 do
            self.data.seeds[i] = seed
        end
        local input_len
        input_len, offset = love.data.unpack("<I8", data, offset)
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
                self.data.input_times[#self.data.input_times + 1] = tick
                self.input_data[tick] = changed
            end
        end
        local need_change = {}
        for i = 1, 4 do
            if state[i] == 1 then
                need_change[#need_change+1] = i
                need_change[#need_change+1] = false
            end
        end
        if #need_change ~= 0 then
            self.input_data[last_tick + 1] = need_change
        end
        self.pack_id = read_str()
        self.level_id = read_str()
        -- no need to prefix level id with pack id
        self.level_id = self.level_id:sub(#self.pack_id + 2)
        -- version is not used for indexing packs in this version of the game
        self.pack_id = self.pack_id:match("(.*)_")

        self.first_play, offset = love.data.unpack("<B", data, offset)
        self.first_play = self.first_play == 1
        local dm
        -- TODO: check if this works on all platforms (float and double are native size)
        dm, offset = love.data.unpack("<f", data, offset)
        self.data.level_settings = { difficulty_mult = dm }
        -- TODO: store scores in replays maybe?
        local _ = love.data.unpack("<d", data, offset) / 60
    elseif version > 1 or version < 1 then
        error("Unsupported replay format version '" .. version .. "'.")
    else
        self.game_version, self.first_play, self.pack_id, self.level_id, offset =
            love.data.unpack(">BBzz", data, offset)
        self.first_play = self.first_play == 1
        offset, self.data = msgpack.unpack(data, offset - 1)
        offset = offset + 1
        for i = 1, #self.data.input_times do
            local time = self.data.input_times[i]
            self.input_data[time] = {}
            local changes
            changes, offset = love.data.unpack(">B", data, offset)
            for j = 1, changes * 2, 2 do
                local key, state
                key, state, offset = love.data.unpack(">BB", data, offset)
                self.input_data[time][j] = key
                self.input_data[time][j + 1] = state == 1
            end
        end
    end
end

return replay
