-- TODO: make configurable
-- (will have to restart when changing, might be different once the asset rework is done)
if true then
    return require("audio.immediate")
else
    return require("audio.queue")
end
