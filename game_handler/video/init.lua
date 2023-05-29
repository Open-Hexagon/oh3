local ffi = require("ffi")

ffi.cdef([[
int start(const char *filename, const int width, const int height, const int framerate);
int supply_video(const void *videoData);
int supply_audio(void *audioData, const int bytes);
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
    if test.supply_video(imagedata:getFFIPointer()) ~= 0 then
        error("Failed sending video frame.")
    end
    -- prevent memory leak
    imagedata:release()
end

function api.get_audio_buffer_size()
    return test.get_audio_buffer_size()
end

function api.supply_audio(sound_data)
    if test.supply_audio(sound_data:getFFIPointer(), sound_data:getSize()) ~= 0 then
        error("Failed sending audio frame.")
    end
end

function api.cleanup()
    test.cleanup()
end

return api
