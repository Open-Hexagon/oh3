local playsound = require("compat.game21.playsound")
local config = require("config")
local game_input = require("game_handler.input")
local args = require("args")
local lua_runtime = require("compat.game21.lua_runtime")
local level_status = require("compat.game21.level_status")
local status = require("compat.game21.status")
local player = require("compat.game21.player")
local assets = require("compat.game21.assets")
local input = {
    move = 0,
}
local game, swap_particles, swap_blip_sound

function input.init(pass_game, particles)
    game = pass_game
    swap_particles = particles
    if not args.headless then
        swap_blip_sound = assets.get_sound("swap_blip.ogg")
    end
end

function input.update(frametime)
    local focus = game_input.get(config.get("key_focus"))
    local swap = game_input.get(config.get("key_swap"))
    local cw = game_input.get(config.get("key_right"))
    local ccw = game_input.get(config.get("key_left"))
    if cw and not ccw then
        input.move = 1
        game.last_move = 1
    elseif not cw and ccw then
        input.move = -1
        game.last_move = -1
    elseif cw and ccw then
        input.move = -game.last_move
    else
        input.move = 0
    end
    -- TODO: update key icons and level info (needs ui)
    player.update(focus, level_status.swap_enabled, frametime)
    if not status.has_died then
        local prevent_player_input = lua_runtime.run_fn_if_exists("onInput", frametime, input.move, focus, swap)
        if not prevent_player_input then
            player.update_input_movement(input.move, level_status.player_speed_mult, focus, frametime)
            if not game.player_now_ready_to_swap and player.is_ready_to_swap() then
                swap_particles.ready()
                game.player_now_ready_to_swap = true
                if config.get("play_swap_sound") then
                    playsound(swap_blip_sound)
                end
            end
            if level_status.swap_enabled and swap and player.is_ready_to_swap() then
                swap_particles.swap()
                game.perform_player_swap(true)
                player.reset_swap(game.get_swap_cooldown())
                player.set_just_swapped(true)
                game.player_now_ready_to_swap = false
            else
                player.set_just_swapped(false)
            end
        end
    end
end

return input
