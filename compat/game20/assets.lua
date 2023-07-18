local log = require("log")(...)
local args = require("args")
local json = require("extlibs.json.jsonc")
local vfs = require("compat.game192.virtual_filesystem")
local level = require("compat.game20.level")
local assets = {}
local audio_module, sound_volume, music_volume
local sound_path = "assets/audio/"
local cached_sounds = {}
local pack_path = "packs20/"
local packs = {}

local function decode_json(str, filename)
    return xpcall(json.decode_jsonc, function(msg)
        log("Error: can't decode '" .. filename .. "': " .. msg)
    end, str)
end

local function file_ext_read_iter(dir, ending, virt_folder)
    virt_folder = virt_folder or {}
    local files = love.filesystem.getDirectoryItems(dir)
    local virt_start_index = #files + 1
    for file in pairs(virt_folder) do
        files[#files + 1] = file
    end
    for i = virt_start_index - 1, 1, -1 do
        for j = virt_start_index, #files do
            if files[j] == files[i] then
                table.remove(files, i)
                virt_start_index = virt_start_index - 1
            end
        end
    end
    local index = 0
    return function()
        index = index + 1
        if index > #files then
            return
        end
        while files[index]:sub(-#ending) ~= ending do
            index = index + 1
            if index > #files then
                return
            end
        end
        if index >= virt_start_index then
            local contents = virt_folder[files[index]]
            return contents, files[index]
        else
            local contents = love.filesystem.read(dir .. "/" .. files[index])
            if contents == nil then
                error("Failed to read '" .. dir .. "/" .. files[index] .. "'")
            else
                return contents, files[index]
            end
        end
    end
end

function assets.init(data, persistent_data, audio, config)
    sound_volume = config.get("sound_volume")
    music_volume = config.get("music_volume")
    audio_module = audio
    local pack_names = love.filesystem.getDirectoryItems(pack_path)
    for i = 1, #pack_names do
        local folder = pack_names[i]
        local pack_data = {}
        pack_data.folder = folder
        pack_data.path = pack_path .. folder .. "/"
        local pack_json_path = pack_data.path .. "pack.json"
        local success, pack_json = decode_json(love.filesystem.read(pack_json_path), pack_json_path)
        if not success then
            error("Failed to load '" .. pack_json_path .. "'")
        end
        pack_data.name = pack_json.name or ""
        data.register_pack(folder, pack_data.name, 20)

        vfs.clear()
        local virtual_pack_folder
        if persistent_data ~= nil and persistent_data[folder] ~= nil then
            vfs.load_files(persistent_data[folder])
            virtual_pack_folder = vfs.dump_real_files_recurse()[folder]
        end
        pack_data.virtual_pack_folder = virtual_pack_folder or {}

        -- level data has to be loaded here for level selection purposes
        pack_data.levels = {}
        for contents, filename in
            file_ext_read_iter(pack_data.path .. "Levels", ".json", pack_data.virtual_pack_folder.Levels)
        do
            local level_json
            success, level_json = decode_json(contents, filename)
            if success then
                level_json.id = pack_data.folder .. "_" .. level_json.id
                level.set(level_json)
                data.register_level(folder, level.id, level.name, {
                    difficulty_mult = level.difficultyMults,
                })
                pack_data.levels[level_json.id] = level_json
            end
        end
        packs[folder] = pack_data
    end
end

function assets.get_pack(folder_name)
    if not packs[folder_name] then
        error("Pack with folder name '" .. folder_name .. "' does not exist.")
    end
    local pack_data = packs[folder_name]
    if pack_data.music then
        return pack_data
    end
    local folder = pack_data.path
    pack_data.music = {}
    for contents, filename in file_ext_read_iter(folder .. "Music", ".json", pack_data.virtual_pack_folder.Music) do
        local success, music_json = decode_json(contents, filename)
        if success then
            if not args.headless then
                local fallback_path = filename:gsub("%.json", ".ogg")
                music_json.file_name = music_json.file_name or fallback_path
                if music_json.file_name:sub(-4) ~= ".ogg" then
                    music_json.file_name = music_json.file_name .. ".ogg"
                end
                if not love.filesystem.getInfo(music_json.file_name) then
                    music_json.file_name = fallback_path
                end
                if
                    not pcall(function()
                        music_json.source = audio_module.new_stream(folder .. "Music/" .. music_json.file_name)
                        music_json.source.looping = true
                        music_json.source.volume = music_volume
                    end)
                then
                    log("Error: failed to load '" .. music_json.file_name .. "'")
                end
            end
            pack_data.music[music_json.id] = music_json
        end
    end
    pack_data.styles = {}
    for contents, filename in file_ext_read_iter(folder .. "Styles", ".json", pack_data.virtual_pack_folder) do
        local success, style_json = decode_json(contents, filename)
        if success then
            pack_data.styles[style_json.id] = style_json
        end
    end
    return pack_data
end

function assets.get_sound(filename)
    if not cached_sounds[filename] then
        if not love.filesystem.getInfo(sound_path .. filename) then
            return
        end
        cached_sounds[filename] = audio_module.new_static(sound_path .. filename)
    end
    return cached_sounds[filename]
end

return assets
