local overlay = require("ui.overlay")
local transitions = require("ui.anim.transitions")
local flex = require("ui.layout.flex")
local quad = require("ui.elements.quad")
local scroll = require("ui.layout.scroll")
local icon = require("ui.elements.icon")
local label = require("ui.elements.label")
local progress = require("ui.elements.progress")
local collapse = require("ui.layout.collapse")
local threadify = require("threadify")
local download = threadify.require("ui.overlay.packs.download_thread")
local channel_callbacks = require("channel_callbacks")
local pack_elements = require("ui.screens.levelselect.packs")
local game_handler = require("game_handler")
local async = require("async")
local config = require("config")
local dialogs = require("ui.overlay.dialog")
local log = require("log")(...)

download.set_server(config.get("server_url"), config.get("server_http_api_port"), config.get("server_https_api_port"))

local pack_overlay = overlay:new()

local pack_list = flex:new({}, { direction = "column", align_items = "stretch" })

local ongoing_downloads = {}
local pack_id_elem_map = {}

local current_chunk = 0
local chunk_size = 50
local loading_in_progress = false
local all_loaded = false

local load_pack_chunk = async(function()
    loading_in_progress = true
    pack_list.elements[#pack_list.elements + 1] = label:new("Loading...")
    pack_list:mutated(false)
    pack_list.elements[#pack_list.elements]:update_size()
    local new_packs
    repeat
        local start = current_chunk * chunk_size + 1
        local stop = current_chunk * chunk_size + chunk_size
        new_packs = async.await(download.get_pack_list(start, stop))
        if new_packs then
            current_chunk = current_chunk + 1
        end
    until new_packs ~= nil and (type(new_packs) ~= "table" or #new_packs ~= 0)
    if new_packs == true then
        pack_list.elements[#pack_list.elements] = nil
        pack_list.elements[1]:update_size()
        all_loaded = true
        loading_in_progress = false
        return
    end
    pack_list.elements[#pack_list.elements] = nil
    local new_elem
    for i = 1, #new_packs do
        local pack = new_packs[i]
        local progress_bar = progress:new({
            style = { background_color = { 0, 0, 0, 0 } },
        })
        local progress_collapse = collapse:new(progress_bar)
        local channel_name = string.format("pack_download_progress_%d_%s", pack.game_version, pack.folder_name)
        channel_callbacks.register(channel_name, function(percent)
            progress_bar.percentage = percent
            progress_collapse:toggle(true)
        end)
        local elem = quad:new({
            child_element = flex:new({
                label:new(pack.name, { wrap = true }),
                progress_collapse,
            }, { direction = "column", align_items = "stretch", align_relative_to = "parentparent" }),
            selectable = true,
            click_handler = function(self)
                self.download_promise = async(function()
                    ongoing_downloads[pack.game_version] = ongoing_downloads[pack.game_version] or {}
                    if ongoing_downloads[pack.game_version][pack.folder_name] then
                        -- download already in progress
                        return
                    end
                    ongoing_downloads[pack.game_version][pack.folder_name] = true
                    local promises = {}
                    for j = 1, #pack.dependency_ids do
                        local elem = pack_id_elem_map[pack.dependency_ids[j]]
                        -- element may not exist if pack is already downloaded
                        if elem then
                            if elem.download_promise then
                                -- download is in progress
                                promises[#promises + 1] = elem.download_promise
                            else
                                -- download is started
                                promises[#promises + 1] = elem.click_handler(elem)
                            end
                        end
                    end
                    local ret = async.await(download.get(pack.game_version, pack.folder_name))
                    progress_collapse:toggle(false)
                    if ret then
                        ongoing_downloads[pack.game_version][pack.folder_name] = nil
                        progress_bar.percentage = 0
                        dialogs.alert(ret)
                        return
                    end
                    log("Waiting for dependency packs...")
                    for j = 1, #promises do
                        async.await(promises[j])
                    end
                    local pack_data = async.await(game_handler.import_pack(pack.folder_name, pack.game_version))
                    local elem = pack_elements.make_pack_element(pack_data, true)
                    -- element may not be created if an element for the pack already exists
                    if elem then
                        require("ui.screens.levelselect").state.packs:mutated(false)
                        elem:update_size()
                        elem:click(false)
                    end
                    table.remove(pack_list.elements, self.parent_index)
                    pack_list:mutated(false)
                    require("ui.elements.element").update_size(pack_list)
                    ongoing_downloads[pack.game_version][pack.folder_name] = nil
                end)()
                return self.download_promise
            end,
        })
        pack_list.elements[#pack_list.elements + 1] = elem
        pack_id_elem_map[pack.id] = elem
        new_elem = elem
    end
    if new_elem then
        pack_list:mutated(false)
        new_elem:update_size()
    elseif #pack_list.elements > 0 then
        pack_list.elements[1]:update_size()
    end
    loading_in_progress = false
end)

local pack_scroll
local current_promise
pack_scroll = scroll:new(pack_list, {
    change_handler = async(function(scroll_pos)
        if all_loaded then
            return
        end
        if scroll_pos == pack_scroll.max_scroll then
            while loading_in_progress and current_promise do
                async.await(current_promise)
            end
            current_promise = load_pack_chunk()
        end
    end),
})
pack_overlay.layout = quad:new({
    child_element = flex:new({
        flex:new({
            label:new("All packs"),
            quad:new({
                child_element = icon:new("x-lg"),
                selectable = true,
                click_handler = function()
                    pack_overlay:close()
                end,
            }),
        }, { justify_content = "between" }),
        pack_scroll,
    }, { direction = "column" }),
})
pack_overlay.transition = transitions.slide
pack_overlay.onopen = async(function()
    if all_loaded then
        return
    end
    if current_chunk == 0 and not loading_in_progress then
        while pack_list.height <= pack_scroll.height do
            current_promise = load_pack_chunk()
            async.await(current_promise)
        end
    end
end)

return pack_overlay
