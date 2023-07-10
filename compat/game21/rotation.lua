local rotation = {}

local function get_sign(num)
    return (num > 0 and 1 or (num == 0 and 0 or -1))
end
local function get_smoother_step(edge0, edge1, x)
    x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return x * x * x * (x * (x * 6 - 15) + 10)
end

function rotation.update(game, frametime)
    local next_rotation = game.level_status.rotation_speed * 10
    if game.status.fast_spin > 0 then
        next_rotation = next_rotation
            + math.abs(
                    (get_smoother_step(0, game.level_status.fast_spin, game.status.fast_spin) / 3.5) * 17
                )
                * get_sign(next_rotation)
        game.status.fast_spin = game.status.fast_spin - frametime
    end
    game.current_rotation = game.current_rotation + next_rotation * frametime
end

function rotation.apply(game)
    love.graphics.rotate(-math.rad(game.current_rotation))
end

return rotation
