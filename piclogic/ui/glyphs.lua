--[[
Small per-layout bitmaps for cell contents that Blitbuffer can't draw
directly (it has no line primitive): the cross and the mistake hatch.
Built once for the current cell size and blitted into each cell, so
paintTo never computes geometry per cell.
]]

local Blitbuffer = require("ffi/blitbuffer")
local Theme = require("piclogic/ui/theme")

local Glyphs = {}
Glyphs.__index = Glyphs

-- Draws a diagonal stroke of thickness t across bb from one corner of the
-- square [x0, x0 + n) to the opposite one, one short rect per scanline.
local function diagonal(bb, x0, y0, n, t, color, anti)
    for k = 0, n - 1 do
        local cx = anti and (x0 + n - 1 - k) or (x0 + k)
        bb:paintRect(cx - math.floor(t / 2), y0 + k, t, 1, color)
    end
end

--- Builds glyphs for cells whose inner area is w x h pixels.
function Glyphs.new(w, h)
    local self = setmetatable({ w = w, h = h }, Glyphs)

    -- Cross: a thin X in secondary gray, inset about 25%.
    local cross = Blitbuffer.new(w, h, Blitbuffer.TYPE_BB8)
    cross:fill(Theme.WHITE)
    local side = math.min(w, h)
    local inset = math.floor(side / 4)
    local n = side - 2 * inset
    local t = math.max(1, math.floor(Theme.line.regular * 0.75))
    local x0 = math.floor((w - n) / 2)
    local y0 = math.floor((h - n) / 2)
    diagonal(cross, x0, y0, n, t, Theme.SECONDARY, false)
    diagonal(cross, x0, y0, n, t, Theme.SECONDARY, true)
    self.cross = cross

    -- Mistake: a hatched fill, readable without color.
    local gap = Theme.fill_gap
    local mistake = Blitbuffer.new(w, h, Blitbuffer.TYPE_BB8)
    mistake:fill(Theme.WHITE)
    mistake:hatchRect(gap, gap, w - 2 * gap, h - 2 * gap, math.max(2, Theme.line.regular), Theme.BLACK)
    self.mistake = mistake

    return self
end

function Glyphs:free()
    self.cross:free()
    self.mistake:free()
end

return Glyphs
