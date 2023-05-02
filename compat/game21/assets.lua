local log = require("log")(...)
local json = require("extlibs.json.jsonc")

local assets = {
    loaded_packs = {},
    pack_path = "Packs/",
    metadata_pack_json_map = {},
    folder_pack_json_map = {},
}

function assets:_build_pack_id(disambiguator, author, name, version)
    local pack_id = disambiguator
        .. "_"
        .. author
        .. "_"
        .. name
    if version ~= nil then
        pack_id = pack_id .. "_" .. math.floor(version)
    end
    pack_id = pack_id:gsub(" ", "_")
    return pack_id
end

function assets:init()
    local pack_folders = love.filesystem.getDirectoryItems(self.pack_path)
    for i = 1, #pack_folders do
        local folder = self.pack_path .. pack_folders[i]
        -- check if valid pack
        local files = love.filesystem.getDirectoryItems(folder)
        local function check_file(file)
            local is_in = false
            for j = 1, #files do
                if files[j] == file then
                    is_in = true
                end
            end
            if not is_in then
                error("Invalid pack " .. folder .. ", " .. file .. " does not exist!")
            end
        end
        check_file("pack.json")
        check_file("Scripts")

        local contents = love.filesystem.read(folder .. "/pack.json")
        if contents == nil then
            error("Failed to load pack.json")
        end
        local pack_json = json.decode_jsonc(contents)
        pack_json.pack_id = assets:_build_pack_id(pack_json.disambiguator, pack_json.author, pack_json.name, pack_json.version)
        local index_pack_id = assets:_build_pack_id(pack_json.disambiguator, pack_json.author, pack_json.name)
        pack_json.pack_name = pack_folders[i]
        self.metadata_pack_json_map[index_pack_id] = pack_json
        self.folder_pack_json_map[folder] = pack_json
    end
end

function assets:get_pack(name)
    if self.loaded_packs[name] == nil then
        local folder = self.pack_path .. name

        local pack_data = {
            path = folder
        }

        -- pack metadata
        pack_data.pack_json = self.folder_pack_json_map[folder]
	if pack_data.pack_json == nil then
            error(folder .. " doesn't exist or is not a valid pack!")
        end
        pack_data.pack_id = pack_data.pack_json.pack_id
        if pack_data.pack_json.dependencies ~= nil then
            for i = 1, #pack_data.pack_json.dependencies do
                local dependency = pack_data.pack_json.dependencies[i]
                local index_pack_id = self:_build_pack_id(dependency.disambiguator, dependency.author, dependency.name)
                local pack_json = self.metadata_pack_json_map[index_pack_id]
                if pack_json == nil then
                    error("can't find dependency '" .. index_pack_id .. "' of '" .. pack_data.pack_id .. "'.")
                end
                self:get_pack(pack_json.pack_name)
            end
        end

        log("Loading '" .. pack_data.pack_id .. "' assets")

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

        -- level data
        pack_data.levels = {}
        for contents in file_ext_read_iter(folder .. "/Levels", ".json") do
            local level_json = json.decode_jsonc(contents)
            pack_data.levels[level_json.id] = level_json
        end

        -- music
        pack_data.music = {}
        for contents in file_ext_read_iter(folder .. "/Music", ".json") do
            local music_json = json.decode_jsonc(contents)
            music_json.source = love.audio.newSource(folder .. "/Music/" .. music_json.file_name, "stream")
            pack_data.music[music_json.id] = music_json
        end

        -- shaders
        pack_data.shaders = {}
        for code, filename in file_ext_read_iter(folder .. "/Shaders", ".frag") do
            -- TODO: convert shader code to work with love
            --       - void main -> vec4 effect
            --       - gl_FragColor -> return
            --       - gl_FragCoord -> screen_coords param or love_PixelCoord
            --       - texture -> Texel
            --       - sampler2D -> Image
            --       - sampler2DArray -> ArrayImage
            --       - samplerCube -> CubeImage
            --       - sampler3D -> VolumeImage 
            -- might also need to change glsl version, can check hardware support with love.graphics.getSupported
            pack_data.shaders[filename] = love.graphics.newShader(code)
        end

        -- styles
        pack_data.styles = {}
        for contents in file_ext_read_iter(folder .. "/Styles", ".json") do
            local style_json = json.decode_jsonc(contents)
            pack_data.styles[style_json.id] = style_json
        end

        self.loaded_packs[name] = pack_data
    end
    return self.loaded_packs[name]
end

assets:init()

return assets
