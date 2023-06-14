local ffi = require("ffi")

ffi.cdef([[
void init_rng();
void set_seed(unsigned long long seed);
unsigned long long get_seed();
int get_int(const int min, const int max);
float get_real(const float min, const float max);
void advance(const float v);
]])

local random = ffi.load("random")
local api = {}
api.init_rng = random.init_rng
api.set_seed = random.set_seed
api.get_seed = function()
    return tonumber(random.get_seed())
end
api.get_int = random.get_int
api.get_real = random.get_real
api.advance = random.advance

return api
