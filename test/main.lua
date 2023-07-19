local search_names = {
    "liblove-11.4.so",
    "liblove.so",
    "liblove-11.4.dll",
    "liblove.dll",
}
local found = false
for i = 1, #search_names do
    package.preload.love = package.loadlib(search_names[i], "luaopen_love")
    if package.preload.love ~= nil then
        found = true
        break
    end
end
assert(found, "could not find liblove")
require("love")
require("love.filesystem")
love.filesystem.init("ohtest")
love.filesystem.setIdentity("ohtest")
love.filesystem.setCRequirePath(love.filesystem.getCRequirePath() .. ";lib/??")
require("love.arg")
require("love.timer")
require("love.keyboard")
local newarg = { "test", "--pattern", "lua", "--exclude-pattern", "main.lua" }
for i = 1, #arg do
    newarg[#newarg + 1] = arg[i]
end
arg = newarg
require("busted.runner")({ standalone = false })
