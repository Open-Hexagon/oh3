local log = require("log")(...)
local args = require("args")
local json = require("extlibs.json.jsonc")

local loaded_packs = {}
local pack_path = "packs21/"
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
local loaded_images = {}

local assets = {
    pack_ids = {},
}

function assets._build_pack_id(disambiguator, author, name, version)
    local pack_id = disambiguator .. "_" .. author .. "_" .. name
    if version ~= nil then
        pack_id = pack_id .. "_" .. math.floor(version)
    end
    pack_id = pack_id:gsub(" ", "_")
    return pack_id
end

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

function assets.init(data)
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

        local pack_json_contents = love.filesystem.read(folder .. "/pack.json")
        if pack_json_contents == nil then
            error("Failed to load pack.json")
        end
        local decode_success, pack_json = decode_json(pack_json_contents)
        if decode_success then
            pack_json.pack_id =
                assets._build_pack_id(pack_json.disambiguator, pack_json.author, pack_json.name, pack_json.version)
            local index_pack_id = assets._build_pack_id(pack_json.disambiguator, pack_json.author, pack_json.name)
            assets.pack_ids[#assets.pack_ids + 1] = index_pack_id
            pack_json.pack_name = pack_folders[i]
            metadata_pack_json_map[index_pack_id] = pack_json
            folder_pack_json_map[folder] = pack_json

            data.register_pack(index_pack_id, pack_json.pack_name, 21)

            -- level data has to be loaded here for level selection purposes
            pack_json.levels = {}
            for contents, filename in file_ext_read_iter(folder .. "/Levels", ".json") do
                local success, level_json = decode_json(contents, filename)
                if success then
                    level_json.difficultyMults = level_json.difficultyMults or {}
                    local has1 = false
                    for j = 1, #level_json.difficultyMults do
                        if level_json.difficultyMults[j] == 1 then
                            has1 = true
                            break
                        end
                    end
                    if not has1 then
                        level_json.difficultyMults[#level_json.difficultyMults + 1] = 1
                    end
                    data.register_level(index_pack_id, level_json.id, level_json.name, {
                        difficulty_mult = level_json.difficultyMults,
                    })
                    pack_json.levels[level_json.id] = level_json
                end
            end
        end
    end
end

function assets.get_pack_from_metadata(disambiguator, author, name)
    return assets.get_pack_from_id(assets._build_pack_id(disambiguator, author, name))
end

function assets.get_pack_from_id(id)
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

        -- move the table to its proper place
        pack_data.levels = pack_data.pack_json.levels
        pack_data.pack_json.levels = nil

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

        if not args.headless then
            -- music
            pack_data.music = {}
            for contents, filename in file_ext_read_iter(folder .. "/Music", ".json") do
                local success, music_json = decode_json(contents, filename)
                if success then
                    music_json.file_name = music_json.file_name or filename:gsub("%.json", ".ogg")
                    if music_json.file_name:sub(-4) ~= ".ogg" then
                        music_json.file_name = music_json.file_name .. ".ogg"
                    end
                    if
                        not pcall(function()
                            music_json.source =
                                love.audio.newSource(folder .. "/Music/" .. music_json.file_name, "stream")
                            music_json.source:setLooping(true)
                        end)
                    then
                        log("Error: failed to load '" .. music_json.file_name .. "'")
                    end
                    pack_data.music[music_json.id] = music_json
                end
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
                        #ifdef INITVARS
                        _new_wrap_init_glob_vars();
                        #endif
                        _old_wrapped_main();
                        #ifdef TEXT
                        return _new_wrap_pixel_color * Texel(tex, VaryingTexCoord.xy);
                        #else
                        return _new_wrap_pixel_color;
                        #endif
                    }
                ]]
                -- remove lines starting with #version
                -- translate switch to if statements
                -- interpret layout(location = 0) out...
                -- get globals to initialize later
                local new_code = ""
                local block_depth = 0
                local need_to_initialize_later = {}
                local other_frag_color_name
                local in_switch, switch_var, switch_first
                for line in code:gmatch("([^\n]*)\n?") do
                    line = line:gsub("\r", "")
                    do
                        local new_line = ""
                        for i = 1, #line do
                            if line:sub(i, i + 1) == "//" then
                                break
                            end
                            new_line = new_line .. line:sub(i, i)
                        end
                        line = new_line
                    end
                    local _, open_count = line:gsub("{", "")
                    local _, close_count = line:gsub("}", "")
                    block_depth = block_depth + open_count - close_count
                    if line:gsub(" ", ""):match("switch%(") then
                        in_switch = "waiting"
                        switch_var = line:match("%((%a+)%)")
                        switch_first = true
                    end
                    if in_switch == "waiting" then
                        if line:match("{") then
                            in_switch = block_depth
                        end
                        line = ""
                    end
                    if in_switch ~= nil and in_switch ~= "waiting" then
                        if line:match("case") then
                            if switch_first then
                                line = line:gsub("case", "if(" .. switch_var .. " =="):gsub(":", ") {")
                            else
                                line = line:gsub("case", "} else if(" .. switch_var .. " =="):gsub(":", ") {")
                            end
                            switch_first = false
                        elseif line:match("default") then
                            line = line:gsub("default:", "} else {")
                        end
                        if block_depth == in_switch - 1 then
                            in_switch = nil
                        end
                    end
                    if block_depth == 0 and line:match("=") ~= nil then
                        local new_line = ""
                        for statement in line:gmatch("([^;]*);?") do
                            local no_space_string = statement:gsub(" ", ""):gsub("\t", "")
                            if no_space_string ~= "" then
                                if no_space_string:match("layout%(") ~= nil then
                                    if no_space_string:match("location=0%)outvec4") ~= nil then
                                        local index = no_space_string:find("4")
                                        if index ~= nil then
                                            other_frag_color_name = no_space_string:sub(index + 1)
                                        end
                                    end
                                else
                                    local key, key_index
                                    key_index = statement:find("=")
                                    if key_index ~= nil then
                                        key = statement:sub(1, key_index - 1)
                                    end
                                    if key == nil or key:match("const ") ~= nil then
                                        new_line = new_line .. statement .. ";"
                                    else
                                        local value = statement:sub(key_index + 1)
                                        need_to_initialize_later[#need_to_initialize_later + 1] = { key, value }
                                        new_line = new_line .. key .. ";"
                                    end
                                end
                            end
                        end
                        line = new_line
                    end
                    local has_version = line:gsub(" ", ""):sub(1, 8) == "#version"
                    if not has_version then
                        new_code = new_code .. line .. "\n"
                    end
                end
                if need_to_initialize_later[1] ~= nil then
                    local add_to_top = "#define INITVARS\n\nvoid _new_wrap_init_glob_vars() {"
                    for j = 1, #need_to_initialize_later do
                        local variable, value = unpack(need_to_initialize_later[j])
                        local space_index = 1
                        local first = true
                        for i = 1, #variable do
                            if variable:sub(i, i) == " " then
                                if not first then
                                    space_index = i
                                    break
                                end
                            else
                                first = false
                            end
                        end
                        add_to_top = add_to_top .. "\n    " .. variable:sub(space_index + 1) .. "=" .. value .. ";"
                    end
                    add_to_top = add_to_top .. "\n}\n"
                    new_code = new_code:gsub("vec4 effect%(", add_to_top .. "\nvec4 effect(")
                end
                if other_frag_color_name ~= nil then
                    new_code = new_code:gsub("_new_wrap_pixel_color", other_frag_color_name)
                end
                xpcall(function()
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
                        local pos = line:find("uniform")
                        if pos ~= nil then
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
                    pack_data.shaders[filename] = {
                        uniforms = uniforms,
                        shader = shader,
                        instance_shader = instance_shader,
                        text_shader = love.graphics.newShader("#define TEXT\n" .. new_code),
                    }
                end, function(msg)
                    log("Failed compiling shader: '" .. filename .. "':\n" .. msg)
                end)
            end
        end

        -- styles
        pack_data.styles = {}
        for contents, filename in file_ext_read_iter(folder .. "/Styles", ".json") do
            local success, style_json = decode_json(contents, filename)
            if success then
                pack_data.styles[style_json.id] = style_json
            end
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

function assets.get_image(name)
    if loaded_images[name] == nil then
        loaded_images[name] = love.graphics.newImage("assets/image/" .. name)
    end
    return loaded_images[name]
end

return assets
