local Timeline = require("compat.game21.timeline")
local timelines = {}
local custom_timelines = {}

function custom_timelines.reset()
    timelines = {}
end

function custom_timelines.get(id)
    if timelines[id] == nil then
        error("Invalid custom timeline '" .. id .. "'")
    end
    return timelines[id]
end

function custom_timelines.update(time_point)
    for i = 1, #timelines do
        local timeline = timelines[i]
        if timeline:update(time_point) then
            timeline:clear()
        end
    end
end

function custom_timelines.add_lua_functions(game)
    local lua = game.lua_runtime.env

    function lua.ct_create()
        timelines[#timelines + 1] = Timeline:new()
        return #timelines
    end

    function lua.ct_eval(handle, code)
        local timeline = custom_timelines.get(handle)
        local fn = loadstring(code)
        setfenv(fn, game.lua_runtime.env)
        timeline:append_do(fn)
    end

    function lua.ct_kill(handle)
        local timeline = custom_timelines.get(handle)
        timeline:append_do(function()
            game:death(true)
        end)
    end

    function lua.ct_stopTime(handle, duration)
        local timeline = custom_timelines.get(handle)
        timeline:append_do(function()
            game.status.pause_time(duration / 60)
        end)
    end

    function lua.ct_stopTimeS(handle, duration)
        local timeline = custom_timelines.get(handle)
        timeline:append_do(function()
            game.status.pause_time(duration)
        end)
    end

    function lua.ct_wait(handle, duration)
        local timeline = custom_timelines.get(handle)
        timeline:append_wait_for_sixths(duration)
    end

    function lua.ct_waitS(handle, duration)
        local timeline = custom_timelines.get(handle)
        timeline:append_wait_for_seconds(duration)
    end

    function lua.ct_waitUntilS(handle, time)
        local timeline = custom_timelines.get(handle)
        timeline:append_wait_until_fn(function()
            return game.status.get_level_start_tp() + time * 1000
        end)
    end
end

return custom_timelines
