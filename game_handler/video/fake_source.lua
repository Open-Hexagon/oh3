local fake_source = {}
fake_source.__index = fake_source
local all_sources = {}
local mixer

function fake_source.init(mix)
    mixer = mix
    love.audio = {
        newSource = function(filename)
            return fake_source.new(filename)
        end,
        play = function(...)
            local sources = { ... }
            for i = 1, #sources do
                sources[i]:play()
            end
        end,
        stop = function(...)
            local sources = { ... }
            if #sources == 0 then
                mixer.stop_all()
            else
                for i = 1, #sources do
                    if sources[i]:isPlaying() then
                        mixer.stop(sources[i].play_index)
                    end
                end
            end
        end,
    }
    love.sound = {
        newDecoder = love.sound.newDecoder,
    }
end

function fake_source.update(time)
    mixer.update(time)
    for i = 1, #all_sources do
        local source = all_sources[i]
        --[[if source.looping and not source:isPlaying() then
            source:play()
        end]]
    end
end

function fake_source.new(filename)
    local obj = setmetatable({
        pitch = 0,
        looping = false,
        play_index = nil,
        decoder = mixer.load_file(filename),
        filename = filename,
    }, fake_source)
    all_sources[#all_sources + 1] = obj
    return obj
end

function fake_source:seek(offset)
    self.decoder:seek(offset)
end

function fake_source:play()
    self.play_index = mixer.play(self.decoder)
end

function fake_source:isPlaying()
    return mixer.is_playing(self.play_index, self.decoder)
end

function fake_source:isLooping()
    return self.looping
end

function fake_source:setLooping(bool)
    self.looping = bool
end

function fake_source:setPitch(pitch)
    self.pitch = pitch
end

function fake_source:getPitch()
    return self.pitch
end

return fake_source
