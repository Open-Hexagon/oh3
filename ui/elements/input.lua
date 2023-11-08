local icon_mappings = {
    keyboard = {
        a = "Key A",
        b = "Key B",
        c = "Key C",
        d = "Key D",
        e = "Key E",
        f = "Key F",
        g = "Key G",
        h = "Key H",
        i = "Key I",
        j = "Key J",
        k = "Key K",
        l = "Key L",
        m = "Key M",
        n = "Key N",
        o = "Key O",
        p = "Key P",
        q = "Key Q",
        r = "Key R",
        s = "Key S",
        t = "Key T",
        u = "Key U",
        v = "Key V",
        w = "Key W",
        x = "Key X",
        y = "Key Y",
        z = "Key Z",
        [0] = "Key 0",
        [1] = "Key 1",
        [2] = "Key 2",
        [3] = "Key 3",
        [4] = "Key 4",
        [5] = "Key 5",
        [6] = "Key 6",
        [7] = "Key 7",
        [8] = "Key 8",
        [9] = "Key 9",
        space = "Space",
        ["!"] = "ASCII !",
        ['"'] = 'ASCII "',
        ["#"] = "ASCII #",
        ["$"] = "ASCII $",
        ["&"] = "ASCII &",
        ["'"] = "ASCII '",
        ["("] = "ASCII (",
        [")"] = "ASCII )",
        ["*"] = "ASCII *",
        ["+"] = "ASCII +",
        [","] = "ASCII ,",
        ["-"] = "ASCII -",
        ["."] = "ASCII .",
        ["/"] = "ASCII /",
        [":"] = "ASCII :",
        [";"] = "ASCII ;",
        ["<"] = "ASCII <",
        ["="] = "ASCII =",
        [">"] = "ASCII >",
        ["?"] = "ASCII ?",
        ["@"] = "ASCII @",
        ["["] = "ASCII [",
        ["\\"] = "ASCII \\",
        ["]"] = "ASCII ]",
        ["^"] = "ASCII ^",
        ["_"] = "ASCII _",
        ["`"] = "ASCII `",
        kp0 = "",
        kp1 = "",
        kp2 = "",
        kp3 = "",
        kp4 = "",
        kp5 = "",
        kp6 = "",
        kp7 = "",
        kp8 = "",
        kp9 = "",
        ["kp."] = "",
        ["kp,"] = "",
        ["kp/"] = "",
        ["kp*"] = "",
        ["kp-"] = "",
        ["kp+"] = "",
        kpenter = "",
        ["kp="] = "",
        up = "Arrow Up",
        down = "Arrow Down",
        right = "Arrow Right",
        left = "Arrow Left",
        home = "Home",
        ["end"] = "End",
        pageup = "Page Up",
        pagedown = "Page Down",
        insert = "Insert",
        backspace = "Backspace",
        tab = "Tab",
        clear = "",
        ["return"] = "Enter",
        delete = "Delete",
        f1 = "F1",
        f2 = "F2",
        f3 = "F3",
        f4 = "F4",
        f5 = "F5",
        f6 = "F6",
        f7 = "F7",
        f8 = "F8",
        f9 = "F9",
        f10 = "F10",
        f11 = "F11",
        f12 = "F12",
        f13 = "",
        f14 = "",
        f15 = "",
        f16 = "",
        f17 = "",
        f18 = "",
        numlock = "NumLock",
        capslock = "Caps",
        scrolllock = "ScrLk",
        rshift = "",
        lshift = "Shift",
        rctrl = "",
        lctrl = "Ctrl",
        ralt = "",
        lalt = "Alt",
        rgui = "",
        lgui = "Super",
        mode = "",
        www = "",
        mail = "",
        calculator = "",
        computer = "",
        appsearch = "",
        apphome = "",
        appback = "",
        appforward = "",
        apprefresh = "",
        appbookmarks = "",
        pause = "Pause",
        escape = "Esc",
        help = "",
        printscreen = "PrtSc",
        sysreq = "",
        menu = "",
        application = "",
        power = "",
        currencyunit = "",
        undo = "",
    },
    mouse = {
        [1] = "Mouse Button 1",
        [3] = "Mouse Button 3",
        [2] = "Mouse Button 2",
        [4] = "Mouse Button 4",
        [5] = "Mouse Button 5",
    },
    touch = {
        left = "square-half",
        right = "square-half:mirror",
    },
}
local icon = require("ui.elements.icon")
local input_schemes = require("input_schemes")
local async = require("async")

local input = {}
input.__index = setmetatable(input, icon)

function input:new(scheme, id, options)
    local icon_id = icon_mappings[scheme][id]
    if icon_id == "" then
        icon_id = id
    end
    local mirror
    icon_id, mirror = icon_id:gsub(":mirror", "")
    local obj = icon:new(icon_id, options)
    obj.mirror = mirror == 1
    setmetatable(obj, input)
    obj.scheme = scheme
    obj.waiting = false
    return obj
end

function input:calculate_layout(width, height)
    local w, h = icon.calculate_layout(self, width, height)
    if self.mirror then
        self.transform:reset(0)
        self.transform:scale(-1, 1, 0)
        self.transform:translate(w, 0, 0)
    end
    return w, h
end

function input:set_icon(id)
    local icon_id = icon_mappings[self.scheme][id]
    if icon_id == "" then
        icon_id = id
    end
    self:set(icon_id)
    if self.change_handler then
        self.change_handler(id)
    end
end

function input:process_event(name, ...)
    if self.waiting and self.resolve then
        for id in pairs(icon_mappings[self.scheme]) do
            if input_schemes[self.scheme].is_down(id) then
                self.resolve(id)
                self.resolve = nil
                break
            end
        end
    else
        icon.process_event(self, name, ...)
        require("ui").only_interactable_element = nil
    end
end

input.wait_for_input = async(function(self)
    self.waiting = true
    self.text:clear()
    require("ui").only_interactable_element = self
    local id = async.await(async.promise:new(function(resolve)
        self.resolve = resolve
    end))
    self.waiting = false
    self:set_icon(id)
end)

return input
