-- 2.1.X compatibility mode
local Timeline = require("compat.game21.timeline")
local Quads = require("compat.game21.dynamic_quads")
local Tris = require("compat.game21.dynamic_tris")
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
    custom_timelines = require("compat.game21.custom_timelines"),
    first_play = true,
    walls = require("compat.game21.walls"),
    custom_walls = require("compat.game21.custom_walls"),
    flash_color = { 0, 0, 0, 0 },
    wall_quads = Quads:new(),
    pivot_quads = Quads:new(),
    player_tris = Tris:new(),
    cap_tris = Tris:new(),
    layer_offsets = {},
    pivot_layer_colors = {},
    wall_layer_colors = {},
    player_layer_colors = {},
    layer_shader = love.graphics.newShader(
        [[
        attribute vec2 instance_position;
        attribute vec4 instance_color;
        varying vec4 instance_color_out;

        vec4 position(mat4 transform_projection, vec4 vertex_position)
        {
            instance_color_out = instance_color / 255.0;
            vertex_position.xy += instance_position;
            return transform_projection * vertex_position;
        }
    ]],
        [[
        varying vec4 instance_color_out;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            return instance_color_out;
        }
    ]]
    ),

    -- TODO: check if the inital values cause issues (may need the values from the canvas instead here)
    width = love.graphics.getWidth(),
    height = love.graphics.getHeight(),
}

game.message_font = game.assets.get_font("OpenSquare-Regular.ttf", 32)
game.go_sound = game.assets.get_sound("go.ogg")
game.swap_blip_sound = game.assets.get_sound("swap_blip.ogg")
game.level_up_sound = game.assets.get_sound("level_up.ogg")
game.restart_sound = game.assets.get_sound("restart.ogg")
game.select_sound = game.assets.get_sound("select.ogg")

function game:start(pack_folder, level_id, difficulty_mult)
    -- TODO: put this somewhere else so it can be loaded for the menu
    --       or maybe not because it caches loaded packs anyway?
    self.pack_data = self.assets.get_pack(pack_folder)
    self.level_data = self.pack_data.levels[level_id]
    self.level_status:reset(true, self.assets) -- TODO: get bool from config
    self.style:select(self.pack_data.styles[self.level_data.styleId])
    self.style:compute_colors()
    self.difficulty_mult = difficulty_mult
    self.status:reset_all_data()
    self.music = self.pack_data.music[self.level_data.musicId]
    if self.music == nil then
        error("Music with id '" .. self.level_data.musicId .. "' doesn't exist!")
    end
    self:refresh_music_pitch()
    local segment
    if self.first_play then
        segment = self.music.segments[1]
    else
        segment = self.music.segments[math.random(1, #self.music.segments)]
    end
    self.status.beat_pulse_delay = self.status.beat_pulse_delay + (segment.beat_pulse_delay_offset or 0)
    self.music.source:seek(segment.time)
    love.audio.play(self.music.source)

    -- initialize random seed
    -- TODO: replays (need to read random seed from there)
    self.seed = math.floor(love.timer.getTime() * 1000)
    math.randomseed(self.seed)
    math.random()

    self.event_timeline:clear()
    self.message_timeline:clear()
    self.custom_timelines:reset()
    self.walls:reset(self.level_status)
    self.custom_walls.cw_clear()

    -- TODO: get player size, speed and focus speed from config
    self.player:reset(self:get_swap_cooldown(), 7.3, 9.45, 4.625)

    self.flash_color = { 255, 255, 255, 0 }

    self.current_rotation = 0
    self.must_change_sides = false
    if not self.first_play and self.lua_runtime.env.onPreUnload ~= nil then
        self.lua_runtime.onPreUnload()
    end
    self.lua_runtime:init_env(self, self.pack_data)
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

function game:get_music_dm_sync_factor()
    return math.pow(self.difficulty_mult, 0.12)
end

function game:refresh_music_pitch()
    -- TODO: account for config music speed mult
    self.music.source:setPitch(
        self.level_status.music_pitch * (self.level_status.sync_music_to_dm and self:get_music_dm_sync_factor() or 1)
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
    self.flash_color[4] = self.status.flash_effect

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
            self.custom_timelines.update(self.status:get_current_tp())

            -- TODO: only if beatpulse not disabled in config
            if not self.level_status.manual_beat_pulse_control then
                if self.status.beat_pulse_delay <= 0 then
                    self.status.beat_pulse = self.level_status.beat_pulse_max
                    self.status.beat_pulse_delay = self.level_status.beat_pulse_delay_max
                else
                    self.status.beat_pulse_delay = self.status.beat_pulse_delay
                        - frametime * self:get_music_dm_sync_factor()
                end
                if self.status.beat_pulse > 0 then
                    self.status.beat_pulse = self.status.beat_pulse
                        - 2 * frametime * self:get_music_dm_sync_factor() * self.level_status.beat_pulse_speed_mult
                end
            end
            -- TODO: 75 instead of radius min if beatpulse disabled in config
            self.status.radius = self.level_status.radius_min * (self.status.pulse / self.level_status.pulse_min)
                + self.status.beat_pulse

            if not self.level_status.manual_pulse_control then
                if self.status.pulse_delay <= 0 then
                    local pulse_add = self.status.pulse_direction > 0 and self.level_status.pulse_speed
                        or -self.level_status.pulse_speed_r
                    local pulse_limit = self.status.pulse_direction > 0 and self.level_status.pulse_max
                        or self.level_status.pulse_min
                    self.status.pulse = self.status.pulse + pulse_add * frametime * self:get_music_dm_sync_factor()
                    if
                        (self.status.pulse_direction > 0 and self.status.pulse >= pulse_limit)
                        or (self.status.pulse_direction < 0 and self.status.pulse <= pulse_limit)
                    then
                        self.status.pulse = pulse_limit
                        self.status.pulse_direction = -self.status.pulse_direction
                        if self.status.pulse_direction < 0 then
                            self.status.pulse_delay = self.level_status.pulse_delay_max
                        end
                    end
                end
                self.status.pulse_delay = self.status.pulse_delay - frametime * self:get_music_dm_sync_factor()
            end

            -- TODO: only if not black and white
            self.style:update(frametime, math.pow(self.difficulty_mult, 0.8))

            self.player:update_position(self.status.radius)
            self.walls:update(frametime, self.status.radius)
            -- TODO: update custom walls
        else
            self.level_status.rotation_speed = self.level_status.rotation_speed * 0.99
        end

        self.status.pulse3D = self.status.pulse3D
            + self.style._3D_pulse_speed * self.status.pulse3D_direction * frametime
        if self.status.pulse3D > self.style._3D_pulse_max then
            self.status.pulse3D_direction = -1
        elseif self.status.pulse3D < self.style._3D_pulse_min then
            self.status.pulse3D_direction = 1
        end
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
    -- apply pulse as well
    local p = self.status.pulse / self.level_status.pulse_min
    love.graphics.scale(zoom_factor / p, zoom_factor / p)

    if not self.status.has_died then
        if self.level_status.camera_shake > 0 then
            love.graphics.translate(
                -- use love.math.random instead of math.random to not break replay rng
                (love.math.random() * 2 - 1) * self.level_status.camera_shake,
                (love.math.random() * 2 - 1) * self.level_status.camera_shake
            )
        end
    end
    -- TODO: only if 3d enabled in config
    local depth = self.style._3D_depth
    local pulse_3d = self.status.pulse3D -- TODO: config can disable pulse
    local effect = self.style._3D_skew * pulse_3d -- TODO: config 3d mult
    local rad_rot = math.rad(self.current_rotation + 90)
    local sin_rot = math.sin(rad_rot)
    local cos_rot = math.cos(rad_rot)
    love.graphics.scale(1, 1 / (1 + effect))

    -- apply rotation
    love.graphics.rotate(-math.rad(self.current_rotation))

    -- TODO: apply right shaders when rendering
    -- TODO: only draw background if not disabled in config
    self.style:draw_background(self.level_status.sides, self.level_status.darken_uneven_background_chunk, false)

    self.wall_quads:clear()
    self.walls:draw(self.style, self.wall_quads)
    self.custom_walls.draw(self.wall_quads)

    -- TODO: get tilt intensity and swap blink effect from config
    self.player_tris:clear()
    self.pivot_quads:clear()
    self.cap_tris:clear()
    if self.status.started then
        self.player:draw(
            self.level_status.sides,
            self.style,
            self.pivot_quads,
            self.player_tris,
            self.cap_tris,
            1,
            true
        )
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- TODO: only if 3d enabled in config
    local function adjust_alpha(a, i)
        if self.style._3D_alpha_mult == 0 then
            return a
        end
        local new_alpha = (a / self.style._3D_alpha_mult) - i * self.style._3D_alpha_falloff
        if new_alpha > 255 then
            return 255
        elseif new_alpha < 0 then
            return 0
        end
        return new_alpha
    end
    for j = 1, depth do
        local i = depth - j
        local offset = self.style._3D_spacing * (i + 1) * self.style._3D_perspective_mult * effect * 3.6 * 1.4
        self.layer_offsets[j] = self.layer_offsets[j] or {}
        self.layer_offsets[j][1] = offset * cos_rot
        self.layer_offsets[j][2] = offset * sin_rot
        local r, g, b, a = self.style:get_3D_override_color()
        -- TODO: set to 255 / 1.4 if bw mode (alpha stays)
        r = r / self.style._3D_darken_mult
        g = g / self.style._3D_darken_mult
        b = b / self.style._3D_darken_mult
        a = adjust_alpha(a, i)
        self.pivot_layer_colors[j] = self.pivot_layer_colors[j] or {}
        self.pivot_layer_colors[j][1] = r
        self.pivot_layer_colors[j][2] = g
        self.pivot_layer_colors[j][3] = b
        self.pivot_layer_colors[j][4] = a
        if self.style._3D_override_is_main then
            r, g, b, a = self.style:get_wall_color()
            r = r / self.style._3D_darken_mult
            g = g / self.style._3D_darken_mult
            b = b / self.style._3D_darken_mult
            a = adjust_alpha(a, i)
        end
        self.wall_layer_colors[j] = self.wall_layer_colors[j] or {}
        self.wall_layer_colors[j][1] = r
        self.wall_layer_colors[j][2] = g
        self.wall_layer_colors[j][3] = b
        self.wall_layer_colors[j][4] = a
        if self.style._3D_override_is_main then
            r, g, b, a = self.style:get_player_color()
            r = r / self.style._3D_darken_mult
            g = g / self.style._3D_darken_mult
            b = b / self.style._3D_darken_mult
            a = adjust_alpha(a, i)
        end
        self.player_layer_colors[j] = self.player_layer_colors[j] or {}
        self.player_layer_colors[j][1] = r
        self.player_layer_colors[j][2] = g
        self.player_layer_colors[j][3] = b
        self.player_layer_colors[j][4] = a
    end
    if depth > 0 then
        self.wall_quads:set_instance_attribute_array("instance_position", "float", 2, self.layer_offsets)
        self.wall_quads:set_instance_attribute_array("instance_color", "float", 4, self.wall_layer_colors)
        self.pivot_quads:set_instance_attribute_array("instance_position", "float", 2, self.layer_offsets)
        self.pivot_quads:set_instance_attribute_array("instance_color", "float", 4, self.pivot_layer_colors)
        self.player_tris:set_instance_attribute_array("instance_position", "float", 2, self.layer_offsets)
        self.player_tris:set_instance_attribute_array("instance_color", "float", 4, self.player_layer_colors)

        love.graphics.setShader(self.layer_shader)
        self.wall_quads:draw_instanced(depth)
        self.pivot_quads:draw_instanced(depth)
        self.player_tris:draw_instanced(depth)
        love.graphics.setShader()
    end

    self.wall_quads:draw()
    self.cap_tris:draw()
    self.pivot_quads:draw()
    self.player_tris:draw()

    -- TODO: draw particles, text, flash

    -- text and flash shouldn't be affected by rotation/pulse
    love.graphics.origin()
    love.graphics.scale(zoom_factor, zoom_factor)
    if self.message_text ~= "" then
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

    -- TODO: draw flash if not disabled in config
    if self.flash_color[4] ~= 0 then
        set_color(unpack(self.flash_color))
        love.graphics.rectangle("fill", 0, 0, self.width / zoom_factor, self.height / zoom_factor)
    end
end

return game
