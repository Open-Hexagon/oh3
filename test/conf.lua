function love.conf(t)
    t.identity = "ohtest"
    t.window = nil
    -- only enable required modules for testing
    t.modules.data = true
    t.modules.event = false
    t.modules.audio = false
    t.modules.font = false
    t.modules.graphics = false
    t.modules.image = false
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = false
    t.modules.mouse = false
    t.modules.physics = false
    t.modules.sound = false
    t.modules.system = false
    t.modules.thread = false
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = false
end
