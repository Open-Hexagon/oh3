local log = require("log")(...)
local threadify = require("threadify")
local index = threadify.require("asset_system.index")
local uv = require("luv")

local event_handles = {}

local function get_callback(path)
    return function(err, filename)
        if err then
            -- I have never seen that happen, so not sure what could go wrong here
            log("Error watching", filename, err)
        else
            log("File changed", path)
            index.changed(path)
        end
        -- since some editors move the file when saving (idk why)
        -- the handle has to be recreated every time in case the inode of the file changed
        -- (not sure about backends other than inotify)
        event_handles[path]:stop()
    end
end

---watch files (called on loop), calls index.changed on file changes
---@param file_list table
return function(file_list)
    for i = 1, #file_list do
        local name = file_list[i]
        event_handles[name] = event_handles[name] or uv.new_fs_event()
        -- the file path of a handle is nil if it has been stopped or not started yet
        if event_handles[name]:getpath() == nil then
            if love.filesystem.getRealDirectory(name) == love.filesystem.getSaveDirectory() then
                -- is in save directory
                event_handles[name]:start(love.filesystem.getSaveDirectory() .. "/" .. name, {}, get_callback(name))
            else
                -- is outside save directory
                event_handles[name]:start(name, {}, get_callback(name))
            end
        end
    end
    uv.sleep(100)
    uv.run("nowait")
end
