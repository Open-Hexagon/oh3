-- 2.1.X compatibility mode
local LevelStatus = require("compat.game21.level_status")
local game = {
    assets = require("compat.game21.assets"),
    lua_runtime = require("compat.game21.lua_runtime"),
    running = false,
    level_data = nil,
    pack_data = nil,
    difficulty_mult = nil,
    music = nil,
    seed = nil,
    message_text = "",
    level_status = nil,
    go_sound = love.audio.newSource("assets/audio/go.ogg", "static"),
    swap_blip_sound = love.audio.newSource("assets/audio/swap_blip.ogg", "static"),
    last_move = 0,
    must_change_sides = false,
    current_rotation = 0,
    status = require("compat.game21.status"),
    style = require("compat.game21.style"),
    player = require("compat.game21.player"),
    player_now_ready_to_swap = false,
    center_pos = {0, 0}
}

function game:start(pack_folder, level_id, difficulty_mult)
    -- TODO: put this somewhere else so it can be loaded for the menu
    --       or maybe not because it caches loaded packs anyway?
    self.pack_data = self.assets:get_pack(pack_folder)

    self.level_data = self.assets.loaded_packs[pack_folder].levels[level_id]
    self.level_status = LevelStatus:new(true)    -- TODO: get bool from config
    self.style:select(self.pack_data.styles[self.level_data.styleId])
    self.style:compute_colors()
    self.difficulty_mult = difficulty_mult
    self.status:reset_all_data()

    self.music = self.pack_data.music[self.level_data.musicId]
    -- TODO: seek to other segments if not first play
    self.music.source:seek(self.music.segments[1].time)
    love.audio.play(self.music.source)

    -- initialize random seed
    -- TODO: replays
    self.seed = math.floor(love.timer.getTime() * 1000)
    math.randomseed(self.seed)
    math.random()

    -- TODO: timeline, walls, custom walls reset

    -- TODO: get player size, speed and focus speed from config
    self.player:reset(self:get_swap_cooldown(), 7.3, 9.45, 4.625)

    -- TODO: zoom, rotation reset

    self.must_change_sides = false

    -- TODO: call self.lua_runtime.env.onPreUnload if not first play

    self.lua_runtime:init_env(self, pack_folder)
    self.lua_runtime:run_lua_file(self.pack_data.path .. "/" .. self.level_data.luaFile)
    self.running = true

    -- TODO: call self.lua_runtime.env.onUnload if not first play

    self.lua_runtime.env.onInit()
    self:set_sides(self.level_status.sides)
    self.status.pulse_delay = self.status.pulse_delay + self.level_status.pulse_initial_delay
    self.status.beat_pulse_delay = self.status.beat_pulse_delay + self.level_status.beat_pulse_initial_delay

    self.status:start()
    self.message_text = ""
    love.audio.play(self.go_sound)
    self.lua_runtime.env.onLoad()
end

function game:get_swap_cooldown()
    return math.max(36 * self.level_status.swap_cooldown_mult, 8)
end

function game:set_sides(sides)
    love.audio.play(self.level_status.beep_sound)
    if sides < 3 then
        sides = 3
    end
    self.level_status.sides = sides
end

function game:update(frametime)
    frametime = frametime * 60
    -- TODO: don't update if debug pause

    -- update flash
    if self.status.flash_effect > 0 then
        self.status.flash_effect = self.status.flash_effect - 3 * frametime
    end
    if self.status.flash_effect < 0 then
        self.status.flash_effect = 0
    elseif self.status.flash_effect > 255 then
        self.status.flash_effect = 255
    end

    -- TODO: effect timeline

    -- update input
    -- TODO: get keybinds from config
    local focus = love.keyboard.isDown("lshift")
    local swap = love.keyboard.isDown("space")
    local cw = love.keyboard.isDown("right")
    local ccw = love.keyboard.isDown("left")
    local move
    if cw and not ccw then
        move = 1
    elseif not cw and ccw then
        move = -1
    elseif cw and ccw then
        move = -self.last_move
    else
        move = 0
    end
    self.last_move = move or self.last_move
    -- TODO: update key icons and level info, or in ui code?
    if self.running then
        self.style:compute_colors()
        self.player:update(focus, self.level_status.swap_enabled, frametime)
        if not self.status.has_died then
            local prevent_player_input
            if self.lua_runtime.env.onInput ~= nil then
                prevent_player_input = self.lua_runtime.env.onInput(frametime, move, focus, swap)
            end
            if not prevent_player_input then
                self.player:update_input_movement(move, self.level_status.player_speed_mult, focus, frametime)
                if not self.player_now_ready_to_swap and self.player:is_ready_to_swap() then
                    self.player_now_ready_to_swap = true
                    -- TODO: only play swap sound if enabled in config
                    love.audio.play(self.swap_blip_sound)
                end
                if self.level_status.swap_enabled and swap and self.player:is_ready_to_swap() then
                    -- TODO: swap particles
                    self.player:player_swap()
                    if self.lua_runtime.env.onCursorSwap ~= nil then
                        self.lua_runtime.env.onCursorSwap()
                    end
                    love.audio.play(self.level_status.swap_sound)
                    self.player:reset_swap(self:get_swap_cooldown())
                    self.player:set_just_swapped(true)
                    self.player_now_ready_to_swap = true
                else
                    self.player:set_just_swapped(false)
                end
            end
            self.status:accumulate_frametime(frametime)
            if self.level_status.score_overwritten then
                self.status:update_custom_score(self.lua_runtime.env[self.level_status.score_overwrite])
            end
            -- TODO: update event and message timeline
            -- increment
            if self.level_status.inc_enabled and self.status:get_increment_time_seconds() < self.level_status.inc_time then
                self.level_status.current_increments = self.level_status.current_increments + 1
                -- TODO: increment difficulty
                self.status:reset_increment_time()
                self.must_change_sides = true
            end

            -- TODO: when no walls and must side change, do side change

            if not self.status:is_time_paused() then
                if self.lua_runtime.env.onUpdate ~= nil then
                    self.lua_runtime.env.onUpdate(frametime)
                end
                -- TODO: update main timeline and call onStep unless game must change sides
            end
            -- TODO: update custom timelines
            -- TODO: update beatpulse
            -- TODO: update pulse

            -- TODO: only if not black and white
            self.style:update(frametime, math.pow(self.difficulty_mult, 0.8))

            self.player:update_position(self.status.radius)
            -- TODO: update walls
            -- TODO: update custom walls
        else
            self.level_status.rotation_speed = self.level_status.rotation_speed * 0.99
        end

        -- TODO: update 3d pulse
        -- update rotation
        local next_rotation = self.level_status.rotation_speed * 10
        if self.status.fast_spin > 0 then
            local function get_sign(num)
                return (num > 0 and 1 or (num == 0 and 0 or -1))
            end
            local function get_smoother_step(edge0, edge1, x)
                x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
                return x * x * x * (x * (x * 6 - 15) + 10)
            end
            next_rotation = next_rotation + math.abs((get_smoother_step(0, self.level_status.fast_spin, self.status.fast_spin) / 3.5) * 17) * get_sign(next_rotation)
            self.status.fast_spin = self.status.fast_spin - frametime
        end
        self.current_rotation = self.current_rotation + next_rotation * frametime
        -- TODO: update camera shake

        if not self.status.has_died then
            math.random(math.abs(self.status.pulse * 1000))
            math.random(math.abs(self.status.pulse3D * 1000))
            math.random(math.abs(self.status.fast_spin * 1000))
            math.random(math.abs(self.status.flash_effect * 1000))
            math.random(math.abs(self.level_status.rotation_speed * 1000))
        end

        -- TODO: update particles (trail and swap)

        if self.status.must_state_change ~= "none" then
            -- other values are "mustRestart" or "mustReplay"
            -- so currently the only possebility is "mustRestart"
            self:start(self.pack_data.path, self.level_data.id, self.difficulty_mult)
        end
        -- TODO: if 3d off but required invalidate score
        -- TODO: if shaders off but required invalidate score
    end
end

function game:draw(width, height)
    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / width, 768 / height)
    love.graphics.scale(zoom_factor, zoom_factor)

    -- apply rotation
    love.graphics.rotate(math.rad(self.current_rotation))

    if not self.status.has_died then
        if self.level_status.camera_shake > 0 then
            self.center_pos[1] = (math.random() * 2 - 1) * self.level_status.camera_shake
            self.center_pos[2] = (math.random() * 2 - 1) * self.level_status.camera_shake
        else
            self.center_pos[1] = 0
            self.center_pos[2] = 0
        end
    end
    -- TODO: apply right shaders when rendering
    -- TODO: only draw background if not disabled in config
    self.style:draw_background({0, 0}, self.level_status.sides, true, false)
    -- TODO: draw 3d if enabled in config
    -- TODO: draw walls

    -- TODO: get tilt intensity and swap blink effect from config
    self.player:draw(self.level_status.sides, self.style, 1, true)

    -- TODO: draw particles, text, flash
end

return game
