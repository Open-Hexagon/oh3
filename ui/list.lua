-- This module holds a list of all overlays/screens

local M = {}

local active_screens = {}

-- Dummy objects
M.bottom, M.top = {}, {}
M.bottom.up = M.top
M.top.down = M.bottom

---Insert a screen in relation to bottommost screen
---@param screen Screen
---@param pos integer?
function M.emplace_bottom(screen, pos)
    if screen.on_insert then
        screen:on_insert()
    end
    if active_screens[screen] then
        error("Tried to insert an already active screen")
    end
    pos = pos or 0
    local item = M.bottom
    for _ = 1, pos do
        item = item.down
        if item == M.top then
            error("Tried to insert a screen above the topmost object", 2)
        end
    end
    screen.down = item
    screen.up = item.up
    item.up.down = screen
    item.up = screen
    active_screens[screen] = true
end

---Insert a screen in relation to the topmost screen
---@param screen Screen
---@param pos integer?
function M.emplace_top(screen, pos)
    if screen.on_insert then
        screen:on_insert()
    end
    if active_screens[screen] then
        error("Tried to insert an already active screen")
    end
    pos = pos or 0
    local item = M.top
    for _ = 1, pos do
        item = item.down
        if item == M.bottom then
            error("Tried to insert a screen underneath the bottommost object", 2)
        end
    end
    screen.up = item
    screen.down = item.down
    item.down.up = screen
    item.down = screen
    active_screens[screen] = true
end

---Inserts a screen above another screen.
---@param screen Screen
---@param base_screen Screen
---@param pos integer?
function M.emplace_above(screen, base_screen, pos)
    if screen.on_insert then
        screen:on_insert()
    end
    if active_screens[screen] then
        error("Tried to insert an already active screen")
    end
    pos = pos or 0
    local item = base_screen
    for _ = 1, pos do
        item = item.down
        if item == M.top then
            error("Tried to insert a screen above the topmost object", 2)
        end
    end
    screen.down = item
    screen.up = item.up
    item.up.down = screen
    item.up = screen
    active_screens[screen] = true
end

---Inserts a screen below another screen.
---@param screen Screen
---@param base_screen Screen
---@param pos integer?
function M.emplace_below(screen, base_screen, pos)
    if screen.on_insert then
        screen:on_insert()
    end
    if active_screens[screen] then
        error("Tried to insert an already active screen")
    end
    pos = pos or 0
    local item = base_screen
    for _ = 1, pos do
        item = item.down
        if item == M.bottom then
            error("Tried to insert a screen underneath the bottommost object", 2)
        end
    end
    screen.up = item
    screen.down = item.down
    item.down.up = screen
    item.down = screen
    active_screens[screen] = true
end

---Removes a specific screen from the list
---@param screen Screen
function M.remove(screen)
    if not active_screens[screen] then
        error("Tried to remove an inactive screen")
    end
    local lower = screen.down
    local upper = screen.up
    lower.up = upper
    upper.down = lower
    screen.up, screen.down = nil, nil
    active_screens[screen] = false
end

---Draws all screens from bottom to top
function M.draw()
    local screen = M.bottom.up
    while screen.up do
        screen:draw()
        screen = screen.up
    end
end

---Sends events to the topmost screen
function M.handle_event(name, a, b, c, d, e, f)
    local screen = M.top.down
    while screen.down do
        if not screen.pass and screen.handle_event then
            return screen:handle_event(name, a, b, c, d, e, f)
        end
        screen = screen.down
    end
end

function M.update(dt)
    local screen = M.bottom.up
    while screen.up do
        if screen.update then
            screen:update(dt)
        end
        screen = screen.up
    end
end

return M
