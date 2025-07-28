local utils = require("asset_system.utils")
local index = require("asset_system.index")

local resource_monitor = {}

local resource_watch_map = {}

---watch any external resource, the id has to be unique, returns true if resource has not been watched by any asset before
---@param resource_id string
---@return boolean
function resource_monitor.watch(resource_id)
    if loading_stack_index <= 0 then
        error("cannot register resource watcher outside of asset loader")
    end
    local asset_id = loading_stack[loading_stack_index]
    if resource_watch_map[resource_id] then
        local ids = resource_watch_map[resource_id]
        utils.add_to_array_if_not_present(resource_id, ids)
        return false
    end
    resource_watch_map[resource_id] = { asset_id }
    return true
end

---notify the asset index of changes in an external resource
---@param resource_id string
function resource_monitor.changed(resource_id)
    if resource_watch_map[resource_id] then
        local ids = resource_watch_map[resource_id]
        for i = 1, #ids do
            index.reload(ids[i])
        end
    end
end

local threadify = require("threadify")
local watcher = threadify.require("asset_system.file_monitor")

---adds the specified file as dependency for the currently loading asset
---@param path string
function resource_monitor.watch_file(path)
    if resource_monitor.watch(path) then
        watcher.add(path)
    end
end

return resource_monitor
