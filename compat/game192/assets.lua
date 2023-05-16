local log = require("log")(...)
local args = require("args")
local json = require("extlibs.json.jsonc")

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

function assets.init()
    local pack_folders = love.filesystem.getDirectoryItems(pack_path)
    for i = 1, #pack_folders do
        local folder = pack_folders[i]
        local pack_data = {}
        pack_data.path = pack_path .. folder .. "/"
        pack_data.folder = folder
        local pack_json = json.decode_jsonc(love.filesystem.read(pack_data.path .. "pack.json"))
        pack_data.name = pack_json.name or ""
        packs[folder] = pack_data
    end
end

local function decode_json(str, filename)
    return xpcall(json.decode_jsonc, function(msg)
        log("Error: can't decode '" .. filename .. "': " .. msg)
    end, str)
end

function assets.get_pack(folder)
    local pack_data = packs[folder]
    if pack_data == nil then
        error("'" .. pack_path .. folder .. "' does not exist or is not a valid pack.")
    end
    if pack_data.levels == nil then
        folder = pack_path .. folder .. "/"
        log("Loading '" .. pack_data.name .. "' assets")
        local function file_ext_read_iter(dir, ending)
            local files = love.filesystem.getDirectoryItems(dir)
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
                local contents = love.filesystem.read(dir .. "/" .. files[index])
                if contents == nil then
                    error("Failed to read '" .. dir .. "/" .. files[index] .. "'")
                else
                    return contents, files[index]
                end
            end
        end

        -- level data
        pack_data.levels = {}
        for contents, filename in file_ext_read_iter(folder .. "Levels", ".json") do
            local success, level_json = decode_json(contents, filename)
            if success then
                pack_data.levels[level_json.id] = level_json
            end
        end

        if not args.headless then
            -- music
            pack_data.music = {}
            for contents, filename in file_ext_read_iter(folder .. "Music", ".json") do
                local success, music_json = decode_json(contents, filename)
                if success then
                    music_json.file_name = music_json.file_name or filename:gsub("%.json", ".ogg")
                    if music_json.file_name:sub(-4) ~= ".ogg" then
                        music_json.file_name = music_json.file_name .. ".ogg"
                    end
                    if
                        not pcall(function()
                            music_json.source =
                                love.audio.newSource(folder .. "Music/" .. music_json.file_name, "stream")
                            music_json.source:setLooping(true)
                        end)
                    then
                        log("Error: failed to load '" .. music_json.file_name .. "'")
                    end
                    pack_data.music[music_json.id] = music_json
                end
            end
        end

        -- styles
        pack_data.styles = {}
        for contents, filename in file_ext_read_iter(folder .. "Styles", ".json") do
            local success, style_json = decode_json(contents, filename)
            if success then
                pack_data.styles[style_json.id] = style_json
            end
        end

        -- events
        pack_data.events = {}
        for contents, filename in file_ext_read_iter(folder .. "Events", ".json") do
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

assets.init()

return assets
