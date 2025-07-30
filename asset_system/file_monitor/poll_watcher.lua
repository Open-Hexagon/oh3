local log = require("log")(...)
local threadify = require("threadify")
local index = threadify.require("asset_system.index")
require("love.timer")

---get info with directory items or "deleted" if it doesn't exist
---@param path string
---@return table|string
local function get_custom_info(path)
    local info = love.filesystem.getInfo(path)
    if info and info.type == "directory" then
        info.files = love.filesystem.getDirectoryItems(path)
    end
    return info or "deleted"
end

---compare 2 of the infos
---@param new table|string
---@param old table|string
---@return boolean
local function has_changed(new, old)
    if type(new) ~= type(old) then
        return true -- one is deleted
    elseif type(new) == "string" then
        return false -- both deleted
    elseif new.type ~= old.type then
        return true -- file type changed (e.g. no longer directory but file)
    elseif new.type == "directory" then
        for i = 1, math.max(#new.files, #old.files) do
            if new.files[i] ~= old.files[i] then
                return true -- directory content changed
            end
        end
    else
        -- modtime or file size changed
        return new.modtime ~= old.modtime or new.size ~= old.size
    end
    -- nothing changed
    return false
end

local last_infos = {}

---watch files (called on loop), calls index.changed on file changes
---@param file_list table
return function(file_list)
    for i = 1, #file_list do
        local path = file_list[i]
        local info = get_custom_info(path)
        if last_infos[path] then
            if has_changed(info, last_infos[path]) then
                log("File changed", path)
                index.changed(path)
            end
        end
        last_infos[path] = info
    end
    love.timer.sleep(1)
end
