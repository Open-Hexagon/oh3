local utils = {}
local main_thread_tasks = love.thread.getChannel("asset_loading_main_thread_tasks")

---run a task on the main thread
---@param code string
---@param ... unknown
---@return unknown
function utils.run_on_main(code, ...)
    main_thread_tasks:supply({ code, ... })
    return unpack(main_thread_tasks:demand())
end

return utils
