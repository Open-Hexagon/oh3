local quads = {}
quads.__index = quads

local instance_vertex_shader = love.graphics.newShader([[
attribute vec2 instance_position;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
	vertex_position.xy += instance_position;
	return transform_projection * vertex_position;
}
]])

local step_size = 256

function quads:_resize()
    for _ = 1, step_size do
        self.vertices[#self.vertices + 1] = { 0, 0, 0, 0, 1, 1, 1, 1 }
    end
    local start = self.size * 4
    for i = 0, step_size - 1, 4 do
        self.vertex_map[#self.vertex_map + 1] = 1 + i + start
        self.vertex_map[#self.vertex_map + 1] = 2 + i + start
        self.vertex_map[#self.vertex_map + 1] = 3 + i + start
        self.vertex_map[#self.vertex_map + 1] = 1 + i + start
        self.vertex_map[#self.vertex_map + 1] = 4 + i + start
        self.vertex_map[#self.vertex_map + 1] = 3 + i + start
        self.size = self.size + 1
    end
    self.mesh = love.graphics.newMesh(self.vertices, "triangles", "stream")
    self.mesh:setVertexMap(self.vertex_map)
    if self.instance_mesh ~= nil then
        self.mesh:attachAttribute("instance_position", self.instance_mesh, "perinstance")
    end
end

function quads:new()
    local obj = setmetatable({
        vertices = {},
        vertex_map = {},
        size = 0,
        quads = 0,
    }, self)
    obj:_resize()
    return obj
end

function quads:add_quad(x0, y0, x1, y1, x2, y2, x3, y3, r0, g0, b0, a0, r1, g1, b1, a1, r2, g2, b2, a2, r3, g3, b3, a3)
    self.quads = self.quads + 1
    if self.quads > self.size then
        self:_resize()
    end
    local vert_index = self.quads * 4
    local vertex = self.vertices[vert_index - 3]
    vertex[1], vertex[2], vertex[5], vertex[6], vertex[7], vertex[8] = x0, y0, r0 / 255, g0 / 255, b0 / 255, a0 / 255
    vertex = self.vertices[vert_index - 2]
    vertex[1], vertex[2], vertex[5], vertex[6], vertex[7], vertex[8] = x1, y1, (r1 or r0) / 255, (g1 or g0) / 255, (b1 or b0) / 255, (a1 or a0) / 255
    vertex = self.vertices[vert_index - 1]
    vertex[1], vertex[2], vertex[5], vertex[6], vertex[7], vertex[8] = x2, y2, (r2 or r0) / 255, (g2 or g0) / 255, (b2 or b0) / 255, (a2 or a0) / 255
    vertex = self.vertices[vert_index]
    vertex[1], vertex[2], vertex[5], vertex[6], vertex[7], vertex[8] = x3, y3, (r3 or r0) / 255, (g3 or g0) / 255, (b3 or b0) / 255, (a3 or a0) / 255
end

function quads:clear()
    self.quads = 0
end

function quads:draw()
    if self.quads ~= 0 then
        self.mesh:setVertices(self.vertices)
        self.mesh:setDrawRange(1, self.quads * 6)
        love.graphics.draw(self.mesh)
    end
end

function quads:draw_instanced(count, positions)
    if self.quads ~= 0 then
        if self.instance_mesh == nil or #positions ~= self.instance_mesh:getVertexCount() then
            self.instance_mesh =
                love.graphics.newMesh({ { "instance_position", "float", 2 } }, positions, nil, "stream")
            self.mesh:attachAttribute("instance_position", self.instance_mesh, "perinstance")
        else
            self.instance_mesh:setVertices(positions)
        end
        self.mesh:setVertices(self.vertices)
        self.mesh:setDrawRange(1, self.quads * 6)
        love.graphics.setShader(instance_vertex_shader)
        love.graphics.drawInstanced(self.mesh, count)
        love.graphics.setShader()
    end
end

return quads
