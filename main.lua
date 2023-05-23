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
        -- temporary command line menu
        local packs = game_handler.get_packs()
        for i = 1, #packs do
            local pack = packs[i]
            print(i, pack.name .. " (" .. pack.id .. ")")
        end
        print("Enter pack number:")
        local pack = packs[tonumber(io.input():read())]
        for i = 1, pack.level_count do
            print(i, pack.levels[i].name)
        end
        print("Enter level number:")
        local level = pack.levels[tonumber(io.input():read())]
        local options = {}
        for option, values in pairs(level.options) do
            print(option .. ":")
            for i = 1, #values do
                print(i, values[i])
            end
            print("Enter value number:")
            options[option] = values[tonumber(io.input():read())]
        end

        game_handler.set_version(tostring(pack.game_version))
        game_handler.record_start(pack.id, level.id, options)
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
