function love.run()
    -- load game for testing
    local game = require("compat.game21")
    game:start("cube", "pointless")

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
                    screen = love.graphics.newCanvas(width * scale[1], height * scale[2])
                end

                -- allow game modules to have their own event handlers
                if game.running and game[name] ~= nil then
                    game[name](game, a, b, c, d, e, f)
                end
            end
            if game.running then
                game:update(frametime)
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
                love.graphics.clear(1, 1, 1, 1)
                game:draw()
                love.graphics.setCanvas()
                -- render the canvas in the middle of the window
                love.graphics.origin()
                love.graphics.translate((width - width * scale[1]) / 2, (height - height * scale[2]) / 2)
                love.graphics.draw(screen)
            end
            love.graphics.present()
        end
    end
end
