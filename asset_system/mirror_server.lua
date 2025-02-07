local log = require("log")(...)

local mirror_server = {}

-- required to know how many acks to wait for when sending notifications for mirroring
local mirror_count = 0

---register a mirror (to wait for when sending notifications) returns currently loaded assets
---@param mirrored_assets table
---@return table
function mirror_server.register_mirror(mirrored_assets)
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
function mirror_server.unregister_mirror()
    mirror_count = mirror_count - 1
end

-- channels to communicate with mirrors
local update_channel = love.thread.getChannel("asset_index_updates")
local update_ack_channel = love.thread.getChannel("asset_index_update_acks")

-- keep track of notifications which need to be sent once loading stack is empty
local pending_notifications = {}
local pending_notification_count = 0
local notification_id = 0

function mirror_server.schedule_sync(asset)
    pending_notification_count = pending_notification_count + 1
    pending_notifications[pending_notification_count] = { notification_id, asset.key, asset.value }
    notification_id = notification_id + 1
end

function mirror_server.sync_pending_assets()
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

return mirror_server
