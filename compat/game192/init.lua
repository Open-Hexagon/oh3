local assets = require("compat.game192.assets")
local public = {}


function public.start(pack_folder, level_id, difficulty_mult)
    local pack = assets.get_pack(pack_folder)
    local level_data = pack.levels[level_id]
    if level_data == nil then
        error("Level with id '" .. level_id .. "' not found")
    end
end

function public.update(frametime)
    -- TODO
end

function public.draw(screen)
    -- TODO
end

return public
