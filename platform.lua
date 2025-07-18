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

-- PUC lua 5.1 does not return nparams or isvararg from debug.getinfo
-- instead the data is encoded in string.dump(function).
if debug.getinfo(function(a, b)end).nparams ~= 2 then
    local old_getinfo = debug.getinfo
    debug.getinfo = function (f, what)
        local res = old_getinfo(f, what)
        local s = string.dump(f)
        assert(s:sub(1, 6) == "\27LuaQ\0", "This code works only in Lua 5.1")
        local int_size = s:byte(8)
        local ptr_size = s:byte(9)
        local pos = 14 + ptr_size + (s:byte(7) > 0 and s:byte(13) or s:byte(12 + ptr_size)) + 2 * int_size
        res.nparams = s:byte(pos)
        res.isvararg = s:byte(pos + 1) > 0
        return res
    end
end
