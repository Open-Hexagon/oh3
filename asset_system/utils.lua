local utils = {}
local main_thread_tasks = love.thread.getChannel("asset_loading_main_thread_tasks")

---run a task on the main thread
---@param ... string
---@return unknown
function utils.run_on_main(...)
    main_thread_tasks:supply({ ... })
    return unpack(main_thread_tasks:demand())
end

---adds a value to an array if it is not present
---@param value unknown
---@param array table
function utils.add_to_array_if_not_present(value, array)
    local already_present = false
    for i = 1, #array do
        if array[i] == value then
            already_present = true
            break
        end
    end
    if not already_present then
        array[#array + 1] = value
    end
end

return utils
