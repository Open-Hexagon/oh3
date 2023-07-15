local args = require("args")
local playsound = require("compat.game21.playsound")
local assets = require("compat.game20.assets")
local make_fake_config = require("compat.game20.fake_config")
local lua_runtime = require("compat.game20.lua_runtime")
local public = {
    running = false,
    first_play = true,
}
local game = {
    status = require("compat.game20.status"),
    level = require("compat.game20.level"),
    level_status = require("compat.game20.level_status"),
    vfs = require("compat.game192.virtual_filesystem"),
    message_text = "",
}
local must_change_sides = false
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
    -- TODO: init walls and player
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
    -- TODO: init 3d depth
end

function game.set_sides(sides)
    playsound(beep_sound)
    if sides < 3 then
        sides = 3
    end
    game.level_status.sides = sides
end

---update the game
---@param delta number
---@return number
function public.update(delta)
    game.real_time = game.real_time + delta
    -- the game runs on a tickrate of 120 ticks per second
    return 1 / 120
end

---draw the game to the current canvas
---@param screen love.Canvas
function public.draw(screen) end

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
function public.run_game_until_death(stop_condition) end

---stop the game
function public.stop()
    public.running = false
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
    end
end

return public
