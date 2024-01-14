local theme = {}

theme.themes = {
    default = {
        background_color = { 0, 0, 0, 1 },
        light_background_color = { 0.5, 0.5, 0.5, 1 },
        selection_color = { 0, 0, 1, 1 },
        light_selection_color = { 0.5, 0.5, 1, 1 },
        border_color = { 1, 1, 1, 1 },
    },
}

theme.current_theme = theme.themes.default

function theme.set(name)
    theme.current_theme = theme.themes[name]
end

function theme.get(key)
    return theme.current_theme[key] or theme.themes.default[key]
end

function theme.get_selection_handler()
    return function(self)
        if self.selected then
            self.border_color = theme.get("selection_color")
        else
            self.border_color = theme.get("border_color")
        end
    end
end

return theme
