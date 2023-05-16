local args = love.arg.parseGameArguments(arg)
local ret = {}
-- tests are always run in headless mode
ret.headless = love.filesystem.getIdentity() == "ohtest"
for i = 1, #args do
    if args[i] == "--headless" then
        ret.headless = true
    else
        ret.no_option = args[i]
    end
end
return ret
