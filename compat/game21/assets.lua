local log = require("log")(...)
local args = require("args")
local async = require("async")
local threadify = require("threadify")
local threaded_assets = threadify.require("game_handler.assets")
local shader_compat = require("compat.game21.shader_compat")
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
local cached_packs = {}
local pending_packs = {}

local assets = {}

---compile shaders if not done already
---@param pack table
local function compile_shaders(pack)
    if not args.headless then
        for filename, data in pairs(pack.shaders) do
            if data.new_code then
                pack.shaders[filename] = shader_compat.compile(data.new_code, data.code, data.filename)
            end
        end
    end
end

assets.init = async(function(audio, config)
    audio_module = audio
    sound_volume = config.get("sound_volume")
    if config.get("preload_all_packs") then
        local game_handler = require("game_handler")
        local packs = game_handler.get_packs()
        for i = 1, #packs do
            if packs[i].game_version == 21 then
                local pack = async.await(threaded_assets.get_pack(21, packs[i].id))
                compile_shaders(pack)
                cached_packs[packs[i].id] = pack
            end
        end
    end
    dependency_mapping = async.await(threaded_assets.get_dependency_pack_mapping21())
end)

local function build_pack_id(disambiguator, author, name, version)
    local pack_id = disambiguator .. "_" .. author .. "_" .. name
    if version ~= nil then
        pack_id = pack_id .. "_" .. math.floor(version)
    end
    pack_id = pack_id:gsub(" ", "_")
    return pack_id
end

assets.get_pack = async(function(id)
    if pending_packs[id] then
        async.await(pending_packs[id])
    elseif not cached_packs[id] then
        local done_func
        pending_packs[id] = async.promise:new(function(resolve)
            done_func = resolve
        end)
        local pack = async.await(threaded_assets.get_pack(21, id))
        compile_shaders(pack)
        -- update pack in dependency_mapping now that shaders are compiled
        do
            local index_pack_id = build_pack_id(pack.disambiguator, pack.author, pack.name)
            dependency_mapping[index_pack_id] = pack
        end
        -- load the dependencies as well (has to be done here again in order to update depdendency mapping in main thread and to compile shaders (although rarely used dependency shaders are a thing))
        if pack.dependencies ~= nil then
            for i = 1, #pack.dependencies do
                local dependency = pack.dependencies[i]
                local index_pack_id = build_pack_id(dependency.disambiguator, dependency.author, dependency.name)
                local dependency_pack = dependency_mapping[index_pack_id]
                if dependency_pack == nil then
                    log("can't find dependency '" .. index_pack_id .. "' of '" .. pack.id .. "'.")
                elseif dependency_pack.id ~= pack.id then
                    dependency_mapping[index_pack_id] = async.await(threaded_assets.get_pack(21, dependency_pack.id))
                    compile_shaders(dependency_mapping[index_pack_id])
                end
            end
        end
        cached_packs[id] = pack
        done_func()
    end
    pending_packs[id] = nil
    return cached_packs[id]
end)

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
        glob_id = pack.id .. "_" .. id
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
