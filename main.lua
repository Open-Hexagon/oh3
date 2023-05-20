local log = require("log")(...)
local args = require("args")
local game_handler = require("game_handler")

function love.run()
    if args.headless then
        if args.no_option == nil then
            error("Started headless mode without replay")
        end
        game_handler.replay_start(args.no_option)
        game_handler.run_until_death()
        log("Score: " .. game_handler.get_score())
        return function()
            return 0
        end
    end

    if args.no_option == nil then
        game_handler.set_version("192")
        game_handler.record_start("VeeDefault", "easy", { difficulty_mult = 1 })
    else
        game_handler.replay_start(args.no_option)
    end
    -- function is called every frame by love
    return function()
        -- process events
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            if name == "quit" then
                return a or 0
            end
            game_handler.process_event(name, a, b, c, d, e, f)
        end

        -- ensures tickrate on its own
        game_handler.update()

        if love.graphics.isActive() then
            -- reset any transformations and make the screen black
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 1)
            game_handler.draw()
            love.timer.step()
            -- used for testing TODO: remove once we have a proper ui element for it
            love.graphics.print(
                "FPS: "
                    .. love.timer.getFPS()
                    .. " Tickrate: "
                    .. game_handler.get_tickrate()
                    .. " Score: "
                    .. math.floor(game_handler.get_score() * 1000) / 1000
            )

            love.graphics.present()
        end
    end
end
