local args = require("args")
local playsound = require("compat.game21.playsound")
local assets = require("compat.game20.assets")
local make_fake_config = require("compat.game20.fake_config")
local lua_runtime = require("compat.game20.lua_runtime")
local dynamic_tris = require("compat.game21.dynamic_tris")
local dynamic_quads = require("compat.game21.dynamic_quads")
local public = {
    running = false,
    first_play = true,
}
local game = {
    status = require("compat.game20.status"),
    level = require("compat.game20.level"),
    level_status = require("compat.game20.level_status"),
    vfs = require("compat.game192.virtual_filesystem"),
    style = require("compat.game20.style"),
    player = require("compat.game20.player"),
    message_text = "",
}
local wall_quads, player_tris
local must_change_sides = false
local last_move, input_both_cw_ccw = 0, false
local beep_sound

---starts a new game
---@param pack_id string
---@param level_id string
---@param level_options table
function public.start(pack_id, level_id, level_options)
    game.difficulty_mult = level_options.difficulty_mult
    if not game.difficulty_mult then
        error("Cannot start compat game without difficulty mult")
    end
    -- TODO: init flash
    game.pack = assets.get_pack(pack_id)
    game.level.set(game.pack.levels[level_id])
    game.level_status.reset()
    game.style.set(game.pack.styles[game.level.styleId])
    public.running = true
    -- TODO: init audio

    -- virtual filesystem init
    game.vfs.clear()
    game.vfs.pack_path = game.pack.path
    game.vfs.pack_folder_name = game.pack.folder
    local files = {
        ["config.json"] = make_fake_config(game.config),
    }
    if public.persistent_data ~= nil then
        for path, contents in pairs(public.persistent_data) do
            files[path] = contents
        end
    end
    game.vfs.load_files(files)

    game.message_text = ""
    -- TODO: clear and reset event and message timelines
    -- TODO: init walls
    game.player.reset(game, assets)
    -- TODO: clear and reset main timeline
    must_change_sides = false
    game.status.reset()
    game.real_time = 0
    if not public.first_play then
        lua_runtime.run_fn_if_exists("onUnload")
    end
    lua_runtime.init_env(game, public, assets)
    lua_runtime.run_lua_file(game.pack.path .. game.level.luaFile)
    lua_runtime.run_fn_if_exists("onInit")
    lua_runtime.run_fn_if_exists("onLoad")
    game.set_sides(game.level_status.sides)
    game.current_rotation = 0
    game.style._3D_depth = math.min(game.style._3D_depth, game.config.get("3D_max_depth"))
end

function game.set_sides(sides)
    playsound(beep_sound)
    if sides < 3 then
        sides = 3
    end
    game.level_status.sides = sides
end

local function get_smoother_step(edge0, edge1, x)
    x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return x * x * x * (x * (x * 6 - 15) + 10)
end

---update the game
---@param frametime number
---@return number
function public.update(frametime)
    game.real_time = game.real_time + frametime
    frametime = frametime * 60
    local focus = game.input.get(game.config.get("key_focus"))
    local swap = game.input.get(game.config.get("key_swap"))
    local cw = game.input.get(game.config.get("key_right"))
    local ccw = game.input.get(game.config.get("key_left"))
    local move = 0
    if cw and not ccw then
        move = 1
    elseif not cw and ccw then
        move = -1
    elseif cw and ccw then
        if not input_both_cw_ccw then
            if move == 1 and last_move == 1 then
                move = -1
            elseif move == -1 and last_move == -1 then
                move = 1
            end
        end
    end
    last_move = move
    input_both_cw_ccw = cw and ccw
    -- TODO: flash
    if not game.status.has_died then
        -- TODO: walls
        game.player.update(frametime, move, focus, swap)
        -- TODO: events
        -- TODO: time stop
        -- TODO: increment
        -- TODO: level
        -- TODO: beatpulse
        -- TODO: pulse
        if not game.config.get("black_and_white") then
            game.style.update(frametime, math.pow(game.difficulty_mult, 0.8))
        end
    else
        game.level_status.rotation_speed = game.level_status.rotation_speed * 0.99
    end
    if game.config.get("3D_enabled") then
        game.status.pulse_3D = game.style._3D_pulse_speed * game.status.pulse_3D_direction * frametime
        if game.status.pulse_3D > game.style._3D_pulse_max then
            game.status.pulse_3D_direction = -1
        elseif game.status.pulse_3D < game.style._3D_pulse_min then
            game.status.pulse_3D_direction = 1
        end
    end
    if game.config.get("rotation") then
        local next_rotation = game.level_status.rotation_speed * 10
        if game.status.fast_spin > 0 then
            next_rotation = next_rotation + math.abs(get_smoother_step(0, game.level_status.fast_spin, game.status.fast_spin) / 3.5 * 17) * (next_rotation > 0 and 1 or -1)
            game.status.fast_spin = game.status.fast_spin - frametime
        end
        game.current_rotation = (game.current_rotation + next_rotation) % 360
    end
    -- the game runs on a tickrate of 120 ticks per second
    return 1 / 120
end

---draw the game to the current canvas
---@param screen love.Canvas
function public.draw(screen)
    local width, height = screen:getDimensions()
    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / width, 768 / height)
    -- apply pulse as well
    local p = game.status.pulse / game.level_status.pulse_min
    love.graphics.scale(zoom_factor / p, zoom_factor / p)
    local effect
    if game.config.get("3D_enabled") then
        effect = game.style._3D_skew * game.status.pulse_3D * game.config.get("3D_multiplier")
        love.graphics.scale(1, 1 / (1 + effect))
    end
    love.graphics.rotate(math.rad(game.current_rotation))
    game.style.compute_colors()
    local black_and_white = game.config.get("black_and_white")
    if game.config.get("background") then
        game.style.draw_background(game.level_status.sides, black_and_white)
    end

    player_tris:clear()
    wall_quads:clear()
    game.player.draw(player_tris, wall_quads)
    wall_quads:draw()
    player_tris:draw()
end

---get the current score
---@return number
function public.get_score()
    return game.status.current_time
end

---get the timed current score
---@return number
function public.get_timed_score()
    return game.real_time
end

---runs the game until the player dies without caring about real time
---@param stop_condition function
function public.run_game_until_death(stop_condition)
    while not game.status.has_died do
        public.update(1 / 120)
        if stop_condition and stop_condition() then
            return
        end
    end
    public.stop()
end

---stop the game
function public.stop()
    public.running = false
    -- TODO: stop audio
end

---updates the persistent data
function public.update_save_data()
    local files = game.vfs.dump_files()
    files["config.json"] = nil
    local has_files = false
    for _, _ in pairs(files) do
        has_files = true
        break
    end
    if has_files then
        public.persistent_data = files
    end
end

---initialize the game
---@param pack_level_data table
---@param input_handler table
---@param config table
---@param persistent_data table
---@param audio table
function public.init(pack_level_data, input_handler, config, persistent_data, audio)
    assets.init(pack_level_data, persistent_data, audio, config)
    game.config = config
    game.input = input_handler
    if not args.headless then
        beep_sound = assets.get_sound("click.ogg")
        wall_quads = dynamic_quads:new()
        player_tris = dynamic_tris:new()
    end
end

return public
