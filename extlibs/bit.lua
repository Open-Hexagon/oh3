-- This file is only loaded with require("bit") when not using luajit
local ffi = require("ffi")

local M = {}

local function set_mode(...)
    local bits = 32
    for i = 1, select("#", ...) do
        if type(select(i, ...)) ~= "number" then
            bits = 64
        end
    end
    M.num_bits = bits
    if bits == 32 then
        M.zero = 0
        M.one = 1
        M.two = 2
    else
        M.zero = ffi.new("uint64_t", 0)
        M.one = ffi.new("uint64_t", 1)
        M.two = ffi.new("uint64_t", 2)
    end
end

local function to_u(n)
    if M.num_bits == 32 then
        return n % M.two^M.num_bits
    end
    return n
end

local function getbit(n, i)
    if M.num_bits == 32 then
        return math.floor(n / M.two^i) % 2
    end
    return (n / M.two^i) % 2
end

function M.band(a, b)
    set_mode(a, b)
    local res = M.zero
    for i = 0, M.num_bits - 1 do
        if getbit(a, i) == M.one and getbit(b, i) == M.one then
            res = res + M.two^i
        end
    end
    return to_u(res)
end

function M.bor(a, b)
    set_mode(a, b)
    local res = M.zero
    for i = 0, M.num_bits - 1 do
        if getbit(a, i) == M.one or getbit(b, i) == M.one then
            res = res + M.two^i
        end
    end
    return to_u(res)
end

function M.bxor(a, b)
    set_mode(a, b)
    local res = M.zero
    for i = 0, M.num_bits - 1 do
        if getbit(a, i) ~= getbit(b, i) then
            res = res + M.two^i
        end
    end
    return to_u(res)
end

function M.bnot(a)
    set_mode(a)
    local res = M.zero
    for i = 0, M.num_bits - 1 do
        if getbit(a, i) == M.zero then
            res = res + M.two^i
        end
    end
    return to_u(res)
end

function M.lshift(a, b)
    set_mode(a, b)
    return to_u(a * M.two^b)
end

function M.rshift(a, b)
    set_mode(a, b)
    if M.num_bits == 32 then
        return math.floor(to_u(a) / M.two^b)
    end
    return to_u(a) / M.two^b
end

function M.rol(a, b)
    set_mode(a, b)
    b = b % M.num_bits
    return to_u(M.lshift(a, b) + M.rshift(a, M.num_bits - b))
end

function M.ror(a, b)
    set_mode(a, b)
    b = b % M.num_bits
    return to_u(M.rshift(a, b) + M.lshift(a, M.num_bits - b))
end

return M
