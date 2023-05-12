local level = {}

local default_values = {
    pulse_min = 75,
    pulse_max = 80,
    radius_min = 72,
}
local tmp_values = {}
local current_data

function level.set(level_data)
    for k, _ in pairs(tmp_values) do
        tmp_values[k] = nil
    end
    current_data = setmetatable(tmp_values, {
        __index = function(_, k)
            return level_data[k] or (default_values[k] or 0)
        end
    })
    return current_data
end

function level.get_difficulty_multipliers()
    local mults = current_data.difficulty_multipliers or {1}
    if #mults == 0 then
        return {1}
    else
        return mults
    end
end

function level.set_value(name, value)
    current_data[name] = value
end

function level.get_value(name)
    return current_data[name]
end

return level
