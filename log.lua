local function get_log(modname)
    return function(...)
        print("[" .. modname .. "]", ...)
    end
end

return get_log
