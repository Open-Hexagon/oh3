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

download.set_server_url(config.get("server_api_url"))

local pack_overlay = overlay:new()

local pack_list = flex:new({}, { direction = "column", align_items = "stretch" })
local selected_version = 21
local version_buttons

local create_pack_list = async(function()
    pack_list.elements = { label:new("Loading...") }
    pack_list:mutated(false)
    pack_list.elements[1]:update_size()
    local old_version = selected_version
    local packs = async.await(download.get_pack_list())
    if old_version ~= selected_version then
        -- user clicked on other version while loading
        return
    end
    local pack_id_elem_map = {}
    pack_list.elements = {}
    for i = 1, #packs do
        local pack = packs[i]
        if pack.game_version == selected_version then
            local downloading = false
            local progress_bar = progress:new({
                style = { background_color = { 0, 0, 0, 0 } },
            })
            local progress_collapse = collapse:new(progress_bar)
            local elem = quad:new({
                child_element = flex:new({
                    label:new(pack.name, { wrap = true }),
                    progress_collapse,
                }, { direction = "column", align_items = "stretch", align_relative_to = "parentparent" }),
                selectable = true,
                selection_handler = function(self)
                    if self.selected then
                        self.border_color = { 0, 0, 1, 1 }
                    else
                        self.border_color = { 1, 1, 1, 1 }
                    end
                end,
                click_handler = function(self)
                    self.download_promise = async(function()
                        if downloading then
                            -- download already in progress
                            return
                        end
                        downloading = true
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
                        local channel_name = string.format("pack_download_progress_%d_%s", selected_version, pack.folder_name)
                        channel_callbacks.register(channel_name, function(percent)
                            progress_bar.percentage = percent
                        end)
                        progress_collapse:toggle(true)
                        local ret = async.await(download.get(selected_version, pack.folder_name))
                        channel_callbacks.unregister(channel_name)
                        progress_collapse:toggle(false)
                        if ret then
                            downloading = false
                            progress_bar.percentage = 0
                            dialogs.alert(ret)
                            return
                        end
                        log("Waiting for dependency packs...")
                        for j = 1, #promises do
                            async.await(promises[j])
                        end
                        local pack_data = async.await(game_handler.import_pack(pack.folder_name, selected_version))
                        local elem = pack_elements.make_pack_element(pack_data, true)
                        -- element may not be created if an element for the pack already exists
                        if elem then
                            require("ui.screens.levelselect").state.packs:mutated(false)
                            elem:update_size()
                            elem:click()
                        end
                        table.remove(pack_list.elements, self.parent_index)
                        pack_list:mutated(false)
                        require("ui.elements.element").update_size(pack_list)
                        downloading = false
                    end)()
                    return self.download_promise
                end,
            })
            pack_list.elements[#pack_list.elements + 1] = elem
            pack_id_elem_map[pack.id] = elem
        end
    end
    pack_list:mutated(false)
    if pack_list.elements[1] then
        pack_list.elements[1]:update_size()
    end
end)

local function make_version_button(version)
    local background_color = { 0, 0, 0, 1 }
    if selected_version == version then
        background_color = { 0, 1, 1, 1 }
    end
    return quad:new({
        child_element = label:new(tostring(version)),
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.border_color = { 0, 0, 1, 1 }
            else
                self.border_color = { 1, 1, 1, 1 }
            end
        end,
        click_handler = function(self)
            for i = 1, #version_buttons do
                version_buttons[i].background_color = { 0, 0, 0, 1 }
            end
            self.background_color = { 0, 1, 1, 1 }
            selected_version = version
            create_pack_list()
        end,
        style = { background_color = background_color },
    })
end

version_buttons = {
    make_version_button(21),
    make_version_button(20),
    make_version_button(192),
}

pack_overlay.layout = quad:new({
    child_element = flex:new({
        flex:new({
            flex:new(version_buttons),
            quad:new({
                child_element = icon:new("x-lg"),
                selectable = true,
                selection_handler = function(self)
                    if self.selected then
                        self.border_color = { 0, 0, 1, 1 }
                    else
                        self.border_color = { 1, 1, 1, 1 }
                    end
                end,
                click_handler = function()
                    pack_overlay:close()
                end,
            }),
        }, { justify_content = "between" }),
        scroll:new(pack_list),
    }, { direction = "column" }),
})
pack_overlay.transition = transitions.slide
pack_overlay.onopen = create_pack_list

return pack_overlay
