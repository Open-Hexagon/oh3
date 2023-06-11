local args = require("args")
local input = require("game_handler.input")
local Replay = require("game_handler.replay")
local pack_level_data = require("game_handler.data")
local game_handler = {}
local games = {
    ["192"] = require("compat.game192"),
    ["21"] = require("compat.game21"),
}
local current_game
local current_game_version
local first_play = true
local real_start_time
local start_time
local target_frametime = 1 / 240
-- enforce aspect ratio by rendering to canvas
local aspect_ratio = 16 / 9
local scale = { 1, 1 }
local screen
if not args.headless then
    -- correct aspect ratio initially (before the user resizes the window)
    love.event.push("resize", love.graphics.getDimensions())
end
game_handler.profile = require("game_handler.profile")

-- TODO: profile selection / creation
game_handler.profile.open_or_new("test")

---initialize all games (has to be called before doing anything)
---@param config any
function game_handler.init(config)
    for _, game in pairs(games) do
        game.init(pack_level_data, config)
    end
end

---set the game version to use
---@param version number
function game_handler.set_version(version)
    current_game = games[tostring(version)]
    current_game.set_input_handler(input)
    if current_game == nil then
        error("Game with version '" .. version .. "' does not exist or is unsupported.")
    end
    current_game_version = version
end

---start a level and start recording a replay
---@param pack string
---@param level string
---@param level_settings table
function game_handler.record_start(pack, level, level_settings)
    if current_game.dm_is_only_setting then
        if level_settings.difficulty_mult == nil or type(level_settings.difficulty_mult) ~= "number" then
            error("Level settings must contain 'difficulty_mult' when starting a compat game.")
        end
    end
    current_game.death_callback = function()
        game_handler.save_score()
    end
    current_game.seed = math.floor(love.timer.getTime() * 1000)
    input.replay = Replay:new()
    input.replay:set_game_data(
        current_game_version,
        current_game.config.get_all(current_game_version),
        first_play,
        pack,
        level,
        level_settings
    )
    input.record_start()
    if current_game.dm_is_only_setting then
        current_game.start(pack, level, level_settings.difficulty_mult)
    else
        current_game.start(pack, level, level_settings)
    end
    start_time = love.timer.getTime()
    real_start_time = start_time
    target_frametime = 1 / 240
    target_frametime = current_game.update(target_frametime) or target_frametime
end

---read a replay file and run the game with its inputs and seed
---@param file string
function game_handler.replay_start(file)
    -- TODO: don't require full path
    if love.filesystem.getInfo(file) then
        local replay = Replay:new(file)
        if replay.game_version ~= current_game_version then
            game_handler.set_version(replay.game_version)
        end
        input.replay = replay
        current_game.death_callback = nil
        -- TODO: save and restore config later
        for name, value in pairs(replay.data.config) do
            current_game.config.set(name, value)
        end
        input.replay_start()
        if current_game.dm_is_only_setting then
            current_game.start(replay.pack_id, replay.level_id, replay.data.level_settings.difficulty_mult)
        else
            current_game.start(replay.pack_id, replay.level_id, replay.data.level_settings)
        end
        if not args.headless then
            start_time = love.timer.getTime()
            real_start_time = start_time
        end
        target_frametime = 1 / 240
        target_frametime = current_game.update(target_frametime) or target_frametime
    else
        error("Replay file at '" .. file .. "' does not exist")
    end
end

---stops the game (it will not be updated or rendered anymore)
function game_handler.stop()
    current_game.stop()
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
    -- allow game modules to have their own event handlers
    if current_game.running and current_game[name] ~= nil then
        current_game[name](...)
    end
end

---save the score and replay of the current attempt (gets called automatically on death)
function game_handler.save_score()
    local elapsed_time = love.timer.getTime() - real_start_time
    game_handler.profile.save_score(current_game.get_score(), elapsed_time, input.replay)
end

---update the game if it's running
function game_handler.update()
    if current_game.running then
        -- update as much as required depending on passed time
        local current_time = love.timer.getTime()
        while current_time - start_time >= target_frametime do
            start_time = start_time + target_frametime
            -- allow games to control tick rate dynamically
            target_frametime = current_game.update(target_frametime) or target_frametime
            -- reset timings after longer blocking call
            if current_game.reset_timings then
                start_time = love.timer.getTime()
            end
        end
    end
end

---draw the game if it's running
function game_handler.draw()
    -- can only start rendering once the initial resize event was processed
    if current_game.running and screen ~= nil then
        local width, height = love.graphics.getDimensions()
        -- render onto the screen
        love.graphics.setCanvas(screen)
        love.graphics.clear(0, 0, 0, 1)
        -- make (0, 0) be the center
        love.graphics.translate(screen:getWidth() / 2, screen:getHeight() / 2)
        current_game.draw(screen)
        love.graphics.setCanvas()
        -- render the canvas in the middle of the window
        love.graphics.origin()
        love.graphics.translate((width - width * scale[1]) / 2, (height - height * scale[2]) / 2)
        -- the color of the canvas' contents will look wrong if color isn't white
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(screen)
    end
end

---get the current score of the game
---@return number
function game_handler.get_score()
    return current_game.get_score()
end

---get the current tickrate (this is constant for all game versions except 1.92)
---@return number
function game_handler.get_tickrate()
    return 1 / target_frametime
end

---run the game until the player dies without drawing it and without matching real time
function game_handler.run_until_death()
    current_game.run_game_until_death()
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

return game_handler