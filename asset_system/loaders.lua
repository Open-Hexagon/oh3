local log = require("log")(...)
local index = require("asset_system.index")
local loaders = {}

local main_thread_tasks = love.thread.getChannel("asset_loading_main_thread_tasks")

---run a task on the main thread
---@param ... string
---@return unknown
local function run_on_main(...)
    main_thread_tasks:supply({ ... })
    return unpack(main_thread_tasks:demand())
end

-- All subsequent functions are loaders, taking any number of love.Variant as arguments and returning love.Variant

function loaders.text_file(path)
    index.watch(path)
    return love.filesystem.read(path)
end

function loaders.image(path)
    index.watch(path)
    return run_on_main("love", "graphics", "newImage", path)
end

function loaders.font(path, size)
    index.watch(path)
    return run_on_main("love", "graphics", "newFont", path, size)
end

function loaders.json(path)
    local json = require("extlibs.json.json")
    local text = index.local_request("text_file", path)
    return json.decode(text)
end

function loaders.icon_font(name, size)
    local path = "assets/font/" .. name
    return {
        font = index.local_request("font", path .. ".ttf", size),
        id_map = index.local_request("json", path .. ".json"),
    }
end

-- set this to true to see the called loaders and their arguments
local loader_debug = true
if loader_debug then
    return setmetatable({}, {
        __index = function(_, key)
            return function(...)
                log("Calling loader", key, "with", ...)
                return loaders[key](...)
            end
        end,
    })
else
    return loaders
end
