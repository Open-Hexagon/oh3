local theme = {}

theme.themes = {
    old_default = {
        text_color = { 1, 1, 1, 1 },
        greyed_out_text_color = { 1, 1, 1, 0.5 },
        contrast_text_color = { 0, 0, 0, 1 },
        background_color = { 0, 0, 0, 1 },
        contrast_background_color = { 1, 1, 1, 1 },
        light_background_color = { 0.5, 0.5, 0.5, 1 },
        selection_color = { 0, 0, 1, 1 },
        light_selection_color = { 0.5, 0.5, 1, 1 },
        transparent_light_selection_color = { 0.5, 0.5, 0, 1 },
        border_color = { 1, 1, 1, 1 },
        border_thickness = 1,
    },
    default = {
        text_color = { 1, 1, 1, 1 },
        greyed_out_text_color = { 1, 1, 1, 0.5 },
        contrast_text_color = { 0, 0, 0, 1 },
        background_color = { 0.1, 0.1, 0.1, 0.7 },
        contrast_background_color = { 1, 1, 1, 1 },
        light_background_color = { 0.5, 0.5, 0.5, 1 },
        selection_color = { 0, 0, 1, 0.7 },
        light_selection_color = { 0.5, 0.5, 0, 1 },
        transparent_light_selection_color = { 0.5, 0.5, 0, 0.7 },
        border_color = { 0, 0, 0, 0.7 },
        border_thickness = 2,
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
