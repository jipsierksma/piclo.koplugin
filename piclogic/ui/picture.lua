--[[
Paints a puzzle picture at a whole-pixel scale: the finished picture in its
reveal tones, or a board in play (filled cells only) as a thumbnail. Runs of
equal tone in a row become one rect, so even a large reveal is cheap.

Tones are compared as plain numbers and only turned into colors to paint:
KOReader's colors are FFI structs whose == breaks when one side is nil.
]]

local Cell = require("piclogic/model/cell")
local Layout = require("piclogic/ui/layout")
local Theme = require("piclogic/ui/theme")

local Picture = {}

-- Tone of pixel i: nil for empty, else a reveal level 0..4 (0 = black).
local function toneAt(puzzle, opts, i)
    if opts.cells then
        return opts.cells[i] == Cell.FILLED and 0 or nil
    end
    if puzzle.solution[i] ~= Cell.FILLED then return nil end
    return puzzle.shade and puzzle.shade[i] or 0
end

--[[
Paints into box {x, y, w, h}, centered. opts.cells: a board's cells to draw
instead of the solution. Returns the painted rect and the scale, or nil when
the box is too small.
]]
function Picture.paint(bb, puzzle, box, opts)
    opts = opts or {}
    local w, h = puzzle.w, puzzle.h
    local scale, ox, oy = Layout.fitPicture(w, h, box.w, box.h)
    if scale < 1 then return nil end
    local x0, y0 = box.x + ox, box.y + oy
    for r = 1, h do
        local y = y0 + (r - 1) * scale
        local c = 1
        while c <= w do
            local tone = toneAt(puzzle, opts, (r - 1) * w + c)
            local run = 1
            while c + run <= w and toneAt(puzzle, opts, (r - 1) * w + c + run) == tone do
                run = run + 1
            end
            if tone then
                bb:paintRect(x0 + (c - 1) * scale, y, run * scale, scale, Theme.REVEAL[tone] or Theme.BLACK)
            end
            c = c + run
        end
    end
    return { x = x0, y = y0, w = w * scale, h = h * scale }, scale
end

return Picture
