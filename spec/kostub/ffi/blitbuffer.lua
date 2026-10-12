-- 8-bit grayscale pixel buffer with the Blitbuffer methods the plugin uses.
-- Paints that reach outside the buffer are clipped (as in KOReader) and
-- counted in BB.out_of_bounds, so tests can catch layout bugs.
local ffi = require("ffi")

local BB = { out_of_bounds = 0 }

-- Colors are FFI structs whose __eq indexes the other operand, exactly like
-- KOReader's (base/ffi/blitbuffer.lua), so comparing a color with nil
-- crashes here too instead of passing silently.
ffi.cdef("typedef struct { uint8_t a; } PiclogicStubColor8;")
local Color8 = ffi.metatype("PiclogicStubColor8", {
    __index = { getColorRGB32 = function(self) return self end },
    __eq = function(self, color)
        local c = color:getColorRGB32()
        return self.a == c.a
    end,
})
BB.Color8 = Color8
BB.COLOR_WHITE = Color8(0xFF)
BB.COLOR_GRAY_E = Color8(0xEE)
BB.COLOR_GRAY_6 = Color8(0x66)
BB.COLOR_BLACK = Color8(0x00)
BB.TYPE_BB8 = 1

local Buf = {}
Buf.__index = Buf

function BB.new(w, h)
    return setmetatable({ w = w, h = h, data = ffi.new("uint8_t[?]", math.max(1, w * h)) }, Buf)
end

function Buf:getWidth() return self.w end
function Buf:getHeight() return self.h end
function Buf:free() end

function Buf:clip(x, y, w, h)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    if w > 0 and h > 0 and (x < 0 or y < 0 or x + w > self.w or y + h > self.h) then
        BB.out_of_bounds = BB.out_of_bounds + 1
    end
    local x1, y1 = math.max(0, x), math.max(0, y)
    local x2, y2 = math.min(self.w, x + w), math.min(self.h, y + h)
    return x1, y1, x2 - x1, y2 - y1
end

function Buf:get(x, y) return self.data[y * self.w + x] end

function Buf:paintRect(x, y, w, h, c)
    x, y, w, h = self:clip(x, y, w, h)
    for yy = y, y + h - 1 do
        ffi.fill(self.data + yy * self.w + x, w, c.a)
    end
end

function Buf:fill(c) self:paintRect(0, 0, self.w, self.h, c) end

function Buf:invertRect(x, y, w, h)
    x, y, w, h = self:clip(x, y, w, h)
    for yy = y, y + h - 1 do
        for xx = x, x + w - 1 do
            local i = yy * self.w + xx
            self.data[i] = 255 - self.data[i]
        end
    end
end

function Buf:lightenRect(x, y, w, h, by)
    x, y, w, h = self:clip(x, y, w, h)
    for yy = y, y + h - 1 do
        for xx = x, x + w - 1 do
            local i = yy * self.w + xx
            self.data[i] = math.floor(self.data[i] + (255 - self.data[i]) * by + 0.5)
        end
    end
end

function Buf:hatchRect(x, y, w, h, sw, c)
    x, y, w, h = self:clip(x, y, w, h)
    for yy = 0, h - 1 do
        for xx = 0, w - 1 do
            if (xx + yy) % (2 * sw) < sw then self.data[(y + yy) * self.w + x + xx] = c.a end
        end
    end
end

function Buf:paintBorder(x, y, w, h, bw, c)
    self:paintRect(x, y, w, bw, c)
    self:paintRect(x, y + h - bw, w, bw, c)
    self:paintRect(x, y, bw, h, c)
    self:paintRect(x + w - bw, y, bw, h, c)
end

function Buf:paintRoundedRect(x, y, w, h, c, r)
    r = math.min(r or 0, math.floor(h / 2), math.floor(w / 2))
    for yy = 0, h - 1 do
        local dy = math.max(0, r - yy - 1, yy - (h - r))
        local inset = r > 0 and math.floor(r - math.sqrt(math.max(0, r * r - dy * dy))) or 0
        self:paintRect(x + inset, y + yy, w - 2 * inset, 1, c)
    end
end

function Buf:blitFrom(src, dx, dy, ox, oy, w, h)
    for yy = 0, h - 1 do
        for xx = 0, w - 1 do
            local tx, ty = dx + xx, dy + yy
            if tx >= 0 and ty >= 0 and tx < self.w and ty < self.h then
                self.data[ty * self.w + tx] = src.data[(oy + yy) * src.w + ox + xx]
            else
                BB.out_of_bounds = BB.out_of_bounds + 1
            end
        end
    end
end

--- Writes the buffer as a binary PGM image (for eyeballing layouts).
function Buf:writePGM(path)
    local f = assert(io.open(path, "wb"))
    f:write(string.format("P5\n%d %d\n255\n", self.w, self.h))
    f:write(ffi.string(self.data, self.w * self.h))
    f:close()
end

return BB
