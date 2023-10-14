local mouse = {
    defaults = {
        right = { 2 },
        left = { 1 },
        swap = { 3 },
    },
}

function mouse.is_down(id)
    return love.mouse.isDown(id)
end

return mouse
