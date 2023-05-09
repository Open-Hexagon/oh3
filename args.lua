local args = love.arg.parseGameArguments(arg)
local ret = {}
ret.headless = false
for i = 1, #args do
    if args[i] == "--headless" then
        ret.headless = true
    else
        ret.no_option = args[i]
    end
end
return ret
