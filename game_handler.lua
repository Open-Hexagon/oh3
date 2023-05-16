local args = require("args")
local input = require("input")
local Replay = require("replay")
local game_handler = {}
local games = {
    ["192"] = require("compat.game192"),
    ["21"] = require("compat.game21"),
}
local current_game
local current_game_version
local first_play = true
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

function game_handler.set_version(version)
    current_game = games[version]
    current_game.death_callback = function()
        game_handler.save_replay()
    end
    current_game.set_input_handler(input)
    if current_game == nil then
        error("Game with version '" .. version .. "' does not exist or is unsupported.")
    end
    current_game_version = tonumber(version)
end

function game_handler.record_start(pack, level, level_settings)
    if current_game.dm_is_only_setting then
        if level_settings.difficulty_mult == nil or type(level_settings.difficulty_mult) ~= "number" then
            error("Level settings must contain 'difficulty_mult' when starting a compat game.")
        end
    end
    current_game.seed = math.floor(love.timer.getTime() * 1000)
    input.replay = Replay:new()
    input.replay:set_game_data(
        current_game_version,
        current_game.config.get_all(),
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
    target_frametime = 1 / 240
end

function game_handler.replay_start(file)
    -- TODO: don't require full path
    if love.filesystem.getInfo(file) then
        local replay = Replay:new(file)
        if replay.game_version ~= current_game_version then
            game_handler.set_version(tostring(replay.game_version))
        end
        input.replay = replay
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
        end
        target_frametime = 1 / 240
    else
        error("Replay file at '" .. file .. "' does not exist")
    end
end

function game_handler.stop()
    current_game.stop()
end

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

function game_handler.save_replay()
    -- TODO: save in different location depending on level and level_settings
    input.replay:save("test.ohr.z")
end

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

function game_handler.get_score()
    return current_game.get_score()
end

function game_handler.get_tickrate()
    return 1 / target_frametime
end

function game_handler.run_until_death()
    current_game.run_game_until_death()
end

return game_handler
