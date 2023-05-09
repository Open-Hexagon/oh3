local msgpack = require("extlibs.msgpack.msgpack")
local bit = require("bit")

---@class Replay
---@field private data table
local replay = {}
replay.__index = replay

---creates or loads a replay if path is given
---@param path string?
---@return Replay
function replay:new(path)
    local obj = setmetatable({
        data = {
            inputs = {}
        },
    }, replay)
    if path ~= nil then
        obj:_read(path)
    end
    return obj
end

---gets the key state changes (not the key state) for a specified tick
---the table is formatted like this: {<key>, <state>, <key>, <state>, ...}
---nil means that no inputs changed at the time
---@param time number
---@return table?
function replay:get_key_state_changes(time)
    return self.data.inputs[time]
end

---set the level and the settings the game was started with
---@param config table global game settings (containing settings such as black and white mode)
---@param seed number
---@param pack_id string
---@param level_id string
---@param level_settings table level specific settings (e.g. the difficulty mult in 21)
function replay:set_game_data(config, seed, pack_id, level_id, level_settings)
    self.data.config = config
    self.data.seed = seed
    self.data.pack_id = pack_id
    self.data.level_id = level_id
    self.data.level_settings = level_settings
end

---saves an input into the replay file
---@param key love.KeyConstant
---@param state boolean
---@param time number timestamp (in ticks)
function replay:record_input(key, state, time)
    self.data.inputs[time] = self.data.inputs[time] or {}
    local state_changes = self.data.inputs[time]
    state_changes[#state_changes + 1] = key
    state_changes[#state_changes + 1] = state
end

---saves the replay into a file
---@param path string
function replay:save(path)
    local extra_data = msgpack.pack(self.data)
    local inputs = msgpack.pack(self.data.inputs)
    local file = love.filesystem.newFile(path)
    file:open("w")
    file:write(love.data.compress("data", "zlib", extra_data .. inputs, 9))
    file:close()
end

function replay:_read(path)
    local file = love.filesystem.newFile(path)
    file:open("r")
    local data = love.data.decompress("string", "zlib", file:read("data"))
    file:close()
    local offset
    offset, self.data = msgpack.unpack(data)
    _, self.data.inputs = msgpack.unpack(data, offset)
end

return replay
