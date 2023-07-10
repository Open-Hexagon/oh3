local playsound = require("compat.game21.playsound")
local args = require("args")
local input = {
    move = 0,
}
local public, game, swap_particles, swap_blip_sound

function input.init(pass_game, pass_public, particles, assets)
    game = pass_game
    public = pass_public
    swap_particles = particles
    if not args.headless then
        swap_blip_sound = assets.get_sound("swap_blip.ogg")
    end
end

function input.update(frametime)
    local focus = game.input.get(public.config.get("key_focus"))
    local swap = game.input.get(public.config.get("key_swap"))
    local cw = game.input.get(public.config.get("key_right"))
    local ccw = game.input.get(public.config.get("key_left"))
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
    game.player.update(focus, game.level_status.swap_enabled, frametime)
    if not game.status.has_died then
        local prevent_player_input = game.lua_runtime.run_fn_if_exists("onInput", frametime, input.move, focus, swap)
        if not prevent_player_input then
            game.player.update_input_movement(input.move, game.level_status.player_speed_mult, focus, frametime)
            if not game.player_now_ready_to_swap and game.player.is_ready_to_swap() then
                swap_particles.ready(game)
                game.player_now_ready_to_swap = true
                if public.config.get("play_swap_sound") then
                    playsound(swap_blip_sound)
                end
            end
            if game.level_status.swap_enabled and swap and game.player.is_ready_to_swap() then
                swap_particles.swap(game)
                game.perform_player_swap(true)
                game.player.reset_swap(game.get_swap_cooldown())
                game.player.set_just_swapped(true)
                game.player_now_ready_to_swap = false
            else
                game.player.set_just_swapped(false)
            end
        end
    end
end

return input
