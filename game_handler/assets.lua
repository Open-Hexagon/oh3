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
local asset_loading_text_channel = love.thread.getChannel("asset_loading_text")
local asset_loading_progress_channel = love.thread.getChannel("asset_loading_progress")

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

local function get_file_amount(dir, ending, pack_data)
    local files = love.filesystem.getDirectoryItems(pack_data.path .. dir)
    if pack_data.game_version ~= 21 then
        for file in pairs(pack_data.virtual_pack_folder[dir] or {}) do
            files[#files + 1] = file
        end
    end
    local count = 0
    for i = 1, #files do
        if files[i]:sub(-#ending) == ending then
            count = count + 1
        end
    end
    return count
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

local initialized = false

function assets.init(persistent_data, headless)
    if not initialized then
        is_headless = headless
        local folders = love.filesystem.getDirectoryItems("")
        for i = 1, #folders do
            local version = folders[i]:match("packs(.*)")
            if version then
                log("Loading pack information for game" .. version)
                asset_loading_text_channel:push("Loading pack information for game" .. version)
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
                                pack_data.id = build_pack_id21(
                                    pack_data.disambiguator,
                                    pack_data.author,
                                    pack_data.name,
                                    pack_data.version
                                )
                                dependency_pack_mapping21[build_pack_id21(
                                    pack_data.disambiguator,
                                    pack_data.author,
                                    pack_data.name
                                )] =
                                    pack_data
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
                            local level_list = {}
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
                                        table.sort(level_json.difficulty_mults)

                                        pack_data.levels[level_json.id] = level_json
                                        level_list[#level_list + 1] = level_json
                                    end
                                else
                                    log("Failed to parse level json:", filename)
                                end
                            end

                            -- register levels in menu priority order
                            table.sort(level_list, function(a, b)
                                return (a.menu_priority or 0) < (b.menu_priority or 0)
                            end)
                            for k = 1, #level_list do
                                local level = level_list[k]
                                data.register_level(
                                    pack_data.id,
                                    level.id,
                                    level.name,
                                    level.author,
                                    level.description,
                                    { difficulty_mult = level.difficulty_mults }
                                )
                            end

                            if packs[pack_data.id] then
                                log("Id conflict: ", pack_data.id)
                            end
                            packs[pack_data.id] = pack_data
                        else
                            log("Failed to decode", folder .. "pack.json")
                        end
                    end
                    asset_loading_progress_channel:push(j / #pack_folders)
                end
            end
        end
        initialized = true
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
        error("pack with id '" .. id .. "' does not exist.")
    end
    id = pack_data.id
    asset_loading_text_channel:push("Loading pack '" .. id .. "' assets")
    asset_loading_progress_channel:push(0)
    if pack_data.loaded then
        asset_loading_progress_channel:push(1)
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
                        error("can't find dependency '" .. index_pack_id .. "' of '" .. pack_data.id .. "'.")
                    end
                    -- fix recursive dependencies
                    if dependency_pack_data.id ~= id then
                        -- no need to keep the pack data, just make sure it's loaded now to avoid having to make loading circles during gameplay to load dependency packs
                        assets.get_pack(version, dependency_pack_data.id)
                    end
                end
            end
            -- reset text and progress to this pack
            asset_loading_text_channel:push("Loading pack '" .. id .. "' assets")
            asset_loading_progress_channel:push(0)
        end
        log("Loading '" .. pack_data.id .. "' assets")

        local loaded_files = 0
        local total_files = get_file_amount("Music", ".json", pack_data) + get_file_amount("Styles", ".json", pack_data)
        if pack_data.game_version == 21 then
            total_files = total_files + get_file_amount("Shaders", ".frag", pack_data)
        elseif pack_data.game_version == 192 then
            total_files = total_files + get_file_amount("Events", ".json", pack_data)
        end

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
            loaded_files = loaded_files + 1
            asset_loading_progress_channel:push(loaded_files / total_files)
        end

        -- shaders in compat mode are only required for 21
        if not is_headless and version == 21 then
            pack_data.shaders = {}
            for code, filename in file_iter("Shaders", ".frag", pack_data) do
                -- only translating, can only compile in main thread
                pack_data.shaders[filename] = shader_compat.translate(code, filename)
                loaded_files = loaded_files + 1
                asset_loading_progress_channel:push(loaded_files / total_files)
            end
        end

        -- styles
        pack_data.styles = {}
        for contents, filename in file_iter("Styles", ".json", pack_data) do
            local success, style_json = decode_json(contents, filename)
            if success then
                pack_data.styles[style_json.id] = style_json
            end
            loaded_files = loaded_files + 1
            asset_loading_progress_channel:push(loaded_files / total_files)
        end

        -- only 1.92 has event files
        if version == 192 then
            pack_data.events = {}
            for contents, filename in file_iter("Events", ".json", pack_data) do
                local success, event_json = decode_json(contents, filename)
                if success then
                    pack_data.events[event_json.id] = event_json.events
                end
                loaded_files = loaded_files + 1
                asset_loading_progress_channel:push(loaded_files / total_files)
            end
        end

        -- small preview data
        if not is_headless then
            pack_data.preview_data = {}
            local style_module = require("compat.game" .. pack_data.game_version .. ".style")
            local set_function = style_module.select or style_module.set
            for level_id, level in pairs(pack_data.levels) do
                -- get side count
                local sides = 6
                if version == 192 then
                    sides = level.sides or 6
                else
                    local lua_path = pack_data.path .. "/" .. level.lua_file
                    if love.filesystem.getInfo(lua_path) then
                        local code = love.filesystem.read(lua_path)
                        -- match set sides calls in the lua file to get the number of sides
                        for match in code:gmatch("function.-onInit.-l_setSides%((.-)%).-end") do
                            sides = tonumber(match) or sides
                        end
                    end
                end
                sides = math.max(sides, 3)

                -- get colors
                set_function(pack_data.styles[level.style_id])
                style_module.compute_colors()
                local main_color = { style_module.get_main_color() }
                for i = 1, 4 do
                    main_color[i] = main_color[i] / 255
                end

                -- generate vertex and color data
                local polygons = {}
                local colors = {}
                local distance = 48
                local radius = distance / 3
                local cap_poly = {}
                local outline = {}
                local pivot_thickness = 2
                for i = 1, sides do
                    local r, g, b, a = style_module.get_color(i - (pack_data.game_version == 20 and 0 or 1))
                    local must_darken = i % 2 == 0 and i == sides - 1
                    if must_darken then
                        r = r / 1.4
                        g = g / 1.4
                        b = b / 1.4
                    end
                    r = r / 255
                    g = g / 255
                    b = b / 255
                    a = a / 255
                    local angle1 = i * 2 * math.pi / sides
                    local cos1 = math.cos(angle1)
                    local sin1 = math.sin(angle1)
                    local angle2 = angle1 + 2 * math.pi / sides
                    local cos2 = math.cos(angle2)
                    local sin2 = math.sin(angle2)
                    local polygon = {
                        0,
                        0,
                        cos1 * distance,
                        sin1 * distance,
                        cos2 * distance,
                        sin2 * distance,
                    }
                    polygons[#polygons + 1] = polygon
                    colors[#colors + 1] = { r * a, g * a, b * a, 1 }
                    local pivot_poly = {
                        cos2 * radius,
                        sin2 * radius,
                        cos1 * radius,
                        sin1 * radius,
                        cos1 * (radius + pivot_thickness),
                        sin1 * (radius + pivot_thickness),
                        cos2 * (radius + pivot_thickness),
                        sin2 * (radius + pivot_thickness),
                    }
                    polygons[#polygons + 1] = pivot_poly
                    colors[#colors + 1] = main_color
                    cap_poly[#cap_poly + 1] = cos1 * radius
                    cap_poly[#cap_poly + 1] = sin1 * radius
                    outline[#outline + 1] = cos1 * distance
                    outline[#outline + 1] = sin1 * distance
                end
                polygons[#polygons + 1] = cap_poly
                local r, g, b, a
                if pack_data.game_version == 21 then
                    r, g, b, a = style_module.get_cap_color_result()
                elseif pack_data.game_version == 20 then
                    r, g, b, a = style_module.get_color(2)
                elseif pack_data.game_version == 192 then
                    r, g, b, a = style_module.get_second_color()
                end
                colors[#colors + 1] = { r / 255, g / 255, b / 255, a / 255 }
                pack_data.preview_data[level_id] = {
                    polygons = polygons,
                    colors = colors,
                    outline = outline,
                }
            end
        end
    end

    pack_data.loaded = true
    return pack_data
end

return assets
