local threadify = require("threadify")
local index = threadify.require("asset_system.index")
local mirror = require("asset_system.mirror")
local watcher = threadify.require("asset_system.watcher")

local asset_system = {
    mirror = mirror,
    index = index,
}

local main_thread_tasks = love.thread.getChannel("asset_loading_main_thread_tasks")

---runs functions that only work on the main thread on behalf of the asset loaders
function asset_system.run_main_thread_task()
    local task = main_thread_tasks:pop()
    if task == nil then
        return
    end
    local namespace = _G
    for i = 1, #task do
        local part = task[i]
        if type(namespace[part]) == "function" then
            local ret = { namespace[part](unpack(task, i + 1)) }
            main_thread_tasks:supply(ret)
            break
        else
            namespace = namespace[part]
        end
    end
end

---automatically call index.reload on the correct assets based on file changes
---(note that in case luv is not available this will fall back to polling)
function asset_system.start_hot_reloading()
    watcher.start()
end

---don't automatically call index.reload on the correct assets based on file changes
function asset_system.stop_hot_reloading()
    watcher.stop()
end

return asset_system
