local args = require("args")
local music = require("compat.music")

return function(game, assets)
    local pack = game.pack_data
    local lua_runtime = game.lua_runtime
    local env = lua_runtime.env
    env.a_setMusic = function(music_id)
        env.a_setMusicSegment(music_id, 0)
    end
    env.a_setMusicSegment = function(music_id, segment)
        local new_music = game.pack_data.music[music_id]
        if new_music == nil then
            lua_runtime.error("Music with id '" .. music_id .. "' doesn't exist!")
        else
            music.stop()
            music.play(new_music, segment + 1, nil, game.refresh_music_pitch())
        end
    end
    env.a_setMusicSeconds = function(music_id, seconds)
        local new_music = game.pack_data.music[music_id]
        if new_music == nil then
            lua_runtime.error("Music with id '" .. music_id .. "' doesn't exist!")
        else
            music.stop()
            music.play(new_music, false, seconds, game.refresh_music_pitch())
        end
    end
    env.a_playSound = function(sound_id)
        if not args.headless then
            local sound = assets.get_sound(sound_id)
            if sound == nil then
                lua_runtime.error("Sound with id '" .. sound_id .. "' doesn't exist!")
            else
                sound:seek(0)
                sound:play()
            end
        end
    end
    local function get_pack_sound(sound_id)
        if not args.headless then
            local sound = assets.get_pack_sound(pack, sound_id)
            if sound == nil then
                lua_runtime.error("Pack Sound with id '" .. sound_id .. "' doesn't exist!")
            else
                return sound
            end
        end
    end
    env.a_playPackSound = function(sound_id)
        local sound = get_pack_sound(sound_id)
        if sound ~= nil then
            sound:seek(0)
            sound:play()
        end
    end
    env.a_syncMusicToDM = function(value)
        game.level_status.sync_music_to_dm = value
    end
    env.a_setMusicPitch = function(pitch)
        game.level_status.music_pitch = pitch
        game.refresh_music_pitch()
    end
    env.a_overrideBeepSound = function(filename)
        game.level_status.beep_sound = get_pack_sound(filename) or game.level_status.beep_sound
    end
    env.a_overrideIncrementSound = function(filename)
        game.level_status.level_up_sound = get_pack_sound(filename) or game.level_status.level_up_sound
    end
    env.a_overrideSwapSound = function(filename)
        game.level_status.swap_sound = get_pack_sound(filename) or game.level_status.swap_sound
    end
    env.a_overrideDeathSound = function(filename)
        game.level_status.death_sound = get_pack_sound(filename) or game.level_status.death_sound
    end

    -- deprecated
    env.u_playSound = env.a_playSound
end
