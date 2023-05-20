return function(modname)
    return function(...)
        -- don't print stuff when testing
        if love.filesystem.getIdentity() ~= "ohtest" then
            print("[" .. modname .. "]", ...)
        end
    end
end
