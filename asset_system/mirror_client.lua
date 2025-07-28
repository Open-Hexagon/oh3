local threadify = require("threadify")
local async = require("async")
local index = threadify.require("asset_system.index")
require("love.timer")

local update_channel = love.thread.getChannel("asset_index_updates")
local update_ack_channel = love.thread.getChannel("asset_index_update_acks")

-- thanks to require caching modules this will only be called once per thread
-- in case the mirror was created after some assets are already
-- loaded the promise results in the inital mirror state
local mirror = async.busy_await(index.register_mirror())

local last_id
local asset_callbacks = {}

---updates the contents of the mirror using the asset notifications
function mirror.update()
    local notification = update_channel:peek()
    if notification then
        local id = notification[1]
        -- notifications are only removed from the channel once all mirrors
        -- acked them, so only process it again once the id changes
        if id ~= last_id then
            update_ack_channel:push(id)
            last_id = id
            local key = notification[2]
            local asset = notification[3]
            mirror[key] = asset
            if asset_callbacks[key] then
                asset_callbacks[key](asset)
            end
        end
    end
end

---listen to asset changes, to unregister listener set callback to nil
---@param key string
---@param callback function?
function mirror.listen(key, callback)
    asset_callbacks[key] = callback
end

return mirror
