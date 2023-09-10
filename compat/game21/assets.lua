local async = require("async")
local threadify = require("threadify")
local threaded_assets = threadify.require("game_handler.assets")
local pack_id_json_map = {}
local pack_id_list = {}
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
local cached_sounds = {}
local loaded_fonts = {}
local loaded_images = {}
local audio_module, sound_volume
local dependency_mapping = {}

local assets = {}

assets.init = async(function(audio, config)
    audio_module = audio
    sound_volume = config.get("sound_volume")
    dependency_mapping = async.await(threaded_assets.get_dependency_pack_mapping21())
end)

function assets.get_pack(id)
    return threaded_assets.get_pack(21, id)
end

function assets.get_pack_from_metadata(disambiguator, author, name)
    local pack_id = disambiguator .. "_" .. author .. "_" .. name
    pack_id = pack_id:gsub(" ", "_")
    return dependency_mapping[pack_id]
end

function assets.get_sound(id)
    id = sound_mapping[id] or id
    if cached_sounds[id] == nil then
        if love.filesystem.getInfo(audio_path .. id) then
            cached_sounds[id] = audio_module.new_static(audio_path .. id)
            cached_sounds[id].volume = sound_volume
        else
            return assets.get_pack_sound(nil, id)
        end
    end
    return cached_sounds[id]
end

function assets.get_pack_sound(pack, id)
    local glob_id
    if pack then
        glob_id = pack.pack_id .. "_" .. id
    else
        glob_id = id
        for i = 1, #pack_id_list do
            local pack_id = pack_id_list[i]
            if id:sub(1, #pack_id) == pack_id then
                id = id:sub(#pack_id + 2)
                pack = pack_id_json_map[pack_id]
                break
            end
        end
        if not pack then
            return
        end
    end
    if cached_sounds[glob_id] == nil then
        cached_sounds[glob_id] = audio_module.new_static(pack.path .. "/Sounds/" .. id)
        cached_sounds[glob_id].volume = sound_volume
    end
    return cached_sounds[glob_id]
end

function assets.get_font(name, size)
    if loaded_fonts[name] == nil then
        loaded_fonts[name] = {}
    end
    if loaded_fonts[name][size] == nil then
        loaded_fonts[name][size] = love.graphics.newFont("assets/font/" .. name, size)
    end
    return loaded_fonts[name][size]
end

function assets.get_image(name)
    if loaded_images[name] == nil then
        loaded_images[name] = love.graphics.newImage("assets/image/" .. name)
    end
    return loaded_images[name]
end

return assets
