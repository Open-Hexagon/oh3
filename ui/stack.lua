-- This module holds a stack of all overlays

local list = {}

local stack = {}

function stack.push(mod)
    assert(mod.update)
    assert(mod.draw)
    assert(mod.handle_event)
    list[#list + 1] = mod
end

function stack.pop()
    local len = #list
    list[len] = nil
end

function stack.update(dt)
    for _, v in ipairs(list) do
        v.update(dt)
    end
end

function stack.draw()
    for _, v in ipairs(list) do
        v.draw()
    end
end

function stack.handle_event(name, a, b, c, d, e, f)
    list[#list].handle_event(name, a, b, c, d, e, f)
end

return stack
