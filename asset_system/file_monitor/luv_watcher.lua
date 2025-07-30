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

local existed = {}

---watch files (called on loop), calls index.changed on file changes
---@param file_list table
return function(file_list)
    for i = 1, #file_list do
        local path = file_list[i]
        local is_first_time = event_handles[path] == nil
        event_handles[path] = event_handles[path] or uv.new_fs_event()
        -- the file path of a handle is nil if it has been stopped or not started yet
        if event_handles[path]:getpath() == nil then
            if love.filesystem.getRealDirectory(path) == love.filesystem.getSaveDirectory() then
                -- is in save directory
                event_handles[path]:start(love.filesystem.getSaveDirectory() .. "/" .. path, {}, get_callback(path))
            else
                -- is outside save directory
                event_handles[path]:start(path, {}, get_callback(path))
            end

            -- poll for file existing if handle path stays nil
            local exists = love.filesystem.exists(path)
            if not is_first_time and existed[path] == false and exists then
                -- file went from not existing to existing
                -- reattaching handle does not call callback, so do it here
                log("File changed", path)
                index.changed(path)
            end
            existed[path] = exists
        end
    end
    uv.sleep(100)
    uv.run("nowait")
end
