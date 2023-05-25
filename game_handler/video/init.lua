local ffi = require("ffi")

ffi.cdef([[
int start(const char *filename, const int width, const int height, const int framerate);
void supply_video(const void *videoData);
void supply_audio(void *audioData, const int bytes);
int get_audio_buffer_size();
void cleanup();
]])
local test = ffi.load("encode")
local api = {}

function api.start(filename, width, height, framerate)
    if test.start(filename, width, height, framerate) ~= 0 then
        error("Failed to initialize ffmpeg.")
    end
end

function api.supply_video(imagedata)
    test.supply_video(imagedata:getFFIPointer())
end

function api.get_audio_buffer_size()
    return test.get_audio_buffer_size()
end

function api.supply_audio(sound_data)
    test.supply_audio(sound_data:getFFIPointer(), sound_data:getSize())
end

function api.cleanup()
    test.cleanup()
end

return api
