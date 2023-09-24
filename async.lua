-- small async implementation using coroutines to suspend a function awaiting a callback
local promise = {}
promise.__index = promise

function promise:new(fn)
    local obj = setmetatable({
        done_callbacks = {},
        error_callbacks = {},
        executed = false,
        result = nil,
        resolved = false,
    }, promise)
    fn(function(...)
        obj.resolved = true
        obj.result = { ... }
        obj.executed = true
        for i = 1, #obj.done_callbacks do
            xpcall(obj.done_callbacks[i], function(err)
                print("Error in done callback: ", err)
                error("Uncaught error in done callback of promise")
            end, ...)
        end
    end, function(...)
        obj.result = { ... }
        obj.executed = true
        for i = 1, #obj.error_callbacks do
            xpcall(obj.error_callbacks[i], function(err)
                print("During the handling of: ", unpack(obj.result))
                print("another error occured: ", err)
                error("Uncaught error in done callback of promise")
            end, ...)
        end
        if #obj.error_callbacks == 0 then
            print("Error: ", ...)
            error("Uncaught error in promise")
        end
    end)
    return obj
end

function promise:done(callback)
    if self.executed then
        if self.resolved then
            xpcall(callback, function(err)
                print("Error in done callback: ", err)
                error("Uncaught error in done callback of promise")
            end, unpack(self.result))
        end
        return
    end
    self.done_callbacks[#self.done_callbacks + 1] = callback
    return self
end

function promise:err(callback)
    if self.executed then
        if not self.resolved then
            xpcall(callback, function(err)
                print("During the handling of: ", unpack(self.result))
                print("another error occured: ", err)
                error("Uncaught error in promise")
            end, unpack(self.result))
        end
        return
    end
    self.error_callbacks[#self.error_callbacks + 1] = callback
    return self
end

local async = setmetatable({}, {
    __call = function(_, fn)
        return function(...)
            local args = { ... }
            local prom = promise:new(function(resolve, reject)
                local co = coroutine.create(function()
                    local ret = { xpcall(fn, reject, unpack(args)) }
                    if ret[1] then
                        resolve(unpack(ret, 2))
                    end
                end)
                coroutine.resume(co)
            end)
            if prom.executed and not prom.resolved and #prom.error_callbacks == 0 then
                error("Uncaught error in promise: " .. prom.result[1])
            end
            return prom
        end
    end,
})

async.await = function(prom)
    if prom.executed then
        return unpack(prom.result)
    end
    local co = coroutine.running()
    if not co then
        error("cannot await outide of an async function")
    end
    prom:done(function(...)
        coroutine.resume(co, ...)
    end)
    return coroutine.yield()
end

async.promise = promise

return async
