local log = require("log")(...)
local args = require("args")

local function add_require_path(path)
    love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";" .. path)
end

local function add_c_require_path(path)
    love.filesystem.setCRequirePath(love.filesystem.getCRequirePath() .. ";" .. path)
end

function love.run()
    -- make sure no level accesses malicious files via symlinks
    love.filesystem.setSymlinksEnabled(false)

    -- find luasodium and luv
    add_require_path("extlibs/?.lua")
    add_c_require_path("lib/??")

    if args.migrate then
        -- migrate a ranking database from the old game to the new format
        if args.no_option == nil then
            error("Called migrate without a database to migrate")
        end
        require("compat.game21.server.migrate")(args.no_option)
        return function()
            return 0
        end
    end

    if args.server then
        -- game21 compat server (made for old clients)
        require("server")
        return function()
            return 0
        end
    end

    local config = require("config")
    local global_config = require("global_config")

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
        local audio = require("game_handler.video.audio")
        local video_encoder = require("game_handler.video")
        local fps = 60
        local ticks_to_frame = 0
        love.window.setMode(1920, 1080)
        video_encoder.start("output.mp4", 1920, 1080, fps, audio.sample_rate)
        audio.set_encoder(video_encoder)
        local after_death_frames = 3 * fps
        local game_handler = require("game_handler")
        global_config.init(config, game_handler.profile)
        game_handler.init(config, audio)
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
                audio.update(1 / fps)
                love.timer.step()
                love.graphics.origin()
                love.graphics.clear(0, 0, 0, 1)
                game_handler.draw()
                love.graphics.captureScreenshot(video_encoder.supply_video_data)
                love.graphics.present()
                if game_handler.is_dead() then
                    after_death_frames = after_death_frames - 1
                    if after_death_frames <= 0 then
                        video_encoder.stop()
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
