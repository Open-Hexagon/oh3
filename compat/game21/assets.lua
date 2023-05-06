local log = require("log")(...)
local json = require("extlibs.json.jsonc")

local loaded_packs = {}
local pack_path = "Packs/"
local metadata_pack_json_map = {}
local folder_pack_json_map = {}
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

local assets = {}

function assets._build_pack_id(disambiguator, author, name, version)
    local pack_id = disambiguator .. "_" .. author .. "_" .. name
    if version ~= nil then
        pack_id = pack_id .. "_" .. math.floor(version)
    end
    pack_id = pack_id:gsub(" ", "_")
    return pack_id
end

function assets.init()
    local pack_folders = love.filesystem.getDirectoryItems(pack_path)
    for i = 1, #pack_folders do
        local folder = pack_path .. pack_folders[i]
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
        pack_json.pack_id =
            assets._build_pack_id(pack_json.disambiguator, pack_json.author, pack_json.name, pack_json.version)
        local index_pack_id = assets._build_pack_id(pack_json.disambiguator, pack_json.author, pack_json.name)
        pack_json.pack_name = pack_folders[i]
        metadata_pack_json_map[index_pack_id] = pack_json
        folder_pack_json_map[folder] = pack_json
    end
end

function assets.get_pack_from_metadata(disambiguator, author, name)
    local id = assets._build_pack_id(disambiguator, author, name)
    local pack = metadata_pack_json_map[id]
    if pack == nil then
        error("Pack with id '" .. id .. "' not found.")
    end
    return assets.get_pack(pack.pack_name)
end

function assets.get_pack(name)
    if loaded_packs[name] == nil then
        local folder = pack_path .. name

        local pack_data = {
            path = folder,
        }

        -- pack metadata
        pack_data.pack_json = folder_pack_json_map[folder]
        if pack_data.pack_json == nil then
            error(folder .. " doesn't exist or is not a valid pack!")
        end
        pack_data.pack_id = pack_data.pack_json.pack_id
        if pack_data.pack_json.dependencies ~= nil then
            for i = 1, #pack_data.pack_json.dependencies do
                local dependency = pack_data.pack_json.dependencies[i]
                local index_pack_id =
                    assets._build_pack_id(dependency.disambiguator, dependency.author, dependency.name)
                local pack_json = metadata_pack_json_map[index_pack_id]
                if pack_json == nil then
                    error("can't find dependency '" .. index_pack_id .. "' of '" .. pack_data.pack_id .. "'.")
                end
                -- fix recursive dependencies
                if pack_json.pack_name ~= name then
                    assets.get_pack(pack_json.pack_name)
                end
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
            if
                not pcall(function()
                    music_json.source = love.audio.newSource(folder .. "/Music/" .. music_json.file_name, "stream")
                end)
            then
                log("Error: failed to load '" .. music_json.file_name .. "'")
            end
            pack_data.music[music_json.id] = music_json
        end

        -- shaders
        pack_data.shaders = {}
        for code, filename in file_ext_read_iter(folder .. "/Shaders", ".frag") do
            -- replace gl_ variables with love stuff
            code = [[
                vec4 _new_wrap_pixel_color;
                vec4 _new_wrap_original_pixel_color;
                vec2 _new_wrap_pixel_coord;
            ]] .. code:gsub("void main", "void _old_wrapped_main")
                :gsub("gl_FragCoord", "_new_wrap_pixel_coord")
                :gsub("gl_FragColor", "_new_wrap_pixel_color")
                :gsub("gl_TexCoord.0.", "VaryingTexCoord")
                :gsub("texture", "Texel")
                :gsub("gl_Color", "_new_wrap_original_pixel_color") .. [[
                vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
                    _new_wrap_original_pixel_color = color;
                    _new_wrap_pixel_coord = screen_coords;
                    _new_wrap_pixel_coord.y = love_ScreenSize.y - _new_wrap_pixel_coord.y;
                    _old_wrapped_main();
                    #ifdef TEXT
                    return _new_wrap_pixel_color * Texel(tex, VaryingTexCoord.xy);
                    #else
                    return _new_wrap_pixel_color;
                    #endif
                }
            ]]
            -- remove lines starting with #version
            local new_code = ""
            for line in code:gmatch("([^\n]*)\n?") do
                if line:gsub(" ", ""):sub(1, 8) ~= "#version" then
                    new_code = new_code .. line .. "\n"
                end
            end
            local shader = love.graphics.newShader(new_code)
            -- compile the shader a second time but with 3d layer offset instance code
            -- (since we don't know where the shader will be used yet and we don't wanted
            -- to slow down the game with runtime compilation)
            local instance_shader = love.graphics.newShader(
                [[
                    attribute vec2 instance_position;
                    attribute vec4 instance_color;
                    varying vec4 instance_color_out;

                    vec4 position(mat4 transform_projection, vec4 vertex_position)
                    {
                        instance_color_out = instance_color / 255.0;
                        vertex_position.xy += instance_position;
                        return transform_projection * vertex_position;
                    }
                ]],
                [[
                    varying vec4 instance_color_out;
                ]]
                    .. new_code:gsub(
                        "_new_wrap_original_pixel_color = color;",
                        "_new_wrap_original_pixel_color = instance_color_out;"
                    )
            )
            -- store uniforms
            local uniforms = {}
            for line in code:gmatch("([^;]*);?") do
                for pos = 1, #line do
                    if line:sub(pos, 6 + pos) == "uniform" then
                        local uni_string = line:sub(pos + 8)
                        local space_pos = uni_string:find(" ")
                        local uni_name = uni_string:sub(space_pos + 1)
                        -- in case it was optimized out
                        if shader:hasUniform(uni_name) then
                            local uni_type = uni_string:sub(1, space_pos - 1)
                            uniforms[uni_name] = uni_type
                        end
                    end
                end
            end
            pack_data.shaders[filename] = {
                uniforms = uniforms,
                shader = shader,
                instance_shader = instance_shader,
                text_shader = love.graphics.newShader("#define TEXT\n" .. new_code),
            }
        end

        -- styles
        pack_data.styles = {}
        for contents in file_ext_read_iter(folder .. "/Styles", ".json") do
            local style_json = json.decode_jsonc(contents)
            pack_data.styles[style_json.id] = style_json
        end

        -- sounds
        pack_data.sounds = love.filesystem.getDirectoryItems(folder .. "/Sounds")
        pack_data.cached_sounds = {}

        loaded_packs[name] = pack_data
    end
    return loaded_packs[name]
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
        pack.cached_sounds[id] = love.audio.newSource(pack.path .. "/Sounds/" .. id, "static")
    end
    return pack.cached_sounds[id]
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

assets.init()

return assets
