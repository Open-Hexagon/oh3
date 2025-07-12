if arg == nil then
    -- called from thread (running in server)
    return {
        server = true,
        headless = true,
    }
end
local argparse = require("extlibs.argparse")

local parser = argparse("oh-ce", "Open Hexagon Community Edition")

parser:argument("replay_file", "Path to replay file."):args("?")
parser:flag("--headless", "Run the game in headless mode.")
parser:flag("--server", "Start the game server.")
parser:option("--migrate", "Steam version server database to migrate to new format.")
parser:flag("--render", "Render a video of the given replay. Also enables server side replay rendering for #1 scores.")
parser:flag("--web", "Enables the web api.")

return parser:parse(love.arg.parseGameArguments(arg))
