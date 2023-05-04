local tris = {}
tris.__index = tris

local instance_vertex_shader = love.graphics.newShader([[
attribute vec2 instance_position;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
	vertex_position.xy += instance_position;
	return transform_projection * vertex_position;
}
]])

local step_size = 255

function tris:_resize()
    for _ = 1, step_size do
        self.vertices[#self.vertices + 1] = { 0, 0, 0, 0, 1, 1, 1, 1 }
        self.size = self.size + 1
    end
    self.mesh = love.graphics.newMesh(self.vertices, "triangles", "stream")
    if self.instance_mesh ~= nil then
        self.mesh:attachAttribute("instance_position", self.instance_mesh, "perinstance")
    end
end

function tris:new()
    local obj = setmetatable({
        vertices = {},
        vertex_map = {},
        size = 0,
        tris = 0,
    }, self)
    obj:_resize()
    return obj
end

function tris:add_tris(x0, y0, x1, y1, x2, y2, r0, g0, b0, a0, r1, g1, b1, a1, r2, g2, b2, a2)
    self.tris = self.tris + 1
    if self.tris * 3 > self.size then
        self:_resize()
    end
    local vert_index = self.tris * 3
    local vertex = self.vertices[vert_index - 2]
    vertex[1], vertex[2], vertex[5], vertex[6], vertex[7], vertex[8] = x0, y0, r0 / 255, g0 / 255, b0 / 255, a0 / 255
    vertex = self.vertices[vert_index - 1]
    vertex[1], vertex[2], vertex[5], vertex[6], vertex[7], vertex[8] = x1, y1, (r1 or r0) / 255, (g1 or g0) / 255, (b1 or b0) / 255, (a1 or a0) / 255
    vertex = self.vertices[vert_index]
    vertex[1], vertex[2], vertex[5], vertex[6], vertex[7], vertex[8] = x2, y2, (r2 or r0) / 255, (g2 or g0) / 255, (b2 or b0) / 255, (a2 or a0) / 255
end

function tris:clear()
    self.tris = 0
end

function tris:draw()
    if self.tris ~= 0 then
        self.mesh:setVertices(self.vertices)
        self.mesh:setDrawRange(1, self.tris * 3)
        love.graphics.draw(self.mesh)
    end
end

function tris:draw_instanced(count, positions)
    if self.tris ~= 0 then
        if self.instance_mesh == nil or #positions ~= self.instance_mesh:getVertexCount() then
            self.instance_mesh =
                love.graphics.newMesh({ { "instance_position", "float", 2 } }, positions, nil, "stream")
            self.mesh:attachAttribute("instance_position", self.instance_mesh, "perinstance")
        else
            self.instance_mesh:setVertices(positions)
        end
        self.mesh:setVertices(self.vertices)
        self.mesh:setDrawRange(1, self.tris * 3)
        love.graphics.setShader(instance_vertex_shader)
        love.graphics.drawInstanced(self.mesh, count)
        love.graphics.setShader()
    end
end

return tris
