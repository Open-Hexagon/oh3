local log = require("log")(...)
local play_sound = require("compat.game192.play_sound")
local utils = require("compat.game192.utils")
local lua_runtime = {
    env = {},
}

local file_cache = {}
local env = lua_runtime.env
local keycode_conversion = {
    [0] = "a",
    [1] = "b",
    [2] = "c",
    [3] = "d",
    [4] = "e",
    [5] = "f",
    [6] = "g",
    [7] = "h",
    [8] = "i",
    [9] = "j",
    [10] = "k",
    [11] = "l",
    [12] = "m",
    [13] = "n",
    [14] = "o",
    [15] = "p",
    [16] = "q",
    [17] = "r",
    [18] = "s",
    [19] = "t",
    [20] = "u",
    [21] = "v",
    [22] = "w",
    [23] = "x",
    [24] = "y",
    [25] = "z",
    [26] = "0",
    [27] = "1",
    [28] = "2",
    [29] = "3",
    [30] = "4",
    [31] = "5",
    [32] = "6",
    [33] = "7",
    [34] = "8",
    [35] = "9",
    [36] = "escape",
    [37] = "lctrl",
    [38] = "lshift",
    [39] = "lalt",
    [40] = "lgui",
    [41] = "rctrl",
    [42] = "rshift",
    [43] = "ralt",
    [44] = "rgui",
    [45] = "menu",
    [46] = "(",
    [47] = ")",
    [48] = ";",
    [49] = ",",
    [50] = ".",
    [51] = "'",
    [52] = "/",
    [53] = "\\",
    -- love doesn't have this one
    --[54] = "~",
    [55] = "=",
    [56] = "-",
    [57] = "space",
    [58] = "return",
    [59] = "backspace",
    [60] = "tab",
    [61] = "pageup",
    [62] = "pagedown",
    [63] = "end",
    [64] = "home",
    [65] = "insert",
    [66] = "delete",
    [67] = "+",
    [68] = "-",
    [69] = "*",
    [70] = "/",
    [71] = "left",
    [72] = "right",
    [73] = "up",
    [74] = "down",
    [75] = "kp0",
    [76] = "kp1",
    [77] = "kp2",
    [78] = "kp3",
    [79] = "kp4",
    [80] = "kp5",
    [81] = "kp6",
    [82] = "kp7",
    [83] = "kp8",
    [84] = "kp9",
    [85] = "f1",
    [86] = "f2",
    [87] = "f3",
    [88] = "f4",
    [89] = "f5",
    [90] = "f6",
    [91] = "f7",
    [92] = "f8",
    [93] = "f9",
    [94] = "f10",
    [95] = "f11",
    [96] = "f12",
    [97] = "f13",
    [98] = "f14",
    [99] = "f15",
    [100] = "pause",
}

function lua_runtime.error(msg)
    log("Error: " .. msg)
end

local clock_count = 0
local key_count = 0
local block_threshold = 1000

function lua_runtime.init_env(game, public)
    local pack = game.pack
    local config = public.config
    lua_runtime.env = {
        os = {
            time = function(...)
                return os.time(...)
            end,
            clock = function()
                clock_count = clock_count + 1
                if clock_count > block_threshold then
                    -- blocking call (something like: `while os.clock() < x do ...`)
                    game.blocked = true
                    public.real_game_loop()
                    game.blocked = false
                end
                return game.real_time
            end
        },
        next = next,
        error = error,
        assert = assert,
        pcall = pcall,
        xpcall = xpcall,
        tonumber = tonumber,
        coroutine = coroutine,
        unpack = unpack,
        table = table,
        getmetatable = getmetatable,
        setmetatable = setmetatable,
        type = type,
        string = string,
        ipairs = ipairs,
        pairs = pairs,
        print = print,
        -- allowing manual random seed setting, the randomseed calls will be recorded in the replay in order (with their seed) (TODO)
        math = math,
    }
    env = lua_runtime.env
    env._G = env
    local function make_get_set_functions(tbl, name)
        env["get" .. name .. "ValueInt"] = function(field)
            return utils.round_to_even(tonumber(tbl[field] or 0))
        end
        env["get" .. name .. "ValueFloat"] = function(field)
            return tonumber(tbl[field] or 0)
        end
        env["get" .. name .. "ValueString"] = function(field)
            local value = tbl[field] or ""
            local str = tostring(value)
            -- fix float to string conversion expecting 0 after dot
            if type(value) == "number" and str:match("[.]") then
                return str .. "0"
            else
                return str
            end
        end
        env["get" .. name .. "ValueBool"] = function(field)
            return tbl[field] or false
        end
        env["set" .. name .. "ValueInt"] = function(field, value)
            tbl[field] = utils.round_to_even(value)
        end
        env["set" .. name .. "ValueFloat"] = function(field, value)
            tbl[field] = value
        end
        env["set" .. name .. "ValueString"] = function(field, value)
            tbl[field] = value
        end
        env["set" .. name .. "ValueBool"] = function(field, value)
            tbl[field] = value
        end
    end
    make_get_set_functions(game.level_data, "Level")
    make_get_set_functions(game.style.get_table(), "Style")
    env.log = function(text)
        log("Lua: " .. text)
    end
    env.wall = function(side, thickness)
        game.main_timeline:append_do(function()
            game.walls.wall(side, thickness)
        end)
    end
    env.getSides = function()
        return game.level_data.sides
    end
    env.getSpeedMult = function()
        return game.level_data.speed_multiplier * math.pow(game.difficulty_mult, 0.65)
    end
    env.getDelayMult = function()
        return game.level_data.delay_multiplier * math.pow(game.difficulty_mult, 0.1)
    end
    env.getDifficultyMult = function()
        return game.difficulty_mult
    end
    env.execScript = function(script)
        lua_runtime.run_lua_file(pack.path .. "Scripts/" .. script)
    end
    env.execEvent = function(id)
        game.events.exec(game.pack.events[id])
    end
    env.enqueueEvent = function(id)
        game.events.queue(game.pack.events[id])
    end
    env.wait = function(duration)
        game.main_timeline:append_wait(duration)
    end
    env.playSound = function(id)
        play_sound(game.assets.get_pack_sound(game.pack, id))
    end
    env.forceIncrement = function()
        game.incrementDifficulty()
    end
    local function add_message(message, duration)
        game.message_timeline:append_do(function()
            play_sound(game.assets.get_sound("beep.ogg"))
            game.message_text = message
        end)
        game.message_timeline:append_wait(duration)
        game.message_timeline:append_do(function()
            game.message_text = nil
        end)
    end
    env.messageAdd = function(message, duration)
        if config.get("messages") and game.first_play then
            add_message(message, duration)
        end
    end
    env.messageImportantAdd = function(message, duration)
        if config.get("messages") then
            add_message(message, duration)
        end
    end
    env.isKeyPressed = function(key_code)
        local key = keycode_conversion[key_code]
        if key == nil then
            --lua_runtime.error("No suitable keycode conversion found for '" .. key_code .. "'")
            return false
        end
        key_count = key_count + 1
        if key_count > block_threshold then
            -- blocking loop like `while not isKeyPressed("left") do ...`
            game.blocked = true
            public.real_game_loop()
            game.blocked = false
        end
        return love.keyboard.isDown(key)
    end
    env.isFastSpinning = function()
        return game.status.fast_spin > 0
    end
    env.wallAdj = function(side, thickness, speed)
        game.main_timeline:append_do(function()
            game.walls.wallAdj(side, thickness, speed)
        end)
    end
    env.wallAcc = function(side, thickness, speed, accel, min, max)
        game.main_timeline:append_do(function()
            game.walls.wallAcc(side, thickness, speed, accel, min, max)
        end)
    end
    log("initialized environment")
end

local function run_fn(name, ...)
    return env[name](...)
end

function lua_runtime.run_fn_if_exists(name, ...)
    clock_count = 0
    key_count = 0
    if env[name] ~= nil then
        xpcall(run_fn, lua_runtime.error, name, ...)
    end
end

function lua_runtime.run_lua_file(path)
    if env == nil then
        error("attempted to load a lua file without initializing the environment")
    else
        if file_cache[path] == nil then
            local error_msg
            file_cache[path], error_msg = love.filesystem.load(utils.get_real_path(path))
            if file_cache[path] == nil then
                error("Failed to load '" .. path .. "': " .. error_msg)
            end
        end
        local lua_file = file_cache[path]
        setfenv(lua_file, env)
        lua_file()
    end
end

return lua_runtime
