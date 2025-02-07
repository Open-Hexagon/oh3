local log = require("log")(...)
local json = require("extlibs.json.json")
require("love.timer")
local index = {}

-- this is the real global index
local assets = {}
local mirrored_assets = {}

-- required to know how many acks to wait for when sending notifications for mirroring
local mirror_count = 0

---register a mirror (to wait for when sending notifications) returns currently loaded assets
---@return table
function index.register_mirror()
    mirror_count = mirror_count + 1
    local new_mirror = {}
    for key, asset in pairs(mirrored_assets) do
        if asset.value then
            new_mirror[key] = asset.value
        end
    end
    return new_mirror
end

---unregister a mirror so the asset thread doesn't wait for it to confirm notifications
---the mirror still has to confirm notifications until the promise is fulfilled (otherwise the asset thread may get stuck)
function index.unregister_mirror()
    mirror_count = mirror_count - 1
end

-- channels to communicate with mirrors
local update_channel = love.thread.getChannel("asset_index_updates")
local update_ack_channel = love.thread.getChannel("asset_index_update_acks")

-- used to check which asset is causing the loading of another asset to infer dependencies
local loading_stack = {}
local loading_stack_index = 0

-- keep track of notifications which need to be sent once loading stack is empty
local pending_notifications = {}
local pending_notification_count = 0
local notification_id = 0

local function add_mirror_notification(asset)
    pending_notification_count = pending_notification_count + 1
    pending_notifications[pending_notification_count] = { notification_id, asset.key, asset.value }
    notification_id = notification_id + 1
end

local function sync_pending_assets()
    for i = 1, pending_notification_count do
        local notification = pending_notifications[i]
        local id = notification[1]
        update_channel:push(notification)
        local acked = 0
        local timer = 0
        while acked < mirror_count do
            local ack_id = update_ack_channel:peek()
            if ack_id and ack_id == id then
                update_ack_channel:pop()
                acked = acked + 1
            end
            love.timer.sleep(0.01)
            timer = timer + 0.01
            if timer > 1 then
                log(string.format("Asset %s is taking an unusual amount of time being mirrored", notification[2]))
                timer = 0
            end
        end
        update_channel:pop()
    end
    pending_notification_count = 0
    -- if notification_id is still 1 then the last notification was sent with 0, so the next one cannot be 0 either
    -- (the id has to change from the last notification for mirrors to register it properly)
    if notification_id - 1 > 0 then
        notification_id = 0
    end
end

---generates a unique asset id based on the loader and the parameters
---@param loader string
---@param ... unknown
---@return string
local function generate_asset_id(loader, ...)
    return json.encode({ loader, ... })
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
    local should_mirror = false

    -- if a key is given set the asset to use it and make sure it doesn't already have another one
    if key then
        if asset.key then
            assert(asset.key == key, "requested the same asset with a different key")
        else
            asset.key = key
            mirrored_assets[key] = asset
            -- newly requested with key, so should mirror even if already loaded
            should_mirror = true
        end
    end

    -- if asset is requested from another loader the other one has this one as dependency
    if loading_stack_index > 0 then
        local caller = loading_stack[loading_stack_index]
        local already_present = false
        for i = 1, #asset.has_as_dependency do
            if asset.has_as_dependency[i] == caller then
                already_present = true
                break
            end
        end
        if not already_present then
            asset.has_as_dependency[#asset.has_as_dependency + 1] = caller
        end
    end

    -- only load if the asset is not already loaded
    if not asset.value then
        -- push asset id to loading stack
        loading_stack_index = loading_stack_index + 1
        loading_stack[loading_stack_index] = id

        -- load the asset
        asset.value = asset.loader_function(unpack(asset.arguments))

        -- pop asset id from loading stack
        loading_stack_index = loading_stack_index - 1

        -- only mirror after loading if there is a key
        if asset.key then
            should_mirror = true
        end
    end

    if should_mirror then
        -- schedule notification for this asset
        add_mirror_notification(asset)
    end

    -- mirror all pending assets once at the end of the initial request
    if loading_stack_index == 0 then
        sync_pending_assets()
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

    -- push asset id to loading stack
    loading_stack_index = loading_stack_index + 1
    loading_stack[loading_stack_index] = asset.id

    -- load the asset
    asset.value = asset.loader_function(unpack(asset.arguments))

    -- pop asset id from loading stack
    loading_stack_index = loading_stack_index - 1

    -- reload assets that depend on this one
    reload_depth = reload_depth + 1
    for i = 1, #asset.has_as_dependency do
        index.reload(asset.has_as_dependency[i])
    end
    reload_depth = reload_depth - 1

    -- schedule notification for this asset if required
    if asset.key then
        add_mirror_notification(asset)
    end

    -- mirror all pending assets once at the end of the initial reload
    if reload_depth == 0 then
        sync_pending_assets()
    end
end

local threadify = require("threadify")
local watcher = threadify.require("asset_system.watcher")
local file_watch_map = {} -- file as key, asset key array as value

---adds the specified file as dependency for the currently loading asset
---@param path string
function index.watch(path)
    if loading_stack_index <= 0 then
        error("cannot register file watcher outside of asset loader")
    end
    local asset_id = loading_stack[loading_stack_index]
    if file_watch_map[path] then
        local ids = file_watch_map[path]
        local already_present = false
        for i = 1, #ids do
            if ids[i] == asset_id then
                already_present = true
                break
            end
        end
        if not already_present then
            ids[#ids + 1] = asset_id
        end
    else
        file_watch_map[path] = { asset_id }
        watcher.add(path)
    end
end

---notify the asset index of a file change
---@param path string
function index.changed(path)
    if file_watch_map[path] then
        local ids = file_watch_map[path]
        for i = 1, #ids do
            index.reload(ids[i])
        end
    end
end

return index
