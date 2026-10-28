--[[
Paints a puzzle picture at a whole-pixel scale: the finished picture in its
reveal tones, or a board in play (its faint grid and the filled cells) as a
thumbnail. Runs of
equal tone in a row become one rect, so even a large reveal is cheap.

Tones are compared as plain numbers and only turned into colors to paint:
KOReader's colors are FFI structs whose == breaks when one side is nil.

In night mode KOReader inverts the whole screen, which would show a drawing
as its negative. Finished pictures are therefore painted on white and
inverted once more, as KOReader does for images in books, so they keep their
real tones, with a narrow white border so black edges don't melt into the
dark screen. Boards in play stay as they are, like the board itself.
]]

local Device = require("device")
local Cell = require("piclo/model/cell")
local Layout = require("piclo/ui/layout")
local Theme = require("piclo/ui/theme")

local Picture = {}

-- Tone of pixel i: nil for empty, else a reveal level 0..4 (0 = black).
local function toneAt(puzzle, opts, i)
    if opts.cells then
        return opts.cells[i] == Cell.FILLED and 0 or nil
    end
    if puzzle.solution[i] ~= Cell.FILLED then return nil end
    return puzzle.shade and puzzle.shade[i] or 0
end

--- A faint empty grid of the puzzle's size, centered in box: the board waiting to be played.
function Picture.grid(bb, puzzle, box)
    local cell, ox, oy = Layout.fitPicture(puzzle.w, puzzle.h, box.w, box.h)
    if cell < 2 then return end
    local x0, y0, hair = box.x + ox, box.y + oy, Theme.line.hair
    for k = 0, puzzle.w do bb:paintRect(x0 + k * cell, y0, hair, puzzle.h * cell, Theme.FAINT) end
    for k = 0, puzzle.h do bb:paintRect(x0, y0 + k * cell, puzzle.w * cell, hair, Theme.FAINT) end
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
    local original = Device.screen.night_mode and not opts.cells
    -- Less than a tile's inner margin, so the border never covers a tile frame.
    local pad = Theme.space.xs
    if original then bb:paintRect(x0 - pad, y0 - pad, w * scale + 2 * pad, h * scale + 2 * pad, Theme.WHITE) end
    if opts.cells then Picture.grid(bb, puzzle, box) end
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
    if original then bb:invertRect(x0 - pad, y0 - pad, w * scale + 2 * pad, h * scale + 2 * pad) end
    return { x = x0, y = y0, w = w * scale, h = h * scale }, scale
end

return Picture
