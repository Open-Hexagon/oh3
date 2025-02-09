local utils = {}
local main_thread_tasks = love.thread.getChannel("asset_loading_main_thread_tasks")

---run a task on the main thread
---@param ... string
---@return unknown
function utils.run_on_main(...)
    main_thread_tasks:supply({ ... })
    return unpack(main_thread_tasks:demand())
end

---wrap a loader function in a callable table used to indicate which
---parameters cause a reload instead of creating a new asset when changed
---@param param_set table
---@param fun function
---@return table
function utils.reload_filter(param_set, fun)
    local param_indices_map = {}
    for i = 1, debug.getinfo(fun).nparams do
        local name = debug.getlocal(fun, i)
        if param_set[name] then
            param_indices_map[i] = true
        end
    end
    return setmetatable(param_indices_map, {
        __call = function (_, ...)
            return fun(...)
        end
    })
end

return utils
