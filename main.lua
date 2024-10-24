local log = require("log")(...)
local async = require("async")
local args = require("args")
local threadify = require("threadify")
local channel_callbacks = require("channel_callbacks")

local function add_require_path(path)
    love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ";" .. path)
end

local function add_c_require_path(path)
    love.filesystem.setCRequirePath(love.filesystem.getCRequirePath() .. ";" .. path)
end

local render_replay = async(function(game_handler, video_encoder, audio, replay, out_file, final_score)
    local ui = require("ui")
    ui.open_screen("game")
    local fps = 60
    local ticks_to_frame = 0
    video_encoder.start(out_file, 1920, 1080, fps, audio.sample_rate)
    audio.set_encoder(video_encoder)
    local after_death_frames = 3 * fps
    async.await(game_handler.replay_start(replay))
    local frames = 0
    local last_print = love.timer.getTime()
    return function()
        love.event.pump()
        for name, a in love.event.poll() do
            if name == "quit" then
                log("Aborting video rendering.")
                video_encoder.stop()
                return a or 0
            end
        end
        if final_score then
            local now = love.timer.getTime()
            if now - last_print > 10 then
                log("Rendering progress: " .. (100 * game_handler.get_timed_score() / final_score) .. "%")
                last_print = now
            end
        end
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
            game_handler.draw(1 / fps)
            ui.update(1 / fps)
            ui.draw()
            love.graphics.captureScreenshot(video_encoder.supply_video_data)
            love.graphics.present()
            if game_handler.is_dead() then
                after_death_frames = after_death_frames - 1
                if after_death_frames <= 0 then
                    video_encoder.stop()
                    game_handler.stop()
                    return 0
                end
            end
        end
    end
end)

local main = async(function()
    -- make sure no level accesses malicious files via symlinks
    love.filesystem.setSymlinksEnabled(false)

    -- find libs
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

    if args.server and not args.render then
        -- game21 compat server (made for old clients)
        require("server")
        return function()
            return 0
        end
    end

    local config = require("config")
    local global_config = require("global_config")

    if args.server and args.render then
        -- render top scores sent to the server
        love.window.setMode(1920, 1080)
        local server_thread = love.thread.newThread("server/init.lua")
        server_thread:start("server", true, args.web)
        local game_handler = require("game_handler")
        local audio = require("game_handler.video.audio")
        local video_encoder = require("game_handler.video")
        global_config.init()
        async.await(game_handler.init(audio))
        game_handler.process_event("resize", 1920, 1080)
        local Replay = require("game_handler.replay")
        return function()
            local replay_file = love.thread.getChannel("replays_to_render"):demand()
            -- replay may no longer exist if player got new pb
            if love.filesystem.getInfo(replay_file) then
                local replay = Replay:new(replay_file)
                local out_file_path = love.filesystem.getSaveDirectory() .. "/" .. replay_file .. ".part.mp4"
                log("Got new #1 on '" .. replay.level_id .. "' from '" .. replay.pack_id .. "', rendering...")
                local promise = render_replay(game_handler, video_encoder, audio, replay, out_file_path, replay.score)
                local fn
                promise:done(function(func)
                    fn = func
                end)
                while not promise.executed do
                    threadify.update()
                    love.timer.sleep(0.01)
                end
                local aborted = false
                while fn() ~= 0 do
                    local abort_hash = love.thread.getChannel("abort_replay_render"):pop()
                    if abort_hash and abort_hash == replay_file:match(".*/(.*)") then
                        aborted = true
                        video_encoder.stop()
                        game_handler.stop()
                        break
                    end
                end
                if aborted then
                    log("aborted rendering.")
                    love.filesystem.remove(replay_file .. ".part.mp4")
                else
                    os.rename(out_file_path, out_file_path:gsub("%.part%.mp4", "%.mp4"))
                    log("done.")
                end
            end
        end
    end

    if args.headless then
        if args.no_option == nil then
            error("Started headless mode without replay")
        end
        local game_handler = require("game_handler")
        global_config.init()
        async.await(game_handler.init())
        async.await(game_handler.replay_start(args.no_option))
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
        love.window.setMode(1920, 1080)
        local game_handler = require("game_handler")
        local audio = require("game_handler.video.audio")
        local video_encoder = require("game_handler.video")
        global_config.init()
        async.await(game_handler.init(audio))
        game_handler.process_event("resize", 1920, 1080)
        return async.await(render_replay(game_handler, video_encoder, audio, args.no_option, "output.mp4"))
    end

    local ui = require("ui")
    ui.open_screen("loading")
    local game_handler = require("game_handler")
    global_config.init()
    -- apply fullscreen setting initially
    config.get_definitions().fullscreen.onchange(config.get("fullscreen"))

    local fps_limit = config.get("fps_limit")
    local delta_target = 1 / fps_limit
    local last_time = love.timer.getTime()

    game_handler.init():done(function()
        if args.no_option then
            async.await(game_handler.replay_start(args.no_option))
            ui.open_screen("game")
        else
            ui.open_screen("levelselect")
        end
    end)
    local level = require("ui.screens.levelselect.level")

    -- function is called every frame by love
    return function()
        local new_fps_limit = config.get("fps_limit")
        if fps_limit ~= new_fps_limit then
            fps_limit = new_fps_limit
            delta_target = 1 / fps_limit
        end
        if fps_limit ~= 0 then
            love.timer.sleep(delta_target - (love.timer.getTime() - last_time))
            last_time = last_time + delta_target
        end

        -- process events
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            if name == "quit" then
                config.save()
                threadify.stop()
                return a or 0
            elseif name == "threaderror" then
                config.save()
                error("Error in thread: " .. b)
            end
            game_handler.process_event(name, a, b, c, d, e, f)
            ui.process_event(name, a, b, c, d, e, f)
        end

        threadify.update()
        channel_callbacks.update()
        ui.update(love.timer.getDelta())

        -- ensures tickrate on its own
        game_handler.update(true)

        if love.graphics.isActive() then
            -- reset any transformations and make the screen black
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 1)
            game_handler.draw()
            if level.current_preview_active and not game_handler.is_running() then
                level.current_preview:draw(true)
            end
            ui.draw()
            love.graphics.present()
        end
        love.timer.step()
    end
end)

function love.run()
    local promise = main()
    local result
    promise:done(function(...)
        result = ...
    end)
    while not result do
        threadify.update()
        love.timer.sleep(0.01)
    end
    return result
end
