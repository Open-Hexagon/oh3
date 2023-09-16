local async = require("async")
local threadify = require("threadify")
local threaded_assets = threadify.require("game_handler.assets")

local assets = {}
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
local audio_module, sound_volume
local cached_packs = {}
local cached_sounds = {}

assets.init = async(function(audio, config)
    audio_module = audio
    sound_volume = config.get("sound_volume")
    if config.get("preload_all_packs") then
        local game_handler = require("game_handler")
        local packs = game_handler.get_packs()
        for i = 1, #packs do
            local pack = packs[i]
            if pack.game_version == 192 then
                cached_packs[pack.id] = async.await(threaded_assets.get_pack(192, pack.id))
            end
        end
    end
end)

assets.get_pack = async(function(folder)
    if not cached_packs[folder] then
        cached_packs[folder] = async.await(threaded_assets.get_pack(192, folder))
    end
    return cached_packs[folder]
end)

function assets.get_sound(id)
    id = sound_mapping[id] or id
    if cached_sounds[id] == nil then
        cached_sounds[id] = audio_module.new_static(audio_path .. id)
        cached_sounds[id].volume = sound_volume
    end
    return cached_sounds[id]
end

function assets.get_pack_sound(pack, id)
    if cached_sounds[id] == nil then
        cached_sounds[id] = audio_module.new_static(pack.path .. "Sounds/" .. id:match("_(.*)"))
        cached_sounds[id].volume = sound_volume
    end
    return cached_sounds[id]
end

return assets
