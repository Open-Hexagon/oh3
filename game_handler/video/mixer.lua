local ffi = require("ffi")
local mixer = {}
local mux
local chunk
local read_bytes = 0
local playing_decoders = {}
local chunk_size
local sample_count
local bytes_per_sample = 2
local current_index = 0
local free_indices = {}

function mixer.set_muxer(muxer)
    mux = muxer
    chunk_size = mux.get_audio_buffer_size()
    sample_count = chunk_size / bytes_per_sample
    chunk = love.data.newByteData(chunk_size)
end

function mixer.load_file(file)
    local decoder = love.sound.newDecoder(file, mux.get_audio_buffer_size())
    if decoder:getBitDepth() ~= 16 then
        error("only 16 bit samples are supported")
    end
    if decoder:getSampleRate() ~= 44100 then
        error("only sample rates of 44100 are supported")
    end
    return decoder
end

function mixer.play(decoder)
    local index
    if #free_indices == 0 then
        current_index = current_index + 1
        index = current_index
    else
        index = free_indices[1]
        table.remove(free_indices, 1)
    end
    playing_decoders[index] = decoder
    return index
end

function mixer.stop_all()
    playing_decoders = {}
end

function mixer.stop(decoder_index)
    playing_decoders[decoder_index] = nil
    free_indices[#free_indices+1] = decoder_index
end

function mixer.is_playing(decoder_index, decoder)
    return playing_decoders[decoder_index] == decoder
end

local function clamp_signal(n)
    if n > 32767 then
        return 32767
    elseif n < -32767 then
        return -32767
    else
        return n
    end
end

function mixer.update(seconds)
    local to_read = seconds * 44100 * 2 * bytes_per_sample
    local target = ffi.cast("int16_t*", chunk:getFFIPointer())
    while to_read > read_bytes do
        for i = 0, sample_count - 1 do
            target[i] = 0
        end
        for i = 1, current_index do
            local decoder = playing_decoders[i]
            if decoder ~= nil then
                local to_mix_chunk = playing_decoders[i]:decode()
                if to_mix_chunk == nil then
                    mixer.stop(i)
                else
                    local to_mix = ffi.cast("int16_t*", to_mix_chunk:getFFIPointer())
                    if playing_decoders[i]:getChannelCount() == 1 then
                        for j = 0, to_mix_chunk:getSize() / bytes_per_sample * 2 - 1, 2 do
                            target[j] = clamp_signal(target[j] + clamp_signal(to_mix[j]))
                        end
                    else
                        for j = 0, to_mix_chunk:getSize() / bytes_per_sample - 1 do
                            target[j] = clamp_signal(target[j] + clamp_signal(to_mix[j]))
                        end
                    end
                end
            end
        end
        mux.supply_audio(chunk)
        read_bytes = read_bytes + chunk_size
    end
end

return mixer
