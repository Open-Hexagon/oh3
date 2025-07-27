local async = require("async")
local audio = require("audio")
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
local sound_volume
local cached_packs = {}
local cached_sounds = {}
local pending_packs = {}

assets.init = async(function(config)
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
    if pending_packs[folder] then
        async.await(pending_packs[folder])
    elseif not cached_packs[folder] then
        pending_packs[folder] = threaded_assets.get_pack(192, folder)
        cached_packs[folder] = async.await(pending_packs[folder])
    end
    pending_packs[folder] = nil
    return cached_packs[folder]
end)

local function try_sound(path)
    if love.filesystem.exists(path) then
        local obj = audio.new_static(path)
        obj.volume = sound_volume
        return obj
    end
end

function assets.get_sound(id)
    id = sound_mapping[id] or id
    if cached_sounds[id] == nil then
        local pack, actual_id = id:match("(.*)_(.*)")
        cached_sounds[id] = try_sound("packs192/" .. (pack or "") .. "/" .. "Sounds/" .. (actual_id or ""))
            or try_sound(audio_path .. id)
    end
    return cached_sounds[id]
end

function assets.set_volume(volume)
    sound_volume = volume
    for _, sound in pairs(cached_sounds) do
        sound.volume = sound_volume
    end
end

return assets
