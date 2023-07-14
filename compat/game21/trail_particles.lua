local Particles = require("compat.game21.particles")
local trail_particles = {}
local particle_system
local game

function trail_particles.init(assets, pass_game)
    game = pass_game
    if not particle_system then
        local small_circle = assets.get_image("smallCircle.png")
        particle_system = Particles:new(small_circle, function(p, frametime)
            p.color[4] = p.color[4] - particle_system.alpha_decay / 255 * frametime
            p.scale = p.scale * 0.98
            local distance = game.status.radius + 2.4
            p.x, p.y = math.cos(p.angle) * distance, math.sin(p.angle) * distance
            return p.color[4] <= 3 / 255
        end, game.config.get("player_trail_alpha"), game.config.get("player_trail_decay"))
    end
    particle_system:reset()
end

function trail_particles.update(frametime, current_trail_color)
    particle_system:update(frametime)
    if game.player.has_changed_angle() then
        local x, y = game.player.get_position()
        particle_system:emit(
            x,
            y,
            game.config.get("player_trail_scale"),
            game.player.get_player_angle(),
            unpack(current_trail_color)
        )
    end
end

function trail_particles.draw()
    love.graphics.draw(particle_system.batch)
end

return trail_particles
