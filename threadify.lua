local log = require("log")("threadify")
local modname, is_thread = ...

if is_thread then
    local api = require(modname)
    local in_channel = love.thread.getChannel(modname .. "_cmd")
    local out_channel = love.thread.getChannel(modname .. "_out")
    local run = true
    local running_coroutines = {}
    while run do
        local cmd
        if #running_coroutines > 0 then
            cmd = in_channel:demand(0.01)
        else
            cmd = in_channel:demand()
        end
        if cmd then
            local call_id = cmd[1]
            xpcall(function()
                local fn = api[cmd[2]]
                if api[cmd[2] .. "_co"] then
                    -- coroutine
                    local co = coroutine.create(fn)
                    local _, ret = coroutine.resume(co, unpack(cmd, 3))
                    if coroutine.status(co) == "dead" then
                        out_channel:push({ call_id, true, ret })
                    else
                        running_coroutines[#running_coroutines + 1] = { call_id, cmd[2], co }
                    end
                else
                    -- normal function
                    out_channel:push({ call_id, true, fn(unpack(cmd, 3)) })
                end
            end, function(err)
                out_channel:push({ call_id, false, "Failed to call '" .. modname .. "." .. cmd[2] .. "'", err })
            end)
        else
            for i = #running_coroutines, 1, -1 do
                local call_id, name, co = unpack(running_coroutines[i])
                xpcall(function()
                    local _, ret = coroutine.resume(co)
                    if coroutine.status(co) == "dead" then
                        table.remove(running_coroutines, i)
                        out_channel:push({ call_id, true, ret })
                    end
                end, function(err)
                    table.remove(running_coroutines, i)
                    out_channel:push({ call_id, false, "Failed to call '" .. modname .. "." .. name .. "'", err })
                end)
            end
        end
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
            }
            threads_channel:performAtomic(function(channel)
                local all_threads = channel:pop() or {}
                if all_threads and all_threads[require_string] then
                    thread_table.thread = all_threads[require_string]
                else
                    thread_table.thread = love.thread.newThread("threadify.lua")
                end
                if not thread_table.thread:isRunning() then
                    thread_table.thread:start(require_string, true)
                end
                all_threads[require_string] = thread_table.thread
                channel:push(all_threads)
            end)
            thread_names[#thread_names + 1] = require_string
            threads[require_string] = thread_table
        end
        local thread = threads[require_string]
        local interface = {}
        return setmetatable(interface, {
            __index = function(_, key)
                return function(...)
                    local msg = { -1, key, ... }
                    return async.promise:new(function(resolve, reject)
                        local id_channel = love.thread.getChannel(require_string .. "_ids")
                        local cmd_channel = love.thread.getChannel(require_string .. "_cmd")
                        -- get a request id with no duplicates across any other threads
                        local request_id = 1
                        id_channel:performAtomic(function(channel)
                            local used_ids = channel:pop() or {}
                            repeat
                                local not_used = true
                                for i = 1, #used_ids do
                                    if used_ids[i] == request_id then
                                        not_used = false
                                        request_id = request_id + 1
                                        break
                                    end
                                end
                            until not_used
                            used_ids[#used_ids + 1] = request_id
                            channel:push(used_ids)
                        end)
                        msg[1] = request_id
                        thread.resolvers[request_id] = resolve
                        thread.rejecters[request_id] = reject
                        cmd_channel:push(msg)
                    end)
                end
            end,
        })
    end

    function threadify.update()
        for i = 1, #thread_names do
            local require_string = thread_names[i]
            local thread = threads[require_string]
            local out_channel = love.thread.getChannel(require_string .. "_out")
            local result
            local check_result = out_channel:peek()
            if check_result then
                if thread.resolvers[check_result[1]] and thread.rejecters[check_result[1]] then
                    result = out_channel:pop()
                end
            end
            if result then
                if result[2] then
                    thread.resolvers[result[1]](unpack(result, 3))
                else
                    log(result[3])
                    thread.rejecters[result[1]](result[4])
                end
                thread.resolvers[result[1]] = nil
                thread.rejecters[result[1]] = nil
                -- remove id from used id table for this thread
                local id_channel = love.thread.getChannel(require_string .. "_ids")
                id_channel:performAtomic(function(channel)
                    local used_ids = channel:pop() or {}
                    for j = 1, #used_ids do
                        if used_ids[j] == result[1] then
                            table.remove(used_ids, j)
                            break
                        end
                    end
                    channel:push(used_ids)
                end)
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
