local log = require("log")(...)
local threadify = require("threadify")
local index = threadify.require("asset_system.index")
local uv = require("luv")

local file_list = {}
local event_handles = {}

local watcher = {}
local watching = false

local function get_callback(path)
    return function(err, filename)
        if err then
            -- I have never seen that happen, so not sure what could go wrong here
            log("Error watching", filename, err)
        else
            index.changed(path)
        end
        -- since some editors move the file when saving (idk why)
        -- the handle has to be recreated every time in case the inode of the file changed
        -- (not sure about backends other than inotify)
        event_handles[path]:stop()
    end
end

---start watching files (events are sent to the "file_watch_events" channel)
function watcher.start()
    watching = true
    while watching do
        for i = 1, #file_list do
            local name = file_list[i]
            event_handles[name] = event_handles[name] or uv.new_fs_event()
            -- the file path of a handle is nil if it has been stopped or not started yet
            if event_handles[name]:getpath() == nil then
                event_handles[name]:start(name, {}, get_callback(name))
            end
        end
        -- has to be non-blocking so new files can be added while watching
        uv.run("nowait")
        coroutine.yield()
        uv.sleep(100)
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
