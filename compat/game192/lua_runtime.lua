local log = require("log")(...)
local lua_runtime = {
    env = {},
}

local error_sound
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
    [54] = "~",
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
    [100] = "pause"
}

function lua_runtime.error(msg)
    log("Error: " .. msg)
end

function lua_runtime.init_env(game)
    local pack = game.pack
    lua_runtime.env = {
        os = {
            time = function(...)
                return os.time(...)
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
    env.execScript = function(script)
        lua_runtime.run_lua_file(pack.path .. "Scripts/" .. script)
    end
    env.getDifficultyMult = function()
        return game.difficulty_mult
    end
    log("initialized environment")
end

local function run_fn(name, ...)
    return env[name](...)
end

function lua_runtime.run_fn_if_exists(name, ...)
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
            file_cache[path], error_msg = love.filesystem.load(path)
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
