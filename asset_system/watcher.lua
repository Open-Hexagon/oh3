local impl
if pcall(function()
    require("luv")
end) then
    impl = require("asset_system.luv_watcher")
else
    impl = require("asset_system.poll_watcher")
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

return watcher
