return function(source)
    if source ~= nil then
        source:seek(0)
        source:play()
    end
end
