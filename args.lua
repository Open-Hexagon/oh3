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
for i = 1, #args do
    if args[i] == "--headless" then
        ret.headless = true
    elseif args[i] == "--server" then
        ret.server = true
        ret.headless = true
    else
        ret.no_option = args[i]
    end
end
return ret
