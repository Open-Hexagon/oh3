local json = require("extlibs.json.json")
local mirror_server = require("asset_system.mirror_server")
require("love.timer")
local index = {}

-- this is the real global index
local assets = {} -- using internal ids
local mirrored_assets = {} -- using given asset keys

-- expose mirror register functions (see mirror_server.lua for function descriptions)
function index.register_mirror()
    return mirror_server.register_mirror(mirrored_assets)
end

function index.unregister_mirror()
    mirror_server.unregister_mirror()
end

-- used to get asset ids from resource id, as well as a resource's remove function
local resource_watch_map = {}

-- used to check which asset is causing the loading of another asset to infer dependencies
local loading_stack = {}
local loading_stack_index = 0

---puts an asset on the stack and calls its loader
---@param asset any
local function load_asset(asset)
    -- push asset id to loading stack
    loading_stack_index = loading_stack_index + 1
    loading_stack[loading_stack_index] = asset.id

    -- back up and clear resource ids
    local resources = asset.resources
    asset.resources = {}

    -- load the asset
    asset.value = asset.loader_function(unpack(asset.arguments))

    -- resource removals (additions happen directly in index.watch)
    for resource_id in pairs(resources) do
        if not asset.resources[resource_id] then
            -- resource got removed
            local ids = resource_watch_map[resource_id]
            ids[asset.id] = nil
            -- call remove function if ids only has the element at 1 left
            if next(ids, next(ids)) == nil and ids[1] then
                ids[1](resource_id)
            end
        end
    end

    -- pop asset id from loading stack
    loading_stack_index = loading_stack_index - 1

    -- only mirror after loading if there is a key
    if asset.key then
        mirror_server.schedule_sync(asset)
    end
end


---get loader function based on loader string
---@param loader string
---@return function
local function get_loader_function(loader)
    local modname = loader:match("(.*)%.")
    local module = modname and require("asset_system.loaders." .. modname) or require("asset_system.loaders")
    local funname = loader:match(".*%.(.*)") or loader
    local loader_function = module[funname]
    if not loader_function then
        error(("Could not find loader '%s'"):format(loader))
    end
    return loader_function
end

---generates a unique asset id based on the loader and the parameters
---@param loader string
---@param ... unknown
---@return string
local function generate_asset_id(loader, ...)
    local t = { loader, ... }
    local info = debug.getinfo(get_loader_function(loader))
    if not info.isvararg and info.nparams < select("#", ...) then
        for i = #t, info.nparams + 1, -1 do
            t[i] = nil
        end
    end
    return json.encode(t)
end

---request an asset to be loaded and mirrored into the index
---(mirroring only happens for this asset if a key is given)
---@param key string?
---@param loader string
---@param ... unknown
function index.request(key, loader, ...)
    -- put asset in index if not already there
    local id = generate_asset_id(loader, ...)
    assets[id] = assets[id]
        or {
            loader_function = get_loader_function(loader),
            arguments = { ... },
            has_as_dependency = {},
            resources = {},
            id = id,
        }
    local asset = assets[id]

    -- if a key is given set the asset to use it and make sure it doesn't already have another one
    if key then
        if asset.key then
            assert(asset.key == key, "requested the same asset with a different key")
        else
            asset.key = key
            mirrored_assets[key] = asset
            if asset.value then
                -- newly requested with key and already loaded, so should mirror
                -- since it is otherwise only done when loading
                mirror_server.schedule_sync(asset)
            end
        end
    end

    -- if asset is requested from another loader the other one has this one as dependency
    if loading_stack_index > 0 then
        local caller = loading_stack[loading_stack_index]
        asset.has_as_dependency[caller] = true
    end

    -- only load if the asset is not already loaded
    if not asset.value then
        load_asset(asset)
    end

    -- mirror all pending assets once at the end of the initial request
    if loading_stack_index == 0 then
        mirror_server.sync_pending_assets()
    end
end

---same as request but returns the asset's value (for use in loaders)
---also leaves the key as nil, since it's only used in this thread
---@param loader string
---@param ... unknown
---@return unknown
function index.local_request(loader, ...)
    index.request(nil, loader, ...)
    return assets[generate_asset_id(loader, ...)].value
end

---traverses the asset dependency tree without duplicates
---returns a sequence of asset ids in the correct order
---@param asset_ids table
---@return table
local function reload_traverse(asset_ids)
    local plan = {}
    repeat
        local next_assets = {}
        for dependee in pairs(asset_ids) do
            if type(dependee) == "string" then -- ignore other table content
                for new_dependee in pairs(assets[dependee].has_as_dependency) do
                    next_assets[new_dependee] = true
                end
                for i = #plan, 1, -1 do
                    if plan[i] == dependee then
                        table.remove(plan, i)
                    end
                end
                plan[#plan + 1] = dependee
            end
        end
        asset_ids = next_assets
    until not next(asset_ids)
    return plan
end

---reloads an asset, using either its id or key
---@param id_or_key string
function index.reload(id_or_key)
    local asset = mirrored_assets[id_or_key] or assets[id_or_key]
    load_asset(asset)

    -- reload assets that depend on this one
    local plan = reload_traverse(asset.has_as_dependency)
    for i = 1, #plan do
        load_asset(assets[plan[i]])
    end

    -- mirror all pending assets once at the end of the initial reload
    mirror_server.sync_pending_assets()
end

---watch any external resource, the id has to be unique
---@param resource_id string
---@param watch_add function?
---@param watch_del function?
function index.watch(resource_id, watch_add, watch_del)
    if loading_stack_index <= 0 then
        error("cannot register resource watcher outside of asset loader")
    end
    local asset_id = loading_stack[loading_stack_index]
    assets[asset_id].resources[resource_id] = true
    if resource_watch_map[resource_id] then
        local ids = resource_watch_map[resource_id]
        ids[asset_id] = true
        return false
    end
    resource_watch_map[resource_id] = { watch_del, [asset_id] = true }
    if watch_add then
        watch_add(resource_id)
    end
end

---notify asset index of changes in an external resource
---@param resource_id string
function index.changed(resource_id)
    if resource_watch_map[resource_id] then
        -- reload assets that depend on this the resource
        local plan = reload_traverse(resource_watch_map[resource_id])
        for i = 1, #plan do
            load_asset(assets[plan[i]])
        end
        mirror_server.sync_pending_assets()
    end
end

local threadify = require("threadify")
local watcher = threadify.require("asset_system.file_monitor")

---adds the specified file as dependency for the currently loading asset
---@param path string
function index.watch_file(path)
    index.watch(path, watcher.add, watcher.remove)
end

return index
