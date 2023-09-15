local log = require("log")("threadify")
local modname, is_thread = ...

if is_thread then
    local api = require(modname)
    local run = true
    while run do
        local cmd = love.thread.getChannel(modname .. "_cmd"):demand()
        local call_id = cmd[1]
        local out_channel = love.thread.getChannel(modname .. "_out")
        xpcall(function()
            local fn = api[cmd[2]]
            out_channel:push({ call_id, true, fn(unpack(cmd, 3)) })
        end, function(err)
            out_channel:push({ call_id, false, "Failed to call '" .. modname .. "." .. cmd[2] .. "'", err })
        end)
    end
else
    local async = require("async")
    local threads = {}
    local thread_names = {}
    local threadify = {}
    local threads_channel = love.thread.getChannel("threads")

    function threadify.require(require_string)
        if not threads[require_string] then
            local thread_table = {
                resolvers = {},
                rejecters = {},
                free_indices = {},
            }
            local global_threads = threads_channel:peek()
            if global_threads and global_threads[require_string] then
                thread_table.thread = global_threads[require_string]
            else
                thread_table.thread = love.thread.newThread("threadify.lua")
            end
            thread_table.thread:start(require_string, true)
            threads[require_string] = thread_table
            thread_names[#thread_names + 1] = require_string
            threads_channel:performAtomic(function(channel, thread_object, module_name)
                local all_threads = channel:pop() or {}
                all_threads[module_name] = thread_object
                channel:push(all_threads)
            end, thread_table.thread, require_string)
        end
        local thread = threads[require_string]
        local interface = {}
        return setmetatable(interface, {
            __index = function(_, key)
                return function(...)
                    local msg = { -1, key, ... }
                    return async.promise:new(function(resolve, reject)
                        local index = 0
                        if #thread.free_indices == 0 then
                            index = #thread.resolvers + 1
                        else
                            local last_index = #thread.free_indices
                            index = thread.free_indices[last_index]
                            thread.free_indices[last_index] = nil
                        end
                        msg[1] = index
                        love.thread.getChannel(require_string .. "_cmd"):push(msg)
                        thread.resolvers[index] = resolve
                        thread.rejecters[index] = reject
                    end)
                end
            end,
        })
    end

    function threadify.update()
        for i = 1, #thread_names do
            local require_string = thread_names[i]
            local thread = threads[require_string]
            local result = love.thread.getChannel(require_string .. "_out"):pop()
            if result then
                if result[2] then
                    thread.resolvers[result[1]](unpack(result, 3))
                else
                    log(result[3])
                    thread.rejecters[result[1]](result[4])
                end
                thread.resolvers[result[1]] = nil
                thread.rejecters[result[1]] = nil
                thread.free_indices[#thread.free_indices + 1] = result[1]
            end
        end
    end

    function threadify.stop()
        for require_string, thread_table in pairs(threads) do
            local thread = thread_table.thread
            if thread:isRunning() then
                -- effectively kills the thread (sending stop doesn't work sometimes and when it does it would still cause unresponsiveness on closing)
                thread:release()
            else
                local err = thread:getError()
                if err then
                    log("Error in '" .. require_string .. "' thread: " .. err)
                end
            end
        end
    end

    return threadify
end
