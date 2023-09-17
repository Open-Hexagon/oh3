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
            obj.done_callbacks[i](...)
        end
    end, function(...)
        obj.result = { ... }
        obj.executed = true
        for i = 1, #obj.error_callbacks do
            obj.error_callbacks[i](...)
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
            callback(unpack(self.result))
        end
        return
    end
    self.done_callbacks[#self.done_callbacks + 1] = callback
    return self
end

function promise:err(callback)
    if self.executed then
        if not self.resolved then
            callback(unpack(self.result))
        end
        return
    end
    self.error_callback[#self.error_callback + 1] = callback
    return self
end

local async = setmetatable({}, {
    __call = function(_, fn)
        return function(...)
            local args = { ... }
            return promise:new(function(resolve, reject)
                local co = coroutine.create(function()
                    local ret = { xpcall(fn, reject, unpack(args)) }
                    if ret[1] then
                        resolve(unpack(ret, 2))
                    end
                end)
                coroutine.resume(co)
            end)
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
