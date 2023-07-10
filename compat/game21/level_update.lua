local utils = require("compat.game192.utils")
local playsound = require("compat.game21.playsound")
return function(game, frametime)
    -- update time/score
    game.status.accumulate_frametime(frametime)
    if game.level_status.score_overwritten then
        game.status.update_custom_score(game.lua_runtime.env[game.level_status.score_overwrite])
    end

    -- update timeline events
    if game.event_timeline:update(game.status.get_time_tp()) then
        game.event_timeline:clear()
    end
    if game.message_timeline:update(game.status.get_current_tp()) then
        game.message_timeline:clear()
    end

    -- increment after a while
    if game.level_status.inc_enabled and game.status.get_increment_time_seconds() >= game.level_status.inc_time then
        game.level_status.current_increments = game.level_status.current_increments + 1
        game.increment_difficulty()
        game.status.reset_increment_time()
        game.must_change_sides = true
    end

    -- change sides after increment
    if game.must_change_sides and game.walls.empty() then
        local side_number = game.rng.get_int(game.level_status.sides_min, game.level_status.sides_max)
        game.level_status.speed_mult = utils.float_round(game.level_status.speed_mult + game.level_status.speed_inc)
        game.level_status.delay_mult = utils.float_round(game.level_status.delay_mult + game.level_status.delay_inc)
        if game.level_status.rnd_side_changes_enabled then
            game.set_sides(side_number)
        end
        game.must_change_sides = false
        playsound(game.level_status.level_up_sound)
        game.lua_runtime.run_fn_if_exists("onIncrement")
    end

    -- onUpdate, main timeline and onStep
    if not game.status.is_time_paused() then
        game.lua_runtime.run_fn_if_exists("onUpdate", frametime)
        if game.main_timeline:update(game.status.get_time_tp()) and not game.must_change_sides then
            game.main_timeline:clear()
            game.lua_runtime.run_fn_if_exists("onStep")
        end
    end
end
