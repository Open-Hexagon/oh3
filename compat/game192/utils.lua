local ffi = require("ffi")
local utils = {}

-- fixes case insensitive paths
function utils.get_real_path(path)
    -- remove trailing spaces
    while path:sub(-1) == " " do
        path = path:sub(1, -2)
    end

    -- fix capitalization
    local real_path = ""
    for segment in path:gmatch("[^/]+") do
        if love.filesystem.getInfo(real_path .. segment) then
            real_path = real_path .. segment .. "/"
        else
            local list = love.filesystem.getDirectoryItems(real_path)
            for i = 1, #list do
                if list[i]:upper() == segment:upper() then
                    real_path = real_path .. list[i] .. "/"
                    break
                end
            end
        end
    end
    real_path = real_path:sub(1, -2)
    return real_path
end

-- insert a path into a recursive table structure
function utils.insert_path(t, keys, value)
    local directory = t
    for i = 1, #keys do
        local key = keys[i]
        if directory[key] == nil then
            if i == #keys then
                directory[key] = value
                return
            end
            directory[key] = {}
        end
        directory = directory[key]
    end
end

-- lookup the item at the end of a path inside a recursive table structure
function utils.lookup_path(t, keys)
    local directory = t
    for _, key in pairs(keys) do
        if directory[key] == nil then
            return
        end
        directory = directory[key]
    end
    return directory
end

function utils.round_to_even(num)
    if num == nil then
        return 0
    end
    -- TODO: return math.floor(num) on some packs depending on target platform?
    local decimal = num % 1
    if decimal ~= 0.5 then
        return math.floor(num + 0.5)
    else
        if num % 2 == 0.5 then
            return num - 0.5
        else
            return num + 0.5
        end
    end
end

function utils.float_round(num)
    return tonumber(ffi.new("float", num))
end

-- This is quite messy since it's copied from 1.92
function utils.get_color_from_hue(hue, color)
    hue = utils.float_round(hue)
    local s, v, r, g, b = 1, 1, 0, 0, 0
    local i = math.floor(hue * 6)
    local f = hue * 6 - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    local im
    if i >= 0 then
        im = i % 6
    else
        im = -(i % 6)
    end
    if im == 0 then
        r, g, b = v, t, p
    elseif im == 1 then
        r, g, b = q, v, p
    elseif im == 2 then
        r, g, b = p, v, t
    elseif im == 3 then
        r, g, b = p, q, v
    elseif im == 4 then
        r, g, b = t, p, v
    elseif im == 5 then
        r, g, b = v, p, q
    end
    color[1] = math.modf(r * 255)
    color[2] = math.modf(g * 255)
    color[3] = math.modf(b * 255)
    color[4] = 255
end

return utils
