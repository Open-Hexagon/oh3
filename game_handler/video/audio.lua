local audio = {
    sample_rate = 48000,
}
audio.__index = audio

-- target audio buffer properties
local BYTES_PER_SAMPLE = 2
local BITS_PER_SAMPLE = BYTES_PER_SAMPLE * 8
local SAMPLE_RATE = audio.sample_rate

local samples_to_read = 0
local encoder
local target_data
local loaded_audio = {}

local function resample(data, pitch, duration)
    pitch = pitch or 1
    local new_data = love.sound.newSoundData(
        math.floor((duration or data:getDuration()) * SAMPLE_RATE / pitch),
        SAMPLE_RATE,
        BITS_PER_SAMPLE,
        data:getChannelCount()
    )
    local to_old_mult = data:getSampleRate() * pitch / SAMPLE_RATE
    for channel = 1, data:getChannelCount() do
        for new_pos = 0, new_data:getSampleCount() - 1 do
            local old_pos = new_pos * to_old_mult
            local last_pos = math.floor(old_pos)
            local last_sample = data:getSample(last_pos, channel)
            local next_pos = math.ceil(old_pos)
            if next_pos >= data:getSampleCount() then
                if new_pos ~= new_data:getSampleCount() - 1 then
                    error("out of range sample not on last sample")
                end
                break
            end
            local next_sample = data:getSample(next_pos, channel)
            local fract = old_pos - last_pos
            -- interpolate between last_sample and next_sample with fract
            -- linear (sounds bad): value = last_sample * (1 - fract) + next_sample * fract
            local value = (2 * fract ^ 3 - 3 * fract ^ 2 + 1) * last_sample
                + (-2 * fract ^ 3 + 3 * fract ^ 2) * next_sample
            new_data:setSample(new_pos, channel, value)
        end
    end
    return new_data
end

function audio.set_encoder(video_encoder)
    encoder = video_encoder
    target_data = love.sound.newSoundData(encoder.audio_frame_size, SAMPLE_RATE, BITS_PER_SAMPLE, 2)
end

function audio.new_static(file)
    local data = love.sound.newSoundData(file)
    local resampled_data = data
    if data:getSampleRate() ~= SAMPLE_RATE then
        resampled_data = resample(data, 1)
    end
    local obj = setmetatable({
        original_data = data,
        data = resampled_data,
        love_obj = data,
        sample_rate = data:getSampleRate(),
        position = 0,
        last_position = 0,
        pitch = 1,
        looping = false,
        playing = false,
        volume = 1,
        file = file,
    }, audio)
    loaded_audio[#loaded_audio + 1] = obj
    return obj
end

function audio.new_stream(file)
    local decoder = love.sound.newDecoder(file)
    local obj = setmetatable({
        decoder = decoder,
        data = nil,
        love_obj = decoder,
        sample_rate = decoder:getSampleRate(),
        position = 0,
        last_position = 0,
        pitch = 1,
        looping = false,
        playing = false,
        volume = 1,
        file = file,
    }, audio)
    loaded_audio[#loaded_audio + 1] = obj
    return obj
end

function audio:seek(offset)
    self.position = math.floor(offset * self.sample_rate / self.pitch)
    self.last_position = self.position
    if self.decoder then
        self.decoder:seek(offset)
        self.data = nil
    end
end

function audio:set_pitch(pitch)
    self.pitch = pitch
    self.sample_rate = math.floor(self.love_obj:getSampleRate() * self.pitch)
    if self.original_data then
        if self.original_data:getSampleRate() == self.sample_rate then
            self.data = self.original_data
        elseif self.data:getSampleRate() ~= self.sample_rate then
            self.data = resample(self.original_data, self.pitch, self.original_data:getDuration())
        end
    end
end

function audio:play()
    self.playing = true
end

function audio:stop()
    self.playing = false
end

local function clamp_signal(value)
    if value > 1 then
        return 1
    elseif value < -1 then
        return -1
    else
        return value
    end
end

function audio.update(delta)
    samples_to_read = samples_to_read + delta * SAMPLE_RATE
    while samples_to_read >= encoder.audio_frame_size do
        for buffer_pos = 0, encoder.audio_frame_size - 1 do
            target_data:setSample(buffer_pos, 1, 0)
            target_data:setSample(buffer_pos, 2, 0)
        end
        for i = 1, #loaded_audio do
            local obj = loaded_audio[i]
            if obj.playing then
                for buffer_pos = 0, encoder.audio_frame_size - 1 do
                    if obj.data == nil then
                        obj.data = obj.decoder:decode()
                        if obj.data:getSampleRate() ~= SAMPLE_RATE or obj.sample_rate ~= obj.data:getSampleRate() then
                            obj.data = resample(obj.data, obj.pitch)
                        end
                    end
                    local sample_count = obj.data:getSampleCount()
                    if obj.position % sample_count == 0 and obj.last_position ~= 0 then
                        if obj.decoder then
                            obj.data = obj.decoder:decode()
                            if obj.data == nil then
                                obj.playing = false
                                obj:seek(0)
                                break
                            end
                            if
                                obj.data:getSampleRate() ~= SAMPLE_RATE
                                or obj.sample_rate ~= obj.data:getSampleRate()
                            then
                                obj.data = resample(obj.data, obj.pitch)
                            end
                            sample_count = obj.data:getSampleCount()
                        else
                            obj.playing = false
                            obj:seek(0)
                            break
                        end
                    end
                    local v1, v2 = target_data:getSample(buffer_pos, 1), target_data:getSample(buffer_pos, 2)
                    if obj.data:getChannelCount() == 2 then
                        -- stereo
                        v1 = clamp_signal(v1 + obj.volume * obj.data:getSample(obj.position % sample_count, 1))
                        v2 = clamp_signal(v2 + obj.volume * obj.data:getSample(obj.position % sample_count, 2))
                    else
                        -- mono
                        v1 = clamp_signal(v1 + obj.volume * obj.data:getSample(obj.position % sample_count))
                        v2 = v1
                    end
                    target_data:setSample(buffer_pos, 1, v1)
                    target_data:setSample(buffer_pos, 2, v2)
                    obj.last_position = obj.position % sample_count
                    obj.position = obj.position + 1
                end
            end
        end
        samples_to_read = samples_to_read - encoder.audio_frame_size
        encoder.supply_audio_data(target_data)
    end
end

return audio
