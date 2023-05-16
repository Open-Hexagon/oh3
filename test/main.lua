local test_module = arg[2]
if test_module == nil then
    error("You need to specify a module for testing!")
end

-- workaround for running busted with love
table.remove(arg, 1)
table.remove(arg, 1)

-- workaroud in order to be able to require modules in normally
love.filesystem.setRequirePath("..")
local real = require
function require(modname)
    -- the compat.game... modules that use init.lua don't work for some reason
    if modname:sub(1, #"compat.game") == "compat.game" and #modname <= #"compat.game192" then
        modname = modname .. ".init"
    end
    return real(modname)
end

require("test." .. test_module)
