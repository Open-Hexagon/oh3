local input = require("ui.elements.input")
local config = require("config")
local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local collapse = require("ui.layout.collapse")
local input_schemes = require("input_schemes")
local async = require("async")

local function make_button(name, callback)
    return quad:new({
        child_element = label:new(name),
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.border_color = { 0, 0, 1, 1 }
            else
                self.border_color = { 1, 1, 1, 1 }
            end
        end,
        click_handler = callback,
    })
end

-- TODO: clean all of this up a bit
return function(property)
    local set_scheme, scheme_select_collapse
    scheme_select_collapse = collapse:new(flex:new({
        make_button("keyboard", function()
            set_scheme("keyboard")
            return true
        end),
        make_button("mouse", function()
            set_scheme("mouse")
            return true
        end),
        make_button("touch", function()
            set_scheme("touch")
            return true
        end),
        make_button("cancel", function()
            scheme_select_collapse:toggle(false)
            return true
        end),
    }))
    local schemes = config.get(property.name)
    local item_layout, layout
    local function new_binding(scheme_name, input_id)
        local function search_indices()
            local scheme_index, id_index
            for k = 1, #schemes do
                if schemes[k].scheme == scheme_name then
                    scheme_index = k
                    break
                end
            end
            for k = 1, #schemes[scheme_index].ids do
                if schemes[scheme_index].ids[k] == input_id then
                    id_index = k
                    break
                end
            end
            return scheme_index, id_index
        end
        return quad:new({
            child_element = input:new(scheme_name, input_id, {
                change_handler = function(id)
                    -- search scheme and id index as it may have change
                    local scheme_index, id_index = search_indices()
                    input_id = id
                    schemes[scheme_index].ids[id_index] = id
                end,
            }),
            selectable = true,
            selection_handler = function(self)
                if self.selected then
                    self.border_color = { 0, 0, 1, 1 }
                else
                    self.border_color = { 1, 1, 1, 1 }
                end
            end,
            click_handler = function(self)
                self.element:wait_for_input():done(function(btn)
                    local is_in = false
                    for i = 1, #item_layout.elements do
                        if item_layout.elements[i] == self then
                            is_in = true
                            break
                        end
                    end
                    if not is_in then
                        if btn then
                            return
                        end
                        table.insert(item_layout.elements, #item_layout.elements, self)
                        item_layout:mutated(false)
                    end
                    if btn == "remove" then
                        -- search scheme and id index as it may have change
                        local scheme_index, id_index = search_indices()
                        table.remove(schemes[scheme_index].ids, id_index)
                        -- remove quad from parent
                        table.remove(self.parent.elements, self.parent_index)
                        item_layout:mutated(false)
                        layout.changed = true
                        require("ui.elements.element").update_size(item_layout)
                    else
                        self:update_size()
                    end
                end)
                return true
            end,
        })
    end
    local items = {}
    for i = 1, #schemes do
        for j = 1, #schemes[i].ids do
            local scheme_name = schemes[i].scheme
            local input_id = schemes[i].ids[j]
            items[#items + 1] = new_binding(scheme_name, input_id)
        end
    end
    items[#items + 1] = quad:new({
        child_element = label:new("+"),
        selectable = true,
        selection_handler = function(self)
            if self.selected then
                self.border_color = { 0, 0, 1, 1 }
            else
                self.border_color = { 1, 1, 1, 1 }
            end
        end,
        click_handler = function()
            async.promise
                :new(function(resolve)
                    set_scheme = resolve
                    scheme_select_collapse:toggle(true)
                end)
                :done(function(scheme)
                    scheme_select_collapse:toggle(false)
                    local input_id = input_schemes[scheme].defaults.right[1]
                    local scheme_index
                    for i = 1, #schemes do
                        if schemes[i].scheme == scheme then
                            scheme_index = i
                            break
                        end
                    end
                    if not scheme_index then
                        scheme_index = #schemes + 1
                        schemes[#schemes + 1] = {
                            scheme = scheme,
                            ids = { input_id },
                        }
                    else
                        schemes[scheme_index].ids[#schemes[scheme_index].ids + 1] = input_id
                    end
                    local elem = new_binding(scheme, input_id)
                    elem:click()
                end)
            return true
        end,
    })
    item_layout = flex:new(items, { align_items = "center" })
    layout = flex:new(
        { label:new(property.display_name), item_layout },
        { justify_content = "between", align_items = "center" }
    )
    return flex:new({
        layout,
        scheme_select_collapse,
    }, { direction = "column" })
end
