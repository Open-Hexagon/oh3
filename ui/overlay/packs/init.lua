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

download.set_server_url(config.get("server_url"))

local pack_overlay = overlay:new()

local pack_list = flex:new({}, { direction = "column", align_items = "stretch" })
local selected_version = 21
local version_buttons

local create_pack_list = async(function()
    pack_list.elements = { label:new("Loading...") }
    pack_list:mutated(false)
    pack_list.elements[1]:update_size()
    local old_version = selected_version
    local packs = async.await(download.get_pack_list(selected_version))
    if old_version ~= selected_version then
        -- user clicked on other version while loading
        return
    end
    pack_list.elements = {}
    for i = 1, #packs do
        local progress_bar = progress:new({
            style = { background_color = { 0, 0, 0, 0 } },
        })
        local progress_collapse = collapse:new(progress_bar)
        pack_list.elements[i] = quad:new({
            child_element = flex:new({
                label:new(packs[i]),
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
            click_handler = async(function()
                if progress_bar.percentage ~= 0 then
                    -- download already in progress
                    return
                end
                channel_callbacks.register("pack_download_progress", function(percent)
                    progress_bar.percentage = percent
                end)
                progress_collapse:toggle(true)
                async.await(download.get(selected_version, packs[i]))
                channel_callbacks.unregister("pack_download_progress")
                progress_collapse:toggle(false)
                progress_bar.percentage = 0
                local pack = async.await(game_handler.import_pack(packs[i], selected_version))
                local elem = pack_elements.make_pack_element(pack, true)
                -- element may not be created if an element for the pack already exists
                if elem then
                    require("ui.screens.levelselect").state.packs:mutated(false)
                    elem:update_size()
                    elem:click()
                end
            end),
        })
    end
    pack_list:mutated(false)
    pack_list.elements[1]:update_size()
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
