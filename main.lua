local args = require("args")
local input = require("input")
local Replay = require("replay")
-- load game for testing
local game = require("compat.game21")
game.set_input_handler(input)

local function record_replay(pack, level, dm)
    game.seed = math.floor(love.timer.getTime() * 1000)
    math.randomseed(game.seed)
    math.random()
    input.replay = Replay:new()
    input.replay:set_game_data(game.config.get_all(), true, game.seed, pack, level, { difficulty_mult = dm })
    input.record_start()
    game.start(pack, level, dm)
end

local function replay_replay(file)
    input.replay = Replay:new(file)
    local replay = input.replay
    -- TODO: save and restore config later
    for name, value in pairs(replay.data.config) do
        game.config.set(name, value)
    end
    game.seed = replay.seed
    math.randomseed(game.seed)
    math.random()
    input.replay_start()
    game.start(replay.pack_id, replay.level_id, replay.data.level_settings.difficulty_mult)
end

function love.run()
    -- uncomment these to record/replay a replay (make sure to uncomment the save call below as well when recording)
    if args.headless then
        if args.no_option == nil then
            error("Started headless mode without replay")
        end
        replay_replay(args.no_option)
        game.run_game_until_death()
        print("Score: " .. game.get_score())
    else
        if args.no_option == nil then
            record_replay("cube", "pointless", 1)
        else
            replay_replay(args.no_option)
        end

        -- target frametime
        local frametime = 1 / 240
        local start_time = love.timer.getTime()

        -- enforce aspect ratio by rendering to canvas
        local aspect_ratio = 16 / 9
        local scale = { 1, 1 }
        local screen
        -- correct aspect ratio initially (before the user resizes the window)
        love.event.push("resize", love.graphics.getDimensions())

        -- function is called every frame by love
        return function()
            -- update as much as required depending on passed time
            local current_time = love.timer.getTime()
            while current_time - start_time >= frametime do
                start_time = start_time + frametime

                -- process events
                love.event.pump()
                for name, a, b, c, d, e, f in love.event.poll() do
                    if name == "quit" then
                        -- TODO: do this somewhere else
                        input.replay:save("test.ohr.z")
                        return a or 0
                    end
                    if name == "resize" then
                        if a < b * aspect_ratio then
                            -- window is too high for the aspect ratio
                            scale[1] = 1
                            scale[2] = a / (aspect_ratio * b)
                        else
                            -- window is too wide for the aspect ratio
                            scale[1] = b * aspect_ratio / a
                            scale[2] = 1
                        end
                        -- recreate screen canvas to have the correct size
                        local width, height = love.graphics.getDimensions()
                        screen = love.graphics.newCanvas(width * scale[1], height * scale[2], {
                            -- TODO: make adjustable in settings
                            msaa = 4,
                        })
                    end

                    -- allow game modules to have their own event handlers
                    if game.running and game[name] ~= nil then
                        game[name](game, a, b, c, d, e, f)
                    end
                end
                if game.running then
                    game.update(frametime)
                end
            end
            if love.graphics.isActive() then
                local width, height = love.graphics.getDimensions()
                -- reset any transformations and make the screen black
                love.graphics.origin()
                love.graphics.clear(0, 0, 0, 1)
                -- can only start rendering once the initial resize event was processed
                if game.running and screen ~= nil then
                    -- render onto the screen
                    love.graphics.setCanvas(screen)
                    -- clear with white for now, so the resizing can be seen in action
                    love.graphics.clear(0, 0, 0, 1)
                    -- make (0, 0) be the center
                    love.graphics.translate(screen:getWidth() / 2, screen:getHeight() / 2)
                    game.draw(screen)
                    love.graphics.setCanvas()
                    -- render the canvas in the middle of the window
                    love.graphics.origin()
                    love.graphics.translate((width - width * scale[1]) / 2, (height - height * scale[2]) / 2)
                    -- the color of the canvas' contents will look wrong if color isn't white
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(screen)
                end
                love.timer.step()
                -- used for testing TODO: remove once we have a proper ui element for it
                love.graphics.print(
                    "FPS: " .. love.timer.getFPS() .. " Score: " .. math.floor(game.get_score() * 1000) / 1000
                )

                love.graphics.present()
            end
        end
    end
end
