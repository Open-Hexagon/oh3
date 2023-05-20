local msgpack = require("extlibs.msgpack.msgpack")

---@class Replay
---@field data table
---@field game_version number
---@field first_play boolean
---@field pack_id string
---@field level_id string
local replay = {}
replay.__index = replay

---creates or loads a replay if path is given
---@param path string?
---@return Replay
function replay:new(path)
    local obj = setmetatable({
        data = {
            inputs = {},
            seeds = {},
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
    self.data.inputs[time] = self.data.inputs[time] or {}
    local state_changes = self.data.inputs[time]
    state_changes[#state_changes + 1] = key
    state_changes[#state_changes + 1] = state
end

---saves the seed a math.randomseed call was given (this way they can be the same when the replay is replayed even if the level is settings its own random seeds)
function replay:record_seed(seed)
    self.data.seeds[#self.data.seeds + 1] = seed
end

function replay:_get_compressed()
    -- the old game's format version was 0, so we call this 1 now
    local header = love.data.pack(
        "string",
        ">BBBzz",
        1,
        self.game_version,
        self.first_play and 1 or 0,
        self.pack_id,
        self.level_id
    )
    local data = msgpack.pack(self.data)
    return love.data.compress("data", "zlib", header .. data, 9)
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
---@param data string?|love.CompressedData?
function replay:save(path, data)
    local file = love.filesystem.newFile(path)
    file:open("w")
    file:write(data or self:_get_compressed())
    file:close()
end

function replay:_read(path)
    local file = love.filesystem.newFile(path)
    file:open("r")
    local data = love.data.decompress("string", "zlib", file:read("data"))
    file:close()
    local version, offset = love.data.unpack(">B", data)
    if version > 1 or version < 1 then
        error("Unsupported replay format version '" .. version .. "'.")
    end
    self.game_version, self.first_play, self.pack_id, self.level_id, offset = love.data.unpack(">BBzz", data, offset)
    self.first_play = self.first_play == 1
    _, self.data = msgpack.unpack(data, offset - 1)
end

return replay
