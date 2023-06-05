---@class Screen
---@field up Screen? A reference to the screen that's above this screen.
---@field down Screen? A reference to the screen that's below this screen.
---@field pass boolean If true, events are ignored and passed to the next lower screen.
---@field on_insert function? A function that is run when the screen is inserted. Should reset a screen to its default state.
---@field draw function A function that draws the screen.
---@field handle_event function? A function that handles events.
---@field update function? A function that updates the screen.

local screen = {
    background = require("ui.screen.background"),
    title = require("ui.screen.title"),
    wheel = require("ui.screen.wheel"),
}

return screen
