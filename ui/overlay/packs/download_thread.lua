-- require can't find it on android (other platforms will just silently fail and put in nil (the love.system module is not available))
package.preload.luv = package.loadlib("libluv.so", "luaopen_luv")
local log = require("log")("ui.overlay.packs.download_thread")
local json = require("extlibs.json.json")
local https = require("https")
local threadify = require("threadify")
local assets = threadify.require("game_handler.assets")
local uv = require("luv")

local server_api_url = ""
local tmp_folder = "download_cache/"
if not love.filesystem.getInfo(tmp_folder) then
    love.filesystem.createDirectory(tmp_folder)
end

local pack_data_list
local pack_map = {}
local download = {}

local function api(suffix)
    local code, json_data = https.request(server_api_url .. suffix)
    if code ~= 200 then
        log("'" .. suffix .. "' api request failed")
        return
    end
    if not json_data or (json_data:sub(1, 1) ~= "{" and json_data:sub(1, 1) ~= "[") then
        -- something went wrong
        return
    end
    return json.decode(json_data)
end

function download.set_server_url(serv_api_url)
    server_api_url = serv_api_url
end

---gets a list of pack names for the specified game version
---@return table
function download.get_pack_list()
    if not pack_data_list then
        pack_data_list = api("get_packs")
        if not pack_data_list then
            return {}
        end
        -- remove packs the player already has
        local promise = assets.init({}, true)
        local result
        promise:done(function(res)
            result = res
        end)
        while not promise.executed do
            threadify.update()
            uv.sleep(10)
        end
        if not result then
            error("could not get current pack list")
        end
        local map = {}
        for i = 1, #result do
            local pack = result[i]
            map[pack.game_version] = map[pack.game_version] or {}
            map[pack.game_version][pack.id] = true
        end
        for i = #pack_data_list, 1, -1 do
            local pack = pack_data_list[i]
            pack_map[pack.game_version] = pack_map[pack.game_version] or {}
            pack_map[pack.game_version][pack.folder_name] = pack
            if map[pack.game_version] and map[pack.game_version][pack.id] then
                table.remove(pack_data_list, i)
            end
        end
    end
    return pack_data_list
end

---downloads and extracts a pack in the right location
---@param version number
---@param pack_name string
---@return string?
function download.get(version, pack_name)
    local thread = love.thread.newThread("ui/overlay/packs/download.lua")
    thread:start(version, pack_name, tmp_folder, server_api_url, pack_map[version][pack_name].file_size)
    while thread:isRunning() do
        coroutine.yield()
    end
    local err = thread:getError() or love.thread.getChannel(string.format("pack_download_error_%d_%s", version, pack_name)):pop()
    if err then
        return err
    end
    for i = #pack_data_list, 1, -1 do
        local pack = pack_data_list[i]
        if pack.game_version == version and pack.folder_name == pack_name then
            table.remove(pack_data_list, i)
            break
        end
    end
    log("Done")
end
download.get_co = true

return download
