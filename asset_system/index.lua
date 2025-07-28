local json = require("extlibs.json.json")
local mirror_server = require("asset_system.mirror_server")
local utils = require("asset_system.utils")
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

-- used to check which asset is causing the loading of another asset to infer dependencies
local loading_stack = {}
local loading_stack_index = 0

---generates a unique asset id based on the loader and the parameters
---may also return a second value used to detect argument changes for the same asset
---@param loader string
---@param ... unknown
---@return string
---@return string?
local function generate_asset_id(loader, ...)
    return json.encode({ loader, ... })
end

---puts an asset on the stack and calls its loader
---@param asset any
local function load_asset(asset)
    -- push asset id to loading stack
    loading_stack_index = loading_stack_index + 1
    loading_stack[loading_stack_index] = asset.id

    -- load the asset
    asset.value = asset.loader_function(unpack(asset.arguments))

    -- pop asset id from loading stack
    loading_stack_index = loading_stack_index - 1

    -- only mirror after loading if there is a key
    if asset.key then
        mirror_server.schedule_sync(asset)
    end
end

---request an asset to be loaded and mirrored into the index
---(mirroring only happens for this asset if a key is given)
---@param key string?
---@param loader string
---@param ... unknown
function index.request(key, loader, ...)
    local id = generate_asset_id(loader, ...)
    assets[id] = assets[id]
        or {
            loader_function = require("asset_system.loaders")[loader],
            arguments = { ... },
            has_as_dependency = {},
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
        utils.add_to_array_if_not_present(caller, asset.has_as_dependency)
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

local reload_depth = 0

---reloads an asset, using either its id or key
---@param id_or_key string
function index.reload(id_or_key)
    local asset = mirrored_assets[id_or_key] or assets[id_or_key]
    asset.value = nil

    load_asset(asset)

    -- reload assets that depend on this one
    reload_depth = reload_depth + 1
    for i = 1, #asset.has_as_dependency do
        index.reload(asset.has_as_dependency[i])
    end
    reload_depth = reload_depth - 1

    -- mirror all pending assets once at the end of the initial reload
    if reload_depth == 0 then
        mirror_server.sync_pending_assets()
    end
end

return index
