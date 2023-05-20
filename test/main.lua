local test_module = arg[2]
if test_module == nil then
    error("You need to specify a module for testing!")
end

-- workaround for running busted with love
arg = {}

-- workaroud in order to be able to require modules in normally
local real = require
function require(modname)
    local path = modname:gsub("%.", "/") .. ".lua"
    local file = loadfile(path)
    if file == nil then
        path = modname:gsub("%.", "/") .. "/init.lua"
        file = loadfile(path)
    end
    if file == nil then
        return real(modname)
    end
    return file(modname)
end

require("test." .. test_module)
