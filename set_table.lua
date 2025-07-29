local Set = {}
Set.__index = Set

function Set:new(entries)
    return setmetatable({
        entries = entries or {},
        iter_p = 0,
    }, Set)
end

function Set:add(value)
    if not self.entries[value] then
        local index = #self.entries + 1
        self.entries[index] = value
        self.entries[value] = index
    end
end

function Set:has(value)
    return self.entries[value] and true or false
end

function Set:remove(value)
    local index = self.entries[value]
    if index then
        table.remove(self.entries, index)
        self.entries[value] = nil
    end
end

function Set:__call()
    self.iter_p = self.iter_p + 1
    local ret = self.entries[self.iter_p]
    if ret == nil then
        self.iter_p = 0
    end
    return ret
end

return Set
