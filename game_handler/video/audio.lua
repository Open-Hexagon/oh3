local audio = {}
audio.__index = audio
local mux, target_chunk, target_sample_size
-- target audio buffer properties
local sample_rate = 44100
local bytes_per_sample = 2
local bits_per_sample = bytes_per_sample * 8
local samples_played = 0
local playing_audio = {}

function audio.set_muxer(muxer)
    mux = muxer
    local size = mux.get_audio_buffer_size()
    target_chunk = love.sound.newSoundData(size / bytes_per_sample, sample_rate, bits_per_sample, 2)
    target_sample_size = size / bytes_per_sample / 2
end

local function resample(data, pitch, duration)
    pitch = pitch or 1
    local new_data = love.sound.newSoundData((duration or data:getDuration()) * sample_rate, sample_rate, bits_per_sample, data:getChannelCount())
    local to_old_mult = data:getSampleRate() * pitch / sample_rate
    for channel = 1, data:getChannelCount() do
        for new_pos = 0, new_data:getSampleCount() - 1 do
            local old_pos = new_pos * to_old_mult
            local last_pos = math.floor(old_pos)
            local last_sample = data:getSample(last_pos, channel)
            local next_sample = data:getSample(math.ceil(old_pos), channel)
            local fract = old_pos - last_pos
            -- interpolate between last_sample and next_sample with fract
            -- linear (sounds bad): value = last_sample * (1 - fract) + next_sample * fract
            local value = (2 * fract ^ 3 - 3 * fract ^ 2 + 1) * last_sample + (-2 * fract ^ 3 + 3 * fract ^ 2) * next_sample
            new_data:setSample(new_pos, channel, value)
        end
    end
    return new_data
end

function audio.new_static(file)
    local data = love.sound.newSoundData(file)
    if data:getSampleRate() ~= sample_rate or data:getBitDepth() ~= bits_per_sample then
        data = resample(data)
    end
    return setmetatable({
        data = data,
        position = 0, -- in samples
        bit_depth = data:getBitDepth(),
        byte_depth = data:getBitDepth() / 8,
        channels = data:getChannelCount(),
        duration = data:getDuration(),
        sample_rate = data:getSampleRate(),
        pitch = 1,
        looping = false,
        playing = false,
        file = file,
    }, audio)
end

function audio.new_stream(file)
    local buf_size = 2048
    local dec = love.sound.newDecoder(file, buf_size)
    return setmetatable({
        decoder = dec,
        read_time = buf_size * 8 / dec:getBitDepth() / dec:getChannelCount() / dec:getSampleRate(),
        resampled_read_samples = math.floor(buf_size * 8 * sample_rate / dec:getBitDepth() / dec:getSampleRate()),
        position = 0, -- in samples (channels are interleaved)
        current_buffer = nil,
        current_buffer_pos = 0,
        bit_depth = dec:getBitDepth(),
        byte_depth = dec:getBitDepth() / 8,
        channels = dec:getChannelCount(),
        duration = dec:getDuration(), -- may be -1 if undeterminable
        sample_rate = dec:getSampleRate(),
        pitch = 1,
        looping = false,
        playing = false,
        file = file,
    }, audio)
end

function audio:seek(offset)
    self.position = offset * sample_rate * self.channels
    if self.decoder then
        self.decoder:seek(offset)
        self.current_buffer_pos = offset * sample_rate * self.channels
        self.current_buffer_pos = self.current_buffer_pos - self.current_buffer_pos % math.floor(self.resampled_read_samples / self.pitch)
    end
end

function audio:set_pitch(pitch)
    self.pitch = pitch
    if self.data then
        self.data = resample(self.data, self.pitch)
    end
end

function audio:play()
    if not self.playing then
        playing_audio[#playing_audio + 1] = self
        self.playing = true
    end
end

function audio:stop()
    if self.playing then
        self.playing = false
        for i = #playing_audio, 1, -1 do
            if playing_audio[i] == self then
                table.remove(playing_audio, i)
            end
        end
    end
end

local function get_samples(self, amount)
    local target_pos = self.position + amount * self.channels
    return function()
        if self.position <= target_pos then
            local pos = self.position
            self.position = self.position + self.channels
            local data = self.data
            if self.decoder then
                -- dynamically decode sound (stream option)
                if pos >= self.current_buffer_pos then
                    while pos >= self.current_buffer_pos do
                        self.current_buffer = self.decoder:decode()
                        self.current_buffer_pos = self.current_buffer_pos + math.floor(self.resampled_read_samples / self.pitch)
                    end
                    if not self.current_buffer then
                        -- no data, done playing
                        self.playing = false
                        return
                    end
                    if self.current_buffer:getSampleRate() * self.pitch ~= sample_rate or self.current_buffer:getBitDepth() ~= bits_per_sample then
                        self.current_buffer = resample(self.current_buffer, self.pitch, self.read_time / self.pitch)
                    end
                end
                data = self.current_buffer
                pos = pos % (data:getSampleCount() * self.channels)
            end
            if self.data and pos >= self.data:getSampleCount() * self.data:getChannelCount() then
                -- no data (for static sounds), done playing
                self.playing = false
                return
            end
            if data then
                if self.channels == 1 then
                    local value = data:getSample(pos)
                    -- put mono sound on both channels
                    return value, value
                elseif self.channels == 2 then
                    return data:getSample(pos), data:getSample(pos + 1)
                else
                    error("Only mono and stereo sound is supported!")
                end
            end
        else
            return
        end
    end
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

function audio.update(seconds)
    local sample_amount_to_play = seconds * sample_rate
    while sample_amount_to_play > samples_played do
        for i = 0, target_chunk:getSampleCount() - 1 do
            target_chunk:setSample(i, 0)
        end
        for i = #playing_audio, 1, -1 do
            local audio_obj = playing_audio[i]
            local buf_pos = 0
            for left, right in get_samples(audio_obj, target_sample_size) do
                target_chunk:setSample(buf_pos, clamp_signal(target_chunk:getSample(buf_pos) + left))
                buf_pos = buf_pos + 1
                target_chunk:setSample(buf_pos, clamp_signal(target_chunk:getSample(buf_pos) + right))
                buf_pos = buf_pos + 1
            end
            if not audio_obj.playing then
                table.remove(playing_audio, i)
                if audio_obj.looping then
                    audio_obj:seek(0)
                    audio_obj:play()
                end
            end
        end
        samples_played = samples_played + target_sample_size
        mux.supply_audio(target_chunk)
    end
end

return audio
