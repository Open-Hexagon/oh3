local args = require("args")


-- TODO: make configurable
-- (will have to restart when changing, might be different once the asset rework is done)
if args.render then
    return require("audio.queue")
else
    return require("audio.immediate")
end
