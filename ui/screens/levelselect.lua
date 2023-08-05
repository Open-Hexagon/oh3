local flex = require("ui.layout.flex")
local label = require("ui.elements.label")
local quad = require("ui.elements.quad")
local dropdown = require("ui.elements.dropdown")
local toggle = require("ui.elements.toggle")
local slider = require("ui.elements.slider")

local level = {}
local pack = {}

--level element! if this is used in more than just the level select, this should be seperate ;o
function level:new(info)
    info = info or {}
	music = info.song .. "\n" .. info.composer
	
    return quad:new({
		child_element = flex:new({
			quad:new({
				child_element = label:new(info.image), --should be a preview of the level
				style = { background_color = { 0, 0, 0, 0 }, border_color = { 1, 1, 1, 1 } },
			}),
			flex:new({
				label:new(info.title, {font_size = 40}),
				label:new(info.author, {font_size = 30}),
				label:new(info.description, {font_size = 20, wrap = true}),
			}, { direction = "column", style = {padding = 5} }),
			label:new(music, {font_size = 30}),
		}, { direction = "row"}),
		style = { background_color = { 0, 0, 0, 0.7 }, border_color = { 0, 0, 0, 0.7 } },
	})
end

function pack:new(name)
    return quad:new({
		child_element = label:new(name, { font_size = 30, style={color = {0,0,0,1}}}),
		style = { background_color = { 1, 1, 1, 1 }, border_color = { 1, 1, 1, 1 } },
	})
end

return flex:new({
	--packs
    flex:new({
		label:new("packs"),
		dropdown:new({"All Packs", "Favorites" }),
		pack:new("test"),
		pack:new("test"),
		pack:new("test"),
		pack:new("test"),
    }, { direction = "column", align_items = "stretch"} ),
	
	--levels
    flex:new({
		label:new("levels"),
		level:new({image = "", title = "title", author = "author", description = "description is here!! and it is very long and detailed waaa and it even wraps!!", song = '"new song"', composer = "Theepicosity"}),
    }, { direction = "column", align_items = "stretch"}),
	
	--leaderboards
    flex:new({
		label:new("lbs"), --todo: "score" element similar to those other two, holds the score data like time, player, place, etc.
    }, { direction = "column", align_items = "start"}),
	
}, { same_size = false, scrollable = false })
