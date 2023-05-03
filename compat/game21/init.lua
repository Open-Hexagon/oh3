-- 2.1.X compatibility mode
local Timeline = require("compat.game21.timeline")
local set_color = require("compat.game21.color_transform")
local game = {
    assets = require("compat.game21.assets"),
    lua_runtime = require("compat.game21.lua_runtime"),
    level_status = require("compat.game21.level_status"),
    running = false,
    level_data = nil,
    pack_data = nil,
    difficulty_mult = nil,
    music = nil,
    seed = nil,
    message_text = "",
    go_sound = love.audio.newSource("assets/audio/go.ogg", "static"),
    swap_blip_sound = love.audio.newSource("assets/audio/swap_blip.ogg", "static"),
    level_up_sound = love.audio.newSource("assets/audio/level_up.ogg", "static"),
    restart_sound = love.audio.newSource("assets/audio/restart.ogg", "static"),
    select_sound = love.audio.newSource("assets/audio/select.ogg", "static"),
    last_move = 0,
    must_change_sides = false,
    current_rotation = 0,
    status = require("compat.game21.status"),
    style = require("compat.game21.style"),
    player = require("compat.game21.player"),
    player_now_ready_to_swap = false,
    event_timeline = Timeline:new(),
    message_timeline = Timeline:new(),
    main_timeline = Timeline:new(),
    center_pos = { 0, 0 },
    first_play = true,
    walls = require("compat.game21.walls"),

    -- TODO: check if the inital values cause issues (may need the values from the canvas instead here)
    width = love.graphics.getWidth(),
    height = love.graphics.getHeight(),
}

game.message_font = game.assets:get_font("OpenSquare-Regular.ttf", 32)

function game:start(pack_folder, level_id, difficulty_mult)
    -- TODO: put this somewhere else so it can be loaded for the menu
    --       or maybe not because it caches loaded packs anyway?
    self.pack_data = self.assets:get_pack(pack_folder)
    self.level_data = self.assets.loaded_packs[pack_folder].levels[level_id]
    self.level_status:reset(true) -- TODO: get bool from config
    self.style:select(self.pack_data.styles[self.level_data.styleId])
    self.style:compute_colors()
    self.difficulty_mult = difficulty_mult
    self.status:reset_all_data()
    self.music = self.pack_data.music[self.level_data.musicId]
    if self.music == nil then
        error("Music with id '" .. self.level_data.musicId .. "' doesn't exist!")
    end
    self:refresh_music_pitch()
    local music_time
    if self.first_play then
        music_time = self.music.segments[1].time
    else
        music_time = self.music.segments[math.random(1, #self.music.segments)].time
    end
    self.music.source:seek(music_time)
    love.audio.play(self.music.source)

    -- initialize random seed
    -- TODO: replays (need to read random seed from there)
    self.seed = math.floor(love.timer.getTime() * 1000)
    math.randomseed(self.seed)
    math.random()

    self.event_timeline:clear()
    self.message_timeline:clear()

    -- TODO: custom timeline reset

    self.walls:reset(self.level_status)

    -- TODO: custom walls reset

    -- TODO: get player size, speed and focus speed from config
    self.player:reset(self:get_swap_cooldown(), 7.3, 9.45, 4.625)

    -- TODO: zoom reset

    self.current_rotation = 0
    self.must_change_sides = false
    if not self.first_play and self.lua_runtime.env.onPreUnload ~= nil then
        self.lua_runtime.onPreUnload()
    end
    self.lua_runtime:init_env(self, pack_folder)
    self.lua_runtime:run_lua_file(self.pack_data.path .. "/" .. self.level_data.luaFile)
    self.running = true
    if self.first_play then
        love.audio.play(self.select_sound)
    else
        if self.lua_runtime.env.onUnload ~= nil then
            self.lua_runtime.onUnload()
        end
        love.audio.play(self.restart_sound)
    end
    self.lua_runtime.env.onInit()
    self:set_sides(self.level_status.sides)
    self.status.pulse_delay = self.status.pulse_delay + self.level_status.pulse_initial_delay
    self.status.beat_pulse_delay = self.status.beat_pulse_delay + self.level_status.beat_pulse_initial_delay
    self.status:start()
    self.message_text = ""
    love.audio.play(self.go_sound)
    self.lua_runtime.env.onLoad()
end

function game:get_speed_mult_dm()
    local result = self.level_status.speed_mult * math.pow(self.difficulty_mult, 0.65)
    if not self.level_status:has_speed_max_limit() then
        return result
    end
    return result < self.level_status.speed_max and result or self.level_status.speed_max
end

function game:perform_player_swap(play_sound)
    self.player:player_swap()
    if self.lua_runtime.env.onCursorSwap ~= nil then
        self.lua_runtime.env.onCursorSwap()
    end
    if play_sound then
        love.audio.play(self.level_status.swap_sound)
    end
end

function game:refresh_music_pitch()
    -- TODO: account for config music speed mult
    self.music.source:setPitch(
        self.level_status.music_pitch
            * (self.level_status.sync_music_to_dm and math.pow(self.difficulty_mult, 0.12) or 1)
    )
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

function game:increment_difficulty()
    love.audio.play(self.level_up_sound)
    local sign_mult = self.level_status.rotation_speed > 0 and 1 or -1
    self.level_status.rotation_speed = self.level_status.rotation_speed
        + self.level_status.rotation_speed_inc * sign_mult
    if math.abs(self.level_status.rotation_speed) > self.level_status.rotation_speed_max then
        self.level_status.rotation_speed = self.level_status.rotation_speed_max * sign_mult
    end
    self.level_status.rotation_speed = -self.level_status.rotation_speed
    self.status.fast_spin = self.level_status.fast_spin
end

-- TODO: (not sure where) music restart
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
        self.last_move = 1
    elseif not cw and ccw then
        move = -1
        self.last_move = -1
    elseif cw and ccw then
        move = -self.last_move
    else
        move = 0
    end
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
                    self:perform_player_swap(true)
                    self.player:reset_swap(self:get_swap_cooldown())
                    self.player:set_just_swapped(true)
                    self.player_now_ready_to_swap = false
                else
                    self.player:set_just_swapped(false)
                end
            end
            self.status:accumulate_frametime(frametime)
            if self.level_status.score_overwritten then
                self.status:update_custom_score(self.lua_runtime.env[self.level_status.score_overwrite])
            end

            -- events
            if self.event_timeline:update(self.status:get_time_tp()) then
                self.event_timeline:clear()
            end
            if self.message_timeline:update(self.status:get_current_tp()) then
                self.message_timeline:clear()
            end

            -- increment
            if
                self.level_status.inc_enabled
                and self.status:get_increment_time_seconds() >= self.level_status.inc_time
            then
                self.level_status.current_increments = self.level_status.current_increments + 1
                self:increment_difficulty()
                self.status:reset_increment_time()
                self.must_change_sides = true
            end

            if self.must_change_sides and self.walls:empty() then
                local side_number = math.random(self.level_status.sides_min, self.level_status.sides_max)
                self.level_status.speed_mult = self.level_status.speed_mult + self.level_status.speed_inc
                self.level_status.delay_mult = self.level_status.delay_mult + self.level_status.delay_inc
                if self.level_status.rnd_side_changes_enabled then
                    self:set_sides(side_number)
                end
                self.must_change_sides = false
                love.audio.play(self.level_status.level_up_sound)
                if self.lua_runtime.env.onIncrement ~= nil then
                    self.lua_runtime.env.onIncrement()
                end
            end

            if not self.status:is_time_paused() then
                if self.lua_runtime.env.onUpdate ~= nil then
                    self.lua_runtime.env.onUpdate(frametime)
                end
                if self.main_timeline:update(self.status:get_time_tp()) and not self.must_change_sides then
                    self.main_timeline:clear()
                    if self.lua_runtime.env.onStep ~= nil then
                        self.lua_runtime.env.onStep()
                    end
                end
            end
            -- TODO: update custom timelines
            -- TODO: update beatpulse
            -- TODO: update pulse

            -- TODO: only if not black and white
            self.style:update(frametime, math.pow(self.difficulty_mult, 0.8))

            self.player:update_position(self.status.radius)
            self.walls:update(frametime, self.status.radius)
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
            next_rotation = next_rotation
                + math.abs((get_smoother_step(0, self.level_status.fast_spin, self.status.fast_spin) / 3.5) * 17)
                    * get_sign(next_rotation)
            self.status.fast_spin = self.status.fast_spin - frametime
        end
        self.current_rotation = self.current_rotation + next_rotation * frametime
        -- TODO: update camera shake (the one for death, totally independant from the level_status one)

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

function game:draw(screen)
    -- for lua access
    self.width, self.height = screen:getDimensions()

    -- do the resize adjustment the old game did after already enforcing our aspect ratio
    local zoom_factor = 1 / math.max(1024 / self.width, 768 / self.height)
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
    self.style:draw_background({ 0, 0 }, self.level_status.sides, true, false)
    -- TODO: draw 3d if enabled in config

    self.walls:draw(self.style)

    -- TODO: get tilt intensity and swap blink effect from config
    self.player:draw(self.level_status.sides, self.style, 1, true)

    -- TODO: draw particles, text, flash

    if self.message_text ~= "" then
        -- text shouldn't be affected by rotation/pulse
        love.graphics.origin()
        love.graphics.scale(zoom_factor, zoom_factor)
        -- text
        -- TODO: offset_color = self.style:get_color(0)  -- black in bw mode
        -- TODO: draw outlines (if not disabled in config)
        -- TODO: bw: text color = white apart from alpha which is gotten from style
        set_color(self.style:get_text_color())
        -- have to split into lines as love doesn't align text the same way as sfml otherwise
        -- TODO: config text scale (maybe we won't have that settings since we'll have ui scale?)
        love.graphics.print(
            self.message_text,
            game.message_font,
            self.width / zoom_factor / 2 - game.message_font:getWidth(self.message_text) / 2,
            self.height / zoom_factor / 5.5
        )
    end
end

return game
