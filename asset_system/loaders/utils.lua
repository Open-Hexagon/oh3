local utils = {}
local main_thread_tasks = love.thread.getChannel("asset_loading_main_thread_tasks")

---run a task on the main thread
---@param ... string
---@return unknown
function utils.run_on_main(...)
    main_thread_tasks:supply({ ... })
    return unpack(main_thread_tasks:demand())
end

return utils
