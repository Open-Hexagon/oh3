local threadify = require("threadify")
local threaded_assets = threadify.require("game_handler.assets")
local async = require("async")
local audio = require("audio")
local args = require("args")
local assets = {}
local sound_volume
local sound_path = "assets/audio/"
local cached_sounds = {}
local cached_packs = {}
local pending_packs = {}

assets.init = async(function(config)
    sound_volume = config.get("sound_volume")
    if config.get("preload_all_packs") and not args.replay_viewer then
        local game_handler = require("game_handler")
        local packs = game_handler.get_packs()
        for i = 1, #packs do
            local pack = packs[i]
            if pack.game_version == 20 then
                cached_packs[pack.id] = async.await(threaded_assets.get_pack(20, pack.id))
            end
        end
    end
end)

assets.get_pack = async(function(folder)
    if pending_packs[folder] then
        async.await(pending_packs[folder])
    elseif not cached_packs[folder] then
        pending_packs[folder] = threaded_assets.get_pack(20, folder)
        cached_packs[folder] = async.await(pending_packs[folder])
    end
    pending_packs[folder] = nil
    return cached_packs[folder]
end)

function assets.get_sound(filename)
    if not cached_sounds[filename] then
        if love.filesystem.getInfo(sound_path .. filename) then
            cached_sounds[filename] = audio.new_static(sound_path .. filename)
            cached_sounds[filename].volume = sound_volume
        else
            if filename:match("_") then
                -- possibly a pack sound
                local location = filename:find("_")
                local pack = filename:sub(1, location - 1)
                if cached_packs[pack] then
                    local name = filename:sub(location + 1)
                    local path = cached_packs[pack].path .. "Sounds/" .. name
                    if not love.filesystem.getInfo(path) then
                        return
                    end
                    cached_sounds[filename] = audio.new_static(path)
                    cached_sounds[filename].volume = sound_volume
                end
            end
            return
        end
    end
    return cached_sounds[filename]
end

function assets.set_volume(volume)
    sound_volume = volume
    for _, sound in pairs(cached_sounds) do
        sound.volume = sound_volume
    end
end

return assets
