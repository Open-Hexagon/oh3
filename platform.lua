-- platform specific adjustments
local ffi = require("ffi")

-- cffi-lua has its own ffi.tonumber
-- luajit's ffi combines both in the default tonumber
ffi.tonumber = ffi.tonumber or tonumber

-- PUC lua 5.1 does not allow extra arguments in xpcall, 5.2+ and luajit do
local xpcall_takes_arguments
xpcall(function(a)
    xpcall_takes_arguments = a == "test"
end, error, "test")
if not xpcall_takes_arguments then
    local old_xpcall = xpcall
    xpcall = function(fun, errfun, ...)
        local varargs = { ... }
        return old_xpcall(function() return fun(unpack(varargs)) end, errfun)
    end
end
