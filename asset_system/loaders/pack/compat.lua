local log = require("log")(...)
local index = require("asset_system.index")
local json = require("extlibs.json.jsonc")
local vfs = require("compat.game192.virtual_filesystem")

local compat_loaders = {}

---steam version has special unique pack identifiers other than the folder name
---@param info table
---@param include_version boolean?
---@return string
function compat_loaders.build_pack_id21(info, include_version)
    local pack_id = info.disambiguator .. "_" .. info.author .. "_" .. info.name
    if info.version ~= nil and include_version then
        pack_id = pack_id .. "_" .. math.floor(info.version)
    end
    pack_id = pack_id:gsub(" ", "_")
    return pack_id
end

function compat_loaders.text_file(path_or_content, use_vfs)
    if use_vfs then
        return path_or_content
    else
        index.watch_file(path_or_content)
        return love.filesystem.read(path_or_content)
    end
end

function compat_loaders.json_file(path_or_content, use_vfs)
    local str = index.local_request("pack.compat.text_file", path_or_content, use_vfs)
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
    -- catch decode errors
    local _, result = xpcall(json.decode_jsonc, function(msg)
        log("Error: can't decode '" .. path_or_content .. "': " .. msg)
    end, str)
    return result
end

function compat_loaders.virtual_folder(pack_folder_name)
    index.watch("persistent_data:" .. pack_folder_name)
    local persistent_data = love.thread.getChannel("persistent_data:" .. pack_folder_name):peek()
    vfs.clear()
    local virtual_pack_folder
    if persistent_data then
        vfs.load_files(json.decode(persistent_data))
        virtual_pack_folder = vfs.dump_real_files_recurse()[pack_folder_name]
    end
    return virtual_pack_folder or {}
end

local file_loaders = {
    [".json"] = "pack.compat.json_file",
}

---iterate over the contents of all files with a certain ending in a certain folder
---@param dir string
---@param ending string
---@param info table
---@return function
local function file_iter(dir, ending, info)
    local loader = file_loaders[ending] or "pack.compat.text_file"
    local files = love.filesystem.getDirectoryItems(info.path .. dir)
    local virt_folder = index.local_request("pack.compat.virtual_folder", info.folder_name)
    virt_folder = virt_folder[dir] or {}
    -- add virtual files to list
    for file in pairs(virt_folder) do
        files[#files + 1] = file
    end
    return coroutine.wrap(function()
        for i = 1, #files do
            local name = files[i]
            if name:sub(-#ending) == ending then
                -- virtual files take precedence over real ones (overwriting)
                if virt_folder[name] then
                    coroutine.yield(index.local_request(loader, virt_folder[name], true), name)
                else
                    coroutine.yield(index.local_request(loader, info.path .. dir .. "/" .. name), name)
                end
            end
        end
    end)
end

function compat_loaders.level_datas(pack_folder_name, version)
    local info = index.local_request("pack.compat.info", pack_folder_name, version)
    local levels = {}
    for level_json in file_iter("Levels", ".json", info) do
        -- make keys have the same name for all versions
        -- get key names
        local key_names = {}
        for key in pairs(level_json) do
            key_names[#key_names + 1] = key
        end
        -- and then translate them to avoid modifying the table while iterating (which may skip some keys)
        for k = 1, #key_names do
            local key = key_names[k]
            local value = level_json[key]
            local snake_case_key = key:gsub("([a-z])([A-Z])", "%1_%2"):lower()
            snake_case_key = snake_case_key:gsub("multipliers", "mults")
            level_json[snake_case_key] = value
        end

        -- set defaults
        level_json.id = level_json.id or "nullId"
        level_json.name = level_json.name or "nullName"
        level_json.description = level_json.description or ""
        level_json.author = level_json.author or ""
        level_json.menu_priority = level_json.menu_priority or 0
        if level_json.selectable == nil then
            level_json.selectable = true
        end
        level_json.music_id = level_json.music_id or "nullMusicId"
        level_json.sound_id = level_json.sound_id or "nullSoundId"
        level_json.style_id = level_json.style_id or "nullStyleId"
        level_json.lua_file = level_json.lua_file or "nullLuaPath"
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

        -- insertion sort by menu priority
        for i = 1, #levels + 1 do
            if levels[i] == nil or levels[i].menu_priority >= level_json.menu_priority then
                table.insert(levels, i, level_json)
                break
            end
        end
    end
    return levels
end

function compat_loaders.info(pack_folder_name, version)
    local folder = "packs" .. version .. "/" .. pack_folder_name .. "/"
    if not love.filesystem.exists(folder .. "pack.json") then
        log("Invalid pack at " .. folder .. " missing pack.json")
        return
    end
    if not love.filesystem.exists(folder .. "Scripts") then
        log("Invalid pack at " .. folder .. " missing Scripts folder")
        return
    end
    local info = index.local_request("pack.compat.json_file", folder .. "pack.json")
    info.game_version = version
    info.path = folder
    info.folder_name = pack_folder_name
    if version == 21 then
        -- steam version defaults
        info.name = info.name or "unkown name"
        info.author = info.author or "unkown author"
        info.description = info.description or "no description"
        info.version = info.version or 0
        info.priority = info.priority or 100

        info.id = compat_loaders.build_pack_id21(info, true)
    else
        info.name = info.name or ""
        info.id = pack_folder_name
    end
    return info
end

function compat_loaders.preload_pack(pack_folder_name, version)
    local pack = {}
    pack.info = index.local_request("pack.compat.info", pack_folder_name, version)
    local level_list = index.local_request("pack.compat.level_datas", pack_folder_name, version)
    pack.levels = {}
    for i = 1, #level_list do
        local level = level_list[i]
        pack.levels[level.id] = level
    end
    return pack
end

function compat_loaders.load_dependency_map21()
    local packs21 = index.local_request("pack.preload_packs", 21)
    local map = {}
    for i = 1, #packs21 do
        local pack = packs21[i]
        map[compat_loaders.build_pack_id21(pack.info)] = pack
    end
    return map
end

return compat_loaders
