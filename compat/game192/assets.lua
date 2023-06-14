local log = require("log")(...)
local args = require("args")
local json = require("extlibs.json.jsonc")
local vfs = require("compat.game192.virtual_filesystem")

local assets = {}
local packs = {}
local pack_path = "packs192/"
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

function assets.init(data, persistent_data)
    local pack_folders = love.filesystem.getDirectoryItems(pack_path)
    for i = 1, #pack_folders do
        local folder = pack_folders[i]
        local pack_data = {}
        pack_data.path = pack_path .. folder .. "/"
        pack_data.folder = folder
        local pack_json_path = pack_data.path .. "pack.json"
        local success, pack_json = decode_json(love.filesystem.read(pack_json_path), pack_json_path)
        if not success then
            error("Failed to load '" .. pack_json_path .. "'")
        end
        pack_data.name = pack_json.name or ""

        data.register_pack(folder, pack_data.name, 192)

        vfs.clear()
        local virtual_pack_folder
        if persistent_data[folder] ~= nil then
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
                if level_json.selectable then
                    level_json.difficulty_multipliers = level_json.difficulty_multipliers or {}
                    local has1 = false
                    for j = 1, #level_json.difficulty_multipliers do
                        if level_json.difficulty_multipliers[j] == 1 then
                            has1 = true
                        end
                    end
                    if not has1 then
                        level_json.difficulty_multipliers[#level_json.difficulty_multipliers + 1] = 1
                    end
                    data.register_level(folder, level_json.id, level_json.name, {
                        difficulty_mult = level_json.difficulty_multipliers,
                    })
                end
                pack_data.levels[level_json.id] = level_json
            end
        end
        packs[folder] = pack_data
    end
end

function assets.get_pack(folder)
    local pack_data = packs[folder]
    if pack_data == nil then
        error("'" .. pack_path .. folder .. "' does not exist or is not a valid pack.")
    end
    if pack_data.music == nil then
        folder = pack_path .. folder .. "/"
        log("Loading '" .. pack_data.name .. "' assets")

        -- music
        pack_data.music = {}
        for contents, filename in file_ext_read_iter(folder .. "Music", ".json", pack_data.virtual_pack_folder.Music) do
            local success, music_json = decode_json(contents, filename)
            if success then
                music_json.file_name = music_json.file_name or filename:gsub("%.json", ".ogg")
                if music_json.file_name:sub(-4) ~= ".ogg" then
                    music_json.file_name = music_json.file_name .. ".ogg"
                end
                if not args.headless then
                    if
                        not pcall(function()
                            music_json.source =
                                love.audio.newSource(folder .. "Music/" .. music_json.file_name, "stream")
                            music_json.source:setLooping(true)
                        end)
                    then
                        log("Error: failed to load '" .. music_json.file_name .. "'")
                    end
                end
                pack_data.music[music_json.id] = music_json
            end
        end

        -- styles
        pack_data.styles = {}
        for contents, filename in file_ext_read_iter(folder .. "Styles", ".json", pack_data.virtual_pack_folder.Styles) do
            local success, style_json = decode_json(contents, filename)
            if success then
                pack_data.styles[style_json.id] = style_json
            end
        end

        -- events
        pack_data.events = {}
        for contents, filename in file_ext_read_iter(folder .. "Events", ".json", pack_data.virtual_pack_folder.Events) do
            local success, event_json = decode_json(contents, filename)
            if success then
                pack_data.events[event_json.id] = event_json.events
            end
        end

        pack_data.cached_sounds = {}
    end
    return pack_data
end

function assets.get_sound(id)
    id = sound_mapping[id] or id
    if cached_sounds[id] == nil then
        cached_sounds[id] = love.audio.newSource(audio_path .. id, "static")
    end
    return cached_sounds[id]
end

function assets.get_pack_sound(pack, id)
    if pack.cached_sounds[id] == nil then
        pack.cached_sounds[id] = love.audio.newSource(pack.path .. "Sounds/" .. id:match("_(.*)"), "static")
    end
    return pack.cached_sounds[id]
end

return assets
