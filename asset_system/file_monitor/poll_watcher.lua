local threadify = require("threadify")
local index = threadify.require("asset_system.index")
require("love.timer")

local last_infos = {}

---watch files (called on loop), calls index.changed on file changes
---@param file_list table
return function(file_list)
    for i = 1, #file_list do
        local name = file_list[i]
        local info = love.filesystem.getInfo(name)
        if last_infos[name] then
            local last_info = last_infos[name]
            if info.modtime > last_info.modtime or info.size ~= last_info.size or info.type ~= last_info.type then
                index.changed(name)
            end
        end
        last_infos[name] = info
    end
    love.timer.sleep(1)
end
