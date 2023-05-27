local ui = require("ui")
local signal = require("anim.signal")

function love.load(arg)
    ui.load()
    -- Setup goes here
end

function love.draw()
    -- TODO: rendering
    ui.draw()
end

function love.update(dt)
    signal.update(dt)
    ui.update(dt)
end

function love.run()
    -- Parse arguments
    -- (Some Lua language servers don't know that the love.arg field exists)
    ---@diagnostic disable-next-line: undefined-field
    love.load(love.arg.parseGameArguments(arg))

    -- enforce aspect ratio by rendering to canvas
    local aspect_ratio = 16 / 9
    local scale = { 1, 1 }
    local screen
    -- correct aspect ratio initially (before the user resizes the window)
    love.event.push("resize", love.graphics.getDimensions())

    -- target frametime
    local frametime = 1 / 240
    local start_time = love.timer.getTime()
    love.timer.step()

    -- ## Main loop
    return function()
        -- process events
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            if name == "quit" then
                return a or 0
            end

            if name == "resize" then
                ui.resize()
            else
                ui.handle_event(name, a, b, c, d, e, f)
            end
            --print(name, a, b, c, d, e, f)
        end

        local current_time = love.timer.getTime()
        local dt = love.timer.step()

        -- tick based update
        while current_time - start_time >= frametime do
            start_time = start_time + frametime
            -- TODO: update game state
        end

        -- deltatime based update
        love.update(dt)

        if love.graphics.isActive() then
            -- reset any transformations and make the screen black
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 1)
            love.draw()
            love.graphics.present()
        end
    end
end
