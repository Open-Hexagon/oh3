local args = require("args")
local input = require("game_handler.input")
local Replay = require("game_handler.replay")
local pack_level_data = require("game_handler.data")
local async = require("async")
local music = require("compat.music")
local threadify = require("threadify")
local threaded_assets = threadify.require("game_handler.assets")
local game_handler = {}
local games = {
    [192] = require("compat.game192"),
    [20] = require("compat.game20"),
    [21] = require("compat.game21"),
}
local last_pack, last_level, last_level_settings, last_version
local current_game
local current_game_version
local first_play = true
local start_time
-- enforce aspect ratio by rendering to canvas
local aspect_ratio = 16 / 9
local scale = { 1, 1 }
local screen
if not args.headless then
    -- correct aspect ratio initially (before the user resizes the window)
    love.event.push("resize", love.graphics.getDimensions())
end
local game_config
game_handler.profile = require("game_handler.profile")

---initialize all games (has to be called before doing anything)
---@param config any
game_handler.init = async(function(config, audio)
    game_config = config
    audio = audio or require("audio")
    -- 1.92 needs persistent data for asset loading as it can overwrite any file
    local persistent_data
    if not args.server and not args.migrate then
        persistent_data = game_handler.profile.get_all_data()
    end
    local packs = async.await(threaded_assets.init(persistent_data, args.headless))
    pack_level_data.import_packs(packs)
    for _, game in pairs(games) do
        local promise = game.init(input, config, audio)
        if promise then
            async.await(promise)
        end
    end
    music.init(audio)
end)

---set the game version to use
---@param version number
function game_handler.set_version(version)
    current_game = games[version]
    if current_game == nil then
        error("Game with version '" .. version .. "' does not exist or is unsupported.")
    end
    current_game_version = version
    last_version = version
end

---start a level and start recording a replay
---@param pack string
---@param level string
---@param level_settings table
---@param is_retry boolean = false
game_handler.record_start = async(function(pack, level, level_settings, is_retry)
    current_game.death_callback = function()
        if current_game.update_save_data ~= nil then
            current_game.update_save_data()
        end
        if current_game.persistent_data ~= nil then
            input.replay.data.persistent_data = current_game.persistent_data
            game_handler.profile.store_data(pack, current_game.persistent_data)
        end
        game_handler.save_score()
    end
    current_game.persistent_data = game_handler.profile.get_data(pack)

    first_play = not is_retry

    input.replay = Replay:new()
    input.replay:set_game_data(
        current_game_version,
        game_config.get_all(current_game_version),
        first_play,
        game_handler.profile.get_current_profile(),
        pack,
        level,
        level_settings
    )
    current_game.first_play = first_play
    input.record_start()
    async.await(current_game.start(pack, level, level_settings))
    start_time = love.timer.getTime()
    current_game.update(1 / current_game.tickrate)
    last_pack = pack
    last_level = level
    last_level_settings = level_settings
end)

---retry the level that was last started with record_start
game_handler.retry = async(function()
    game_handler.stop()
    game_handler.set_version(last_version)
    game_handler.record_start(last_pack, last_level, last_level_settings, true)
end)

---read a replay file and run the game with its inputs and seeds
---@param file_or_replay_obj string|Replay
game_handler.replay_start = async(function(file_or_replay_obj)
    local replay
    if type(file_or_replay_obj) == "table" then
        replay = file_or_replay_obj
    else
        if love.filesystem.getInfo(file_or_replay_obj) then
            replay = Replay:new(file_or_replay_obj)
        else
            error("Replay file at '" .. file_or_replay_obj .. "' does not exist")
        end
    end
    if replay.game_version ~= current_game_version then
        game_handler.set_version(replay.game_version)
    end
    current_game.persistent_data = replay.data.persistent_data
    input.replay = replay
    first_play = replay.first_play
    current_game.first_play = first_play
    local old_config_values = {}
    local current_values = game_config.get_all()
    for name, value in pairs(replay.data.config) do
        old_config_values[name] = current_values[name]
        game_config.set(name, value)
    end
    current_game.death_callback = function()
        for name, value in pairs(old_config_values) do
            game_config.set(name, value)
        end
    end
    input.replay_start()
    async.await(current_game.start(replay.pack_id, replay.level_id, replay.data.level_settings))
    if not args.headless then
        start_time = love.timer.getTime()
    end
    current_game.update(1 / current_game.tickrate)
end)

---stops the game (it will not be updated or rendered anymore)
function game_handler.stop()
    current_game.stop()
end

---check if the game is replaying a replay
---@return boolean
function game_handler.is_replaying()
    return input.is_replaying()
end

---process an event (mainly used for aspect ratio resizing)
---@param name string
---@param ... unknown
function game_handler.process_event(name, ...)
    if name == "resize" then
        local width, height = ...
        if width < height * aspect_ratio then
            -- window is too high for the aspect_ratio
            scale[1] = 1
            scale[2] = width / (aspect_ratio * height)
        else
            -- window is toowide for the aspect_ratio
            scale[1] = height * aspect_ratio / width
            scale[2] = 1
        end
        -- recreate screen canvas to have the correct size
        width, height = love.graphics.getDimensions()
        screen = love.graphics.newCanvas(width * scale[1], height * scale[2], {
            -- TODO: make adjustable in settings
            msaa = 4,
        })
    end
    if current_game then
        -- allow game modules to have their own event handlers
        if current_game.running and current_game[name] ~= nil then
            current_game[name](...)
        end
    end
end

---get the dimensions of the game canvas (returns 0, 0 if it was not created yet)
---@return integer
---@return integer
function game_handler.get_game_dimensions()
    if screen then
        return screen:getDimensions()
    else
        return 0, 0
    end
end

---get the position of the game canvas on the screen
---@return number
---@return number
function game_handler.get_game_position()
    local width, height = love.graphics.getDimensions()
    return (width - width * scale[1]) / 2, (height - height * scale[2]) / 2
end

---save the score and replay of the current attempt (gets called automatically on death)
function game_handler.save_score()
    input.replay.score = current_game.get_score()
    game_handler.profile.save_score(game_handler.get_timed_score(), input.replay)
end

---update the game if it's running
---@param ensure_tickrate boolean
function game_handler.update(ensure_tickrate)
    if current_game and current_game.running then
        if ensure_tickrate then
            -- update as much as required depending on passed time
            local current_time = love.timer.getTime()
            while current_time - start_time >= 1 / current_game.tickrate do
                start_time = start_time + 1 / current_game.tickrate
                -- allow games to control tick rate dynamically
                current_game.update(1 / current_game.tickrate)
                -- reset timings after longer blocking call
                if current_game.reset_timings then
                    start_time = love.timer.getTime()
                end
                if game_handler.onupdate then
                    game_handler.onupdate()
                end
            end
        else
            current_game.update(1 / current_game.tickrate)
            if game_handler.onupdate then
                game_handler.onupdate()
            end
        end
    end
end

---draw the game if it's running
---@param frametime number?
function game_handler.draw(frametime)
    -- can only start rendering once the initial resize event was processed
    if current_game and current_game.running and screen ~= nil then
        frametime = frametime or love.timer.getDelta()
        local width, height = love.graphics.getDimensions()
        -- render onto the screen
        love.graphics.setCanvas(screen)
        love.graphics.clear(0, 0, 0, 1)
        -- make (0, 0) be the center
        love.graphics.translate(screen:getWidth() / 2, screen:getHeight() / 2)
        current_game.draw(screen, frametime)
        love.graphics.setCanvas()
        -- render the canvas in the middle of the window
        love.graphics.origin()
        love.graphics.translate((width - width * scale[1]) / 2, (height - height * scale[2]) / 2)
        -- the color of the canvas' contents will look wrong if color isn't white
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(screen)
        love.graphics.origin()
    end
end

---check if a replay is fully replayed only in terms of inputs
---@return boolean
function game_handler.is_replay_done()
    return input.is_done_replaying
end

---get the current score of the game
---@return number
---@return boolean
function game_handler.get_score()
    return current_game.get_score()
end

---get the current time of the game even if the score time was halted or if a custom score is used
---@return number
function game_handler.get_timed_score()
    if current_game.get_timed_score then
        return current_game.get_timed_score()
    else
        return current_game.get_score()
    end
end

---21 specific function for getting the custom score the client saves in replays
---@return number?
function game_handler.get_compat_custom_score()
    if current_game_version ~= 21 then
        error("attempted to get compat custom score in non 21 game version")
    end
    return current_game.get_compat_custom_score()
end

---get the current tickrate (this is constant for all game versions except 1.92)
---@return number
function game_handler.get_tickrate()
    return current_game.tickrate
end

---run the game until the player dies without drawing it and without matching real time
---@param stop_condition function?
function game_handler.run_until_death(stop_condition)
    while not current_game.is_dead() do
        current_game.update(1 / current_game.tickrate)
        if stop_condition and stop_condition() then
            return
        end
    end
    current_game.stop()
end

---gets the current replay (nil if there is none)
---@return Replay|nil
function game_handler.get_replay()
    return input.replay
end

---get all packs and relevant data for level selection
---@return table
function game_handler.get_packs()
    return pack_level_data.get_packs()
end

---gets if the player is dead
---@return boolean
function game_handler.is_dead()
    return current_game.is_dead()
end

---returns true if a game is running
---@return boolean
function game_handler.is_running()
    return current_game and current_game.running or false
end

---draws a minimal level preview to a canvas
---@param canvas love.Canvas
---@param game_version number
---@param pack string
---@param level string
---@return table?
function game_handler.draw_preview(canvas, game_version, pack, level)
    if games[game_version].draw_preview then
        return games[game_version].draw_preview(canvas, pack, level)
    end
end

return game_handler
