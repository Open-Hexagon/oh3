local log = require("log")("ui.overlay.packs.download_thread")
local http = require("socket.http")
local url = require("socket.url")
local zip = require("extlibs.zip")

local server_url = ""

local pack_sizes = {}
local download = {}

function download.set_server_url(serv_url)
    server_url = serv_url
end

---gets a list of pack names for the specified game version
---@param version number
---@return table
function download.get_pack_list(version)
    local html = http.request(server_url .. "packs" .. tostring(version))
    local packs = {}
    for pack in html:gmatch('\n<a href="(.-).zip"') do
        packs[#packs + 1] = url.unescape(pack)
    end
    local index = 1
    pack_sizes[version] = pack_sizes[version] or {}
    for size in html:gmatch('<a href=".-.zip".-..\\-...\\-.... ..:.. (.-)\n') do
        pack_sizes[version][packs[index]] = tonumber(size)
        index = index + 1
    end
    return packs
end

---downloads and extracts a pack in the right location
---@param version number
---@param pack_name string
function download.get(version, pack_name)
    local file = love.filesystem.newFile("tmp.zip")
    local download_size = 0
    file:open("w")
    log("Downloading", pack_name)
    http.request({
        url = server_url .. "packs" .. version .. "/" .. pack_name .. ".zip",
        sink = function(chunk, err)
            if err then
                log(err)
            elseif chunk then
                file:write(chunk)
                download_size = download_size + #chunk
                log("Downloading", pack_name, "progress:", download_size, "of:", pack_sizes[version][pack_name])
                love.thread.getChannel("pack_download_progress"):push(download_size / pack_sizes[version][pack_name])
                return 1
            end
        end,
    })
    file:close()
    log("Extracting", "tmp.zip")
    local zip_file = zip:new("tmp.zip")
    zip_file:unzip("packs" .. version)
    zip_file:close()
    love.filesystem.remove("tmp.zip")
    log("Done")
end

return download
