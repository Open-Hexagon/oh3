local log = require("log")(...)
local json = require("extlibs.json.jsonc")

local assets = {
    loaded_packs = {},
    pack_path = "Packs/",
    lua_file_cache = {}
}

function assets:load_lua_file(pack_folder, path)
    path = self.pack_path .. pack_folder .. "/" .. path
    if self.lua_file_cache[path] == nil then
        self.lua_file_cache[path] = loadfile(path)
    end
    return self.lua_file_cache[path]
end

function assets:load_pack(name)
    if self.loaded_packs[name] == nil then
        local folder = self.pack_path .. name

        -- check validity
        do
            local files = love.filesystem.getDirectoryItems(folder)
            local function check_file(file)
                local is_in = false
                for i = 1, #files do
                    if files[i] == file then
                        is_in = true
                    end
                end
                if not is_in then
                    error("Invalid pack " .. folder .. ", " .. file .. " does not exist!")
                end
            end
            check_file("pack.json")
            check_file("Scripts")
        end

        local pack_data = {
            path = folder
        }

        -- pack metadata
        do
            local contents = love.filesystem.read(folder .. "/pack.json")
            if contents == nil then
                error("Failed to load pack.json")
            end
            pack_data.pack_json = json.decode_jsonc(contents)
            pack_data.pack_id = pack_data.pack_json.disambiguator
                .. "_"
                .. pack_data.pack_json.author
                .. "_"
                .. pack_data.pack_json.name
                .. "_"
                .. math.floor(pack_data.pack_json.version)
            pack_data.pack_id = pack_data.pack_id:gsub(" ", "_")
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

return assets
