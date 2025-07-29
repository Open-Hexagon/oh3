local threadify = require("threadify")
local index = threadify.require("asset_system.index")
local mirror = require("asset_system.mirror_client")
local watcher = threadify.require("asset_system.file_monitor")

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
    local ret = { loadstring(task[1])(unpack(task, 2)) }
    main_thread_tasks:push(ret)
end

---automatically call index.reload on the correct assets based on file changes
---(note that in case luv is not available this will fall back to polling)
---the filter can specify a starting path under which all files are monitored
---without one all files that were used are monitored, which with polling could be quite inefficient
---@param filter string?
function asset_system.start_hot_reloading(filter)
    watcher.start(filter)
end

---don't automatically call index.reload on the correct assets based on file changes
function asset_system.stop_hot_reloading()
    watcher.stop()
end

return asset_system
