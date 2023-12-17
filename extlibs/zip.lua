-- small library for zip extraction derived from zzlib
local zip = {}
zip.__index = zip

---create a new zip file object
---@param path string
---@return table
function zip:new(path)
    return setmetatable({
        path = path,
        file = love.filesystem.newFile(path, "r"),
    }, zip)
end

function zip:read_int_at(pos, size)
    self.file:seek(pos - 1)
    return love.data.unpack("<I" .. size, self.file:read(size), 1)
end

---returns an iterator over all files in the zip
---@return function
function zip:list_files()
    local size = self.file:getSize()
    local pos = size - 21
    if self:read_int_at(pos, 4) ~= 0x06054b50 then
        error(".ZIP file comments not supported")
    end
    pos = self:read_int_at(pos + 16, 4) + 1
    return function()
        if self:read_int_at(pos, 4) ~= 0x02014b50 then
            return
        end
        local packed = self:read_int_at(pos + 10, 2) ~= 0
        local crc = self:read_int_at(pos + 16, 4)
        local namelen = self:read_int_at(pos + 28, 2)
        self.file:seek(pos + 45)
        local name = self.file:read(namelen)
        local offset = self:read_int_at(pos + 42, 4) + 1
        pos = pos + 46 + namelen + self:read_int_at(pos + 30, 2) + self:read_int_at(pos + 32, 2)
        if self:read_int_at(offset, 4) ~= 0x04034b50 then
            error("invalid local header signature")
        end
        local file_size = self:read_int_at(offset + 18, 4)
        local extlen = self:read_int_at(offset + 28, 2)
        offset = offset + 30 + namelen + extlen
        return pos, name, offset, file_size, packed, crc
    end
end

local crc32_table

local function crc32(s)
    if not crc32_table then
        crc32_table = {}
        for i = 0, 255 do
            local r = i
            for _ = 1, 8 do
                r = bit.bxor(bit.rshift(r, 1), bit.band(0xedb88320, bit.bnot(bit.band(r, 1) - 1)))
            end
            crc32_table[i] = r
        end
    end
    local crc = bit.bnot(0)
    for i = 1, #s do
        local c = s:byte(i)
        crc = bit.bxor(crc32_table[bit.bxor(c, bit.band(crc, 0xff))], bit.rshift(crc, 8))
    end
    crc = bit.bnot(crc)
    if crc < 0 then
        crc = crc + 4294967296
    end
    return crc
end

---unzip all files into a directory
---@param path string
function zip:unzip(path)
    path = path or ""
    if path:sub(-1, -1) ~= "/" then
        path = path .. "/"
    end
    for _, name, offset, size, packed, crc in self:list_files() do
        name = name .. path
        if name:sub(-1, -1) == "/" then
            love.filesystem.createDirectory(name)
        else
            self.file:seek(offset - 1)
            local data = self.file:read(size)
            if packed then
                -- DEFLATE compression
                data = love.data.decompress("string", "deflate", data)
                if crc and crc ~= crc32(data) then
                    error("checksum verification failed")
                end
            end
            local file = love.filesystem.newFile(name)
            file:open("w")
            file:write(data)
            file:close()
        end
    end
end

---close the zip file
function zip:close()
    self.file:close()
end

return zip
