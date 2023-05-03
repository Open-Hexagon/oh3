function love.conf(t)
    t.window.title = "Open Hexagon"
    t.window.icon = "assets/image/icon.png"
    t.window.width = 960
    t.window.height = 540
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 360

    -- TODO: make configurable
    t.window.vsync = 0

    t.console = true -- windows only
end
