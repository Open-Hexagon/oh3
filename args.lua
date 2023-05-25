local args = love.arg.parseGameArguments(arg)
local ret = {}
-- tests are always run in headless mode
ret.headless = love.filesystem.getIdentity() == "ohtest"
ret.render = false
for i = 1, #args do
    if args[i] == "--headless" then
        ret.headless = true
    elseif args[i] == "--render" then
        ret.render = true
        ret.headless = false
    else
        ret.no_option = args[i]
    end
end
return ret
