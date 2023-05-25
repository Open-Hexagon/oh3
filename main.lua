local log = require("log")(...)
local args = require("args")
local config = require("config")
local global_config = require("global_config")

function love.run()
    if args.headless then
        if args.no_option == nil then
            error("Started headless mode without replay")
        end
        local game_handler = require("game_handler")
        global_config.init(config, game_handler.profile)
        game_handler.init(config)
        game_handler.replay_start(args.no_option)
        game_handler.run_until_death()
        log("Score: " .. game_handler.get_score())
        return function()
            return 0
        end
    end

    if args.render then
        if args.no_option == nil then
            error("trying to render replay without replay")
        end
        local audio_mixer = require("game_handler.video.mixer")
        local fake_source = require("game_handler.video.fake_source")
        local video_encoder = require("game_handler.video")
        local fps = 60
        local ticks_to_frame = 0
        love.window.setMode(1920, 1080)
        video_encoder.start("output.mp4", 1920, 1080, fps)
        audio_mixer.set_muxer(video_encoder)
        fake_source.init(audio_mixer)
        local after_death_frames = 3 * fps
        local game_handler = require("game_handler")
        global_config.init(config, game_handler.profile)
        game_handler.init(config)
        game_handler.replay_start(args.no_option)
        game_handler.process_event("resize", 1920, 1080)
        local frames = 0
        return function()
            if love.graphics.isActive() then
                frames = frames + 1
                ticks_to_frame = ticks_to_frame + game_handler.get_tickrate() / fps
                for _ = 1, ticks_to_frame do
                    ticks_to_frame = ticks_to_frame - 1
                    game_handler.update(false)
                end
                fake_source.update(frames / fps)
                love.timer.step()
                love.graphics.origin()
                love.graphics.clear(0, 0, 0, 1)
                game_handler.draw()
                love.graphics.captureScreenshot(video_encoder.supply_video)
                love.graphics.present()
                if game_handler.is_dead() then
                    after_death_frames = after_death_frames - 1
                    if after_death_frames <= 0 then
                        video_encoder.cleanup()
                        return 0
                    end
                end
            end
        end
    end

    local game_handler = require("game_handler")
    global_config.init(config, game_handler.profile)
    game_handler.init(config)
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

        game_handler.set_version(pack.game_version)
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
        game_handler.update(true)

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
