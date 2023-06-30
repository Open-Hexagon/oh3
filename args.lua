if arg == nil then
    -- called from thread (running in server)
    return {
        server = true,
        headless = true,
    }
end
local args = love.arg.parseGameArguments(arg)
local ret = {}
-- tests are always run in headless mode
ret.headless = love.filesystem.getIdentity() == "ohtest"
ret.server = false
ret.migrate = false
ret.render = false
ret.web = false
for i = 1, #args do
    if args[i] == "--headless" then
        ret.headless = true
    elseif args[i] == "--server" then
        ret.server = true
        ret.headless = true
    elseif args[i] == "--migrate" then
        ret.headless = true
        ret.migrate = true
    elseif args[i] == "--render" then
        ret.render = true
        ret.headless = false
    elseif args[i] == "--web" then
        ret.web = true
    else
        ret.no_option = args[i]
    end
end
return ret
