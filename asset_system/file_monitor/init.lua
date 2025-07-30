local log = require("log")(...)
local impl
if pcall(function()
    require("luv")
end) then
    log("luv backend is available for hot reloading")
    impl = require("asset_system.file_monitor.luv_watcher")
else
    log("luv backend is not available for hot reloading, will fall back to polling")
    impl = require("asset_system.file_monitor.poll_watcher")
end

local watcher = {}

local watching = false
local path_filter = nil
local filtered_list = {}
local file_list = {}

---start watching files while optionally filtering for the beginning of the path
---@param filter string?
function watcher.start(filter)
    path_filter = filter
    if filter then
        filtered_list = {}
        for i = 1, #file_list do
            local name = file_list[i]
            if name:find(filter) == 1 then
                filtered_list[#filtered_list + 1] = name
            end
        end
    else
        filtered_list = file_list
    end
    watching = true
    while watching do
        impl(filtered_list)
        -- has to be non-blocking so new files can be added while watching
        coroutine.yield()
    end
end
watcher.start_co = true

---stop watching
function watcher.stop()
    watching = false
end

---add a file to watch
---@param path string
function watcher.add(path)
    file_list[#file_list + 1] = path
    if path_filter and path:find(path_filter) == 1 then
        filtered_list[#filtered_list + 1] = path
    end
end

local function remove(t, e)
    for i = 1, #t do
        if t[i] == e then
            table.remove(t, i)
            return
        end
    end
end

---remove a file from watcher
---@param path string
function watcher.remove(path)
    remove(file_list, path)
    if path_filter and path:find(path_filter) == 1 then
        remove(filtered_list, path)
    end
end

return watcher
