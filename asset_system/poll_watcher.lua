local threadify = require("threadify")
local index = threadify.require("asset_system.index")
require("love.timer")

local file_list = {}
local last_infos = {}

local watcher = {}
local watching = false

---start watching files (events are sent to the "file_watch_events" channel)
function watcher.start()
    watching = true
    while watching do
        for i = 1, #file_list do
            local name = file_list[i]
            local info = love.filesystem.getInfo(name)
            if last_infos[name] then
                local last_info = last_infos[name]
                if info.modtime > last_info.modtime or info.size ~= last_info.size or info.type ~= last_info.type then
                    index.changed(name)
                end
            end
            last_infos[name] = info
        end
        -- has to be non-blocking in case files are added while watching
        coroutine.yield()
        love.timer.sleep(1)
    end
end
watcher.start_co = true

---stop watching files
function watcher.stop()
    watching = false
end

---add a file to watch
---@param path string
function watcher.add(path)
    file_list[#file_list + 1] = path
end

return watcher
