local overlay = require("ui.overlay")
local transitions = require("ui.anim.transitions")
local flex = require("ui.layout.flex")
local quad = require("ui.elements.quad")
local scroll = require("ui.layout.scroll")
local icon = require("ui.elements.icon")
local label = require("ui.elements.label")
local threadify = require("threadify")
local download = threadify.require("ui.overlay.packs.download_thread")
local channel_callbacks = require("channel_callbacks")
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
    local packs = async.await(download.get_pack_list(selected_version))
    pack_list.elements = {}
    for i = 1, #packs do
        pack_list.elements[i] = quad:new({
            child_element = label:new(packs[i]),
            selectable = true,
            selection_handler = function(self)
                if self.selected then
                    self.border_color = { 0, 0, 1, 1 }
                else
                    self.border_color = { 1, 1, 1, 1 }
                end
            end,
            click_handler = function()
                download.get(selected_version, packs[i])
            end,
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
