local db = {}
local thread
local calling_thread

function db.init()
    thread = love.thread.newThread("server/database_thread.lua")
    thread:start()
end

function db.set_identity(thread_id)
    calling_thread = thread_id
end

function db.execute(cmd)
    love.thread.getChannel("db_cmd"):push({calling_thread, unpack(cmd)})
    return love.thread.getChannel("db_out" .. calling_thread):demand()
end

function db.stop()
    if thread:isRunning() then
        love.thread.getChannel("db_cmd"):push({"stop"})
        thread:wait()
    else
        print("error in db thread:\n", thread:getError())
    end
end

return setmetatable(db, {
    __index = function(_, key)
        return function(...)
            return db.execute({key, ...})
        end
    end
})
