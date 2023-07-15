local level = {}

local defaults = {
    id = "nullId",
    name = "nullName",
    description = "",
    author = "",
    menuPriority = 0,
    selectable = true,
    musicId = "nullMusicId",
    styleId = "nullStyleId",
    luaFile = "nullLuaPath",
    difficultyMults = {},
}

function level.set(level_json)
    for key, value in pairs(defaults) do
        level[key] = level_json[key] or value
    end
    local has1 = false
    for i = 1, #level.difficultyMults do
        if level.difficultyMults[i] == 1 then
            has1 = true
            break
        end
    end
    if not has1 then
        level.difficultyMults[#level.difficultyMults + 1] = 1
    end
    table.sort(level.difficultyMults)
end

return level
