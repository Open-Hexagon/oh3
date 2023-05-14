return function(source)
    if source ~= nil then
        source:seek(0)
        love.audio.play(source)
    end
end
