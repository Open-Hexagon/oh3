local index = require("asset_system.index")

local sound_mapping = {
    ["beep.ogg"] = "click.ogg",
    ["difficultyMultDown.ogg"] = "difficulty_mult_down.ogg",
    ["difficultyMultUp.ogg"] = "difficulty_mult_up.ogg",
    ["gameOver.ogg"] = "game_over.ogg",
    ["levelUp.ogg"] = "level_up.ogg",
    ["openHexagon.ogg"] = "open_hexagon.ogg",
    ["personalBest.ogg"] = "personal_best.ogg",
    ["swapBlip.ogg"] = "swap_blip.ogg",
}
local audio_path = "assets/audio/"

local loaders = {}

function loaders.sound(name)
    name = sound_mapping[name] or name
    local path = audio_path .. name
    if love.filesystem.exists(path) then
        return index.local_request("sound_data", path)
    end
end

function loaders.all_game_sounds()
    index.watch_file(audio_path)
    local items = love.filesystem.getDirectoryItems(audio_path)
    local result = {}
    for i = 1, #items do
        result[items[i]] = index.local_request("compat.sound", items[i])
    end
    for k, v in pairs(sound_mapping) do
        result[k] = result[v]
    end
    return result
end

return loaders
