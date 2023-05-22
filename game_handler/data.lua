local data = {}
local packs = {}
local pack_id_map = {}
local pack_count = 0

function data.register_pack(id, name, game_version)
    pack_count = pack_count + 1
    packs[pack_count] = {
        id = id,
        name = name,
        game_version = game_version,
        levels = {},
        level_count = 0,
    }
    pack_id_map[id] = packs[pack_count]
end

function data.register_level(pack_id, id, name, options)
    local pack = pack_id_map[pack_id]
    if pack == nil then
        error("Attempted to register level for non-existing pack")
    end
    pack.level_count = pack.level_count + 1
    pack.levels[pack.level_count] = {
        id = id,
        name = name,
        options = options or {},
    }
end

function data.get_packs()
    return packs
end

return data
