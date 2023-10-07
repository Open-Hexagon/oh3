local args = require("args")

function love.conf(t)
    t.version = "11.4"
    if not args.headless then
        t.window.title = "Open Hexagon"
        t.window.icon = "assets/image/icon.png"
        t.window.width = 960
        t.window.height = 540
        t.window.resizable = true
        t.window.minwidth = 640
        t.window.minheight = 360
        t.window.usedpiscale = false

        -- TODO: make configurable
        t.window.vsync = 0
        t.window.msaa = 4

        t.console = true -- windows only

        -- don't enable the audio module when rendering
        t.modules.audio = not args.render
    else
        t.modules.data = true
        t.modules.event = false
        t.modules.audio = false
        t.modules.font = false
        t.modules.graphics = false
        t.modules.image = false
        t.modules.joystick = false
        t.modules.keyboard = false
        t.modules.math = true
        t.modules.mouse = false
        t.modules.physics = false
        t.modules.sound = false
        t.modules.system = true
        t.modules.thread = true
        t.modules.timer = true
        t.modules.touch = false
        t.modules.video = false
        t.modules.window = false
    end
    -- allows people to access game directories on android
    t.externalstorage = true
end
