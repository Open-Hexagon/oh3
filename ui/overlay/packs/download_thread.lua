local log = require("log")("ui.overlay.packs.download_thread")
local json = require("extlibs.json.json")
local http = require("socket.http")
local url = require("socket.url")
local zip = require("extlibs.zip")
local https = require("https")

local server_api_url = ""

local pack_data_list
local pack_sizes = {}
local download = {}

local function api(suffix)
    local code, json_data = https.request(server_api_url .. suffix)
    if code ~= 200 then
        log("'" .. suffix .. "' api request failed")
        return {}
    end
    if not json_data or (json_data:sub(1, 1) ~= "{" and json_data:sub(1, 1) ~= "[") then
        -- something went wrong
        return {}
    end
    return json.decode(json_data)
end

function download.set_server_url(serv_api_url)
    server_api_url = serv_api_url
end

---gets a list of pack names for the specified game version
---@param version number
---@return table
function download.get_pack_list(version)
    local code, html = https.request("https://openhexagon.fun/packs" .. tostring(version) .. "/")
    if code ~= 200 then
        log("get pack list request failed")
        return {}
    end
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
    pack_data_list = pack_data_list or api("get_packs")
    local list = {}
    for i = 1, #pack_data_list do
        local pack = pack_data_list[i]
        if pack.game_version == version then
            list[#list + 1] = pack
        end
    end
    return list
end

---downloads and extracts a pack in the right location
---@param version number
---@param pack_name string
function download.get(version, pack_name)
    local file = love.filesystem.newFile("tmp.zip")
    local download_size, last_progress = 0, nil
    file:open("w")
    log("Downloading", pack_name)
    http.request({
        url = "http://openhexagon.fun/packs" .. version .. "/" .. url.escape(pack_name) .. ".zip",
        sink = function(chunk, err)
            if err then
                log(err)
            elseif chunk then
                file:write(chunk)
                download_size = download_size + #chunk
                local progress = math.floor(download_size / pack_sizes[version][pack_name] * 100)
                if progress ~= last_progress then
                    love.thread.getChannel("pack_download_progress"):push(progress)
                    last_progress = progress
                end
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
