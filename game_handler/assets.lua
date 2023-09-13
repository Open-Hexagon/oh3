local log = require("log")(...)
local json = require("extlibs.json.jsonc")
local data = require("game_handler.data")
local utils = require("compat.game192.utils")
local vfs = require("compat.game192.virtual_filesystem")
local shader_compat = require("compat.game21.shader_compat")
local assets = {}
local packs = {}
local is_headless = false
local dependency_pack_mapping21 = {}

---decode a string of json with a filename to be used in a potential non erroring error message
---@param str string
---@param filename string
---@return boolean
---@return table
local function decode_json(str, filename)
    -- not a good way but hardcoding some known cases
    str = str:gsub(": 00 }", ": 0 }")
    str = str:gsub(", 00", ", 0")
    str = str:gsub("%[00,", "%[0,")
    str = str:gsub("055%]", "55%]")
    -- remove multiline comments
    while str:find("/*", 0, true) and str:find("*/", 0, true) do
        local cstart = str:find("/*", 0, true)
        local cend = str:find("*/", 0, true)
        str = str:sub(1, cstart - 1) .. str:sub(cend + 2)
    end
    -- replace control characters in strings
    local offset = 0
    local strings = {}
    while true do
        local start_quote = str:find('"', offset)
        if start_quote == nil then
            break
        end
        offset = start_quote + 1
        local end_quote = str:find('"', offset)
        if end_quote == nil then
            break
        end
        offset = end_quote + 1
        local contents = str:sub(start_quote + 1, end_quote - 1)
        if contents:find("\n") then
            strings[#strings + 1] = contents
            contents = contents:gsub("\n", "\\n"):gsub("\r", "\\r")
            strings[#strings + 1] = contents
            str = str:sub(1, start_quote) .. contents .. str:sub(end_quote)
            offset = str:find('"', start_quote + 1) + 1
        end
    end
    -- catch decode errors
    return xpcall(json.decode_jsonc, function(msg)
        log("Error: can't decode '" .. filename .. "': " .. msg)
    end, str)
end

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
            error("Failed to read " .. dir .. "/" .. files[index])
        else
            return contents, files[index]
        end
    end
end

local function file_iter(dir, ending, pack_data)
    if pack_data.game_version ~= 21 then
        return utils.file_ext_read_iter(pack_data.path .. dir, ending, pack_data.virtual_pack_folder[dir])
    else
        return file_ext_read_iter(pack_data.path .. dir, ending)
    end
end

-- steam version has special unique pack identifiers other than the folder name
local function build_pack_id21(disambiguator, author, name, version)
    local pack_id = disambiguator .. "_" .. author .. "_" .. name
    if version ~= nil then
        pack_id = pack_id .. "_" .. math.floor(version)
    end
    pack_id = pack_id:gsub(" ", "_")
    return pack_id
end

function assets.init(persistent_data, headless)
    is_headless = headless
    local folders = love.filesystem.getDirectoryItems("")
    for i = 1, #folders do
        local version = folders[i]:match("packs(.*)")
        if version then
            log("Loading pack information for game" .. version)
            version = tonumber(version)
            local is_compat = version ~= 3
            local pack_folder = "packs" .. version .. "/"
            local pack_folders = love.filesystem.getDirectoryItems(pack_folder)
            for j = 1, #pack_folders do
                local folder = pack_folder .. pack_folders[j] .. "/"
                -- check if valid pack
                local files = love.filesystem.getDirectoryItems(folder)
                local function check_file(file)
                    local is_in = false
                    for k = 1, #files do
                        if files[k] == file then
                            is_in = true
                        end
                    end
                    if not is_in then
                        error("Invalid pack " .. folder .. ", " .. file .. " does not exist!")
                    end
                end
                if is_compat then
                    check_file("pack.json")
                    check_file("Scripts")
                    local pack_json_contents = love.filesystem.read(folder .. "pack.json")
                    if pack_json_contents == nil then
                        error("Failed to load pack.json")
                    end
                    local decode_success, pack_data = decode_json(pack_json_contents)
                    if decode_success then
                        pack_data.game_version = version
                        pack_data.path = folder
                        pack_data.loaded = false
                        if version == 21 then
                            pack_data.id = build_pack_id21(pack_data.disambiguator, pack_data.author, pack_data.name, pack_data.version)
                            dependency_pack_mapping21[build_pack_id21(pack_data.disambiguator, pack_data.author, pack_data.name)] = pack_data
                        else
                            pack_data.id = pack_folders[j]
                        end
                        data.register_pack(pack_data.id, pack_data.name, version)
                        if version ~= 21 then
                            -- initialize virtual filesystem for reading
                            vfs.clear()
                            local virtual_pack_folder
                            local folder_name = pack_folders[j]
                            if persistent_data and persistent_data[folder_name] then
                                vfs.load_files(persistent_data[folder_name])
                                virtual_pack_folder = vfs.dump_real_files_recurse()[folder_name]
                            end
                            pack_data.virtual_pack_folder = virtual_pack_folder or {}
                        end

                        -- level data has to be loaded immediately for level selection purposes
                        pack_data.levels = {}
                        for contents, filename in file_iter("Levels", ".json", pack_data) do
                            local success, level_json = decode_json(contents, filename)
                            if success then
                                local proceed = true
                                if pack_data.game_version == 192 then
                                    proceed = level_json.selectable
                                end
                                if proceed then
                                    -- make keys have the same name for all versions
                                    for key, value in pairs(level_json) do
                                        local snake_case_key = key:gsub("([a-z])([A-Z])", "%1_%2"):lower()
                                        snake_case_key = snake_case_key:gsub("multipliers", "mults")
                                        level_json[snake_case_key] = value
                                    end

                                    -- default
                                    level_json.difficulty_mults = level_json.difficulty_mults or {}
                                    -- add 1x difficulty mult if it doesn't exist
                                    local has1 = false
                                    for k = 1, #level_json.difficulty_mults do
                                        if level_json.difficulty_mults[k] == 1 then
                                            has1 = true
                                            break
                                        end
                                    end
                                    if not has1 then
                                        level_json.difficulty_mults[#level_json.difficulty_mults + 1] = 1
                                    end
                                    -- sort difficulties
                                    table.sort(level_json)

                                    data.register_level(pack_data.id, level_json.id, level_json.name, level_json.author, level_json.description, { difficulty_mult = level_json.difficulty_mults })
                                    pack_data.levels[level_json.id] = level_json
                                end
                            else
                                log("Failed to parse level json:", filename)
                            end
                        end
                        if packs[pack_data.id] then
                            log("Id conflict: ", pack_data.id)
                        end
                        packs[pack_data.id] = pack_data
                    else
                        log("Failed to decode", folder .. "pack.json")
                    end
                end
            end
        end
    end
    return data.get_packs()
end

function assets.get_dependency_pack_mapping21()
    return dependency_pack_mapping21
end

function assets.get_pack(version, id)
    local is_compat = version ~= 3
    local pack_data = packs[id] or dependency_pack_mapping21[id]
    if not pack_data then
        print(version, id)
        error("pack with id '" .. id .. "' does not exist.")
    end
    id = pack_data.id
    if pack_data.loaded then
        return pack_data
    end
    if is_compat then
        if version == 21 then
            -- pack may have dependencies
            if pack_data.dependencies ~= nil then
                for i = 1, #pack_data.dependencies do
                    local dependency = pack_data.dependencies[i]
                    local index_pack_id = build_pack_id21(dependency.disambiguator, dependency.author, dependency.name)
                    local dependency_pack_data = dependency_pack_mapping21[index_pack_id]
                    if dependency_pack_data == nil then
                        error("can't find dependency '" .. index_pack_id .. "' of '" .. pack_data.pack_id .. "'.")
                    end
                    -- fix recursive dependencies
                    if dependency_pack_data.id ~= id then
                        -- no need to keep the pack data, just make sure it's loaded now to avoid having to make loading circles during gameplay to load dependency packs
                        assets.get_pack(version, dependency_pack_data.id)
                    end
                end
            end
        end
        log("Loading '" .. pack_data.id .. "' assets")

        -- music
        pack_data.music = {}
        for contents, filename in file_iter("Music", ".json", pack_data) do
            local success, music_json = decode_json(contents, filename)
            if success then
                if not is_headless then
                    local fallback_path = filename:gsub("%.json", ".ogg")
                    music_json.file_name = music_json.file_name or fallback_path
                    if music_json.file_name:sub(-4) ~= ".ogg" then
                        music_json.file_name = fallback_path
                    end
                    if not love.filesystem.getInfo(pack_data.path .. "Music/" .. music_json.file_name) then
                        music_json.file_name = fallback_path
                    end
                    if love.filesystem.getInfo(pack_data.path .. "Music/" .. music_json.file_name) then
                        -- don't load music here yet, load it when required and unload it again to save memory usage (otherwise the game may use 5+ gb just for music assets after clicking through the menu)
                        music_json.file_path = pack_data.path .. "Music/" .. music_json.file_name
                    end
                end
                if pack_data.game_version ~= 21 then
                    for i = 1, #music_json.segments do
                        if type(music_json.segments[i]) == "table" then
                            music_json.segments[i].time = math.floor(music_json.segments[i].time)
                        else
                            -- happens with the last element of not properly closed segment list
                            music_json.segments[i] = nil
                        end
                    end
                end
                pack_data.music[music_json.id] = music_json
            end
        end

        -- shaders in compat mode are only required for 21
        if not is_headless and version == 21 then
            pack_data.shaders = {}
            for code, filename in file_iter("Shaders", ".frag", pack_data) do
                pack_data[filename] = shader_compat(code, filename)
            end
        end

        -- styles
        pack_data.styles = {}
        for contents, filename in file_iter("Styles", ".json", pack_data) do
            local success, style_json = decode_json(contents, filename)
            if success then
                pack_data.styles[style_json.id] = style_json
            end
        end

        -- only 1.92 has event files
        if version == 192 then
            pack_data.events = {}
            for contents, filename in file_iter("Events", ".json", pack_data) do
                local success, event_json = decode_json(contents, filename)
                if success then
                    pack_data.events[event_json.id] = event_json.events
                end
            end
        end
    end
    pack_data.loaded = true
    return pack_data
end

return assets
