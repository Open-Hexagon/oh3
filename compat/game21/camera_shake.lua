local shake = {}
local death_shake_translate = { 0, 0 }
local game, public

function shake.init(pass_game, pass_public)
    game = pass_game
    public = pass_public
end

function shake.start()
    game.status.camera_shake = 45 * public.config.get("camera_shake_mult")
end

function shake.update(frametime)
    if game.status.camera_shake <= 0 then
        death_shake_translate[1] = 0
        death_shake_translate[2] = 0
    else
        game.status.camera_shake = game.status.camera_shake - frametime
        local i = game.status.camera_shake
        death_shake_translate[1] = game.rng.get_real(-i, i)
        death_shake_translate[2] = game.rng.get_real(-i, i)
    end
end

function shake.apply()
    -- normal death shake
    love.graphics.translate(unpack(death_shake_translate))

    if not game.status.has_died then
        -- custom shake from level
        if game.level_status.camera_shake > 0 then
            love.graphics.translate(
                -- use love.math.random instead of math.random to not break replay rng
                (love.math.random() * 2 - 1) * game.level_status.camera_shake,
                (love.math.random() * 2 - 1) * game.level_status.camera_shake
            )
        end
    end
end

return shake
