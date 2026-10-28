--[[
Where the board goes on a screen of a given size: the header, the toolbar
(bottom in portrait, a rail on the right or left in landscape), the area
left for the board, and the board geometry fitted into it.

This is the one place that decides it. The game screen draws the board here
and the reveal draws the finished picture on the same grid, so the picture
appears exactly where the board was.

When solving the puzzle will unlock a pack, the reveal shows one more line
under its buttons. In portrait the board then leaves room for it: it sits
a little higher, and on some screens a pixel or two smaller per cell.
]]

local RenderText = require("ui/rendertext")
local TextWidget = require("ui/widget/textwidget")
local logger = require("logger")
local Geometry = require("piclo/ui/board_geometry")
local Theme = require("piclo/ui/theme")

local Placement = {}

-- Clue numerals are this share of the cell size (spec: 55-60%).
local CLUE_FONT_RATIO = 0.57
-- Digit metrics are measured once at this size and scaled while fitting.
local REF_PX = 40

local ref_cache = {}

local function refMetrics()
    local cached = ref_cache[Theme.scale]
    if cached then return cached end
    local face = Theme.faceForPx("numeric", REF_PX)
    local adv = {}
    for d = 0, 9 do
        adv[tostring(d)] = RenderText:sizeUtf8Text(0, nil, face, tostring(d)).x
    end
    local ref = { adv = adv, cap = RenderText:sizeUtf8Text(0, nil, face, "0").y_top }
    ref_cache[Theme.scale] = ref
    return ref
end

-- Clue slot sizes for a candidate cell size, from the reference metrics.
local function slotsFor(cell, ref)
    local px = math.max(1, math.floor(cell * CLUE_FONT_RATIO + 0.5))
    local k = px / REF_PX
    local min_w = math.floor(cell * 0.62 + 0.5)
    local pad = math.floor(cell * 0.3 + 0.5)
    local function textW(n)
        local w = 0
        for d in tostring(n):gmatch("%d") do w = w + ref.adv[d] end
        return math.ceil(w * k)
    end
    return {
        px = px,
        slot_w = function(n) return math.max(min_w, textW(n) + pad) end,
        slot_h = math.max(math.floor(cell * 0.62 + 0.5), math.ceil(ref.cap * k) + pad),
    }
end

-- Type size of the reveal's "New pack unlocked" line (the reveal uses it too).
Placement.UNLOCK_SIZE = "caption"

local line_cache = {}

-- Height of the reveal's unlock line.
local function lineHeight()
    local h = line_cache[Theme.scale]
    if not h then
        local w = TextWidget:new{ text = "Ag", face = Theme.face("body", Placement.UNLOCK_SIZE) }
        h = w:getSize().h
        w:free()
        line_cache[Theme.scale] = h
    end
    return h
end

--[[
Height the portrait reveal needs under the picture: its row of buttons and
`lines` extra lines of text, with a margin above and below. The reveal
checks its layout against this too, so both sides agree.
]]
function Placement.revealRoom(lines)
    return Theme.touch + lines * (Theme.space.s + lineHeight()) + 2 * Theme.space.xl
end

local function fit(puzzle, area)
    local ref = refMetrics()
    return Geometry.fit{
        cols = puzzle.w, rows = puzzle.h,
        row_clues = puzzle.row_clues, col_clues = puzzle.col_clues,
        rect = area,
        lines = Theme.line,
        gap = Theme.space.s,
        measure = function(cell) return slotsFor(cell, ref) end,
        max_cell = Theme.max_cell,
    }
end

local function roomBelow(geom, H)
    return H - (geom.grid_y + geom.rows * geom.cell)
end

--[[
Fits the board with `need` pixels free under it, down to the screen's
bottom edge: the least the area has to give up at the bottom, found by
bisection (giving up more only moves the board up or shrinks it). Returns
nil if no amount works.
]]
local function fitWithRoom(puzzle, area, H, need)
    local function try(cut)
        local g = fit(puzzle, { x = area.x, y = area.y, w = area.w, h = area.h - cut })
        return g and roomBelow(g, H) >= need and g or nil
    end
    local lo, hi = 0, math.floor(area.h / 2)
    if not try(hi) then return nil end
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if try(mid) then hi = mid else lo = mid end
    end
    return try(hi)
end

--[[
The screen's frame around the board: { landscape, rail_side, toolbar = rect,
area = rect } with the area the board may use. rail_side is "right"
(default) or "left": where the landscape toolbar goes.
]]
function Placement.frame(W, H, rail_side)
    local top, pad, bar = Theme.header_h, Theme.space.l, Theme.toolbar_h
    local landscape = W > H
    rail_side = rail_side == "left" and "left" or "right"
    local toolbar, area
    if landscape then
        local left = rail_side == "left"
        toolbar = { x = left and 0 or W - bar, y = top, w = bar, h = H - top }
        area = { x = (left and bar or 0) + pad, y = top + pad, w = W - bar - 2 * pad, h = H - top - 2 * pad }
    else
        toolbar = { x = 0, y = H - bar, w = W, h = bar }
        area = { x = pad, y = top + pad, w = W - 2 * pad, h = H - top - bar - 2 * pad }
    end
    return { landscape = landscape, rail_side = rail_side, toolbar = toolbar, area = area }
end

--[[
Returns the frame (see above) plus geom, for a puzzle on a W x H screen.
opts (optional):
  rail_side    as for frame
  unlock_room  leave room for the reveal's unlock line too (portrait only)
  note_h       a practice board: leave this much room under the grid for the
               guide's text; placement.note is then its rect, area-wide
In portrait the board always leaves room under it for the reveal's buttons,
so the picture can land exactly on the grid. Most boards have that room
anyway; a large-celled one (a 7x7 on a tall screen) moves up or shrinks a
little.
geom is nil (and a warning logged) when the board doesn't fit.
]]
function Placement.compute(puzzle, W, H, opts)
    opts = opts or {}
    local placement = Placement.frame(W, H, opts.rail_side)
    local landscape, area = placement.landscape, placement.area
    local geom = fit(puzzle, area)
    local need
    if opts.note_h then
        -- Down to the toolbar in portrait, the screen's edge in landscape.
        need = opts.note_h + 2 * Theme.space.l + (landscape and 0 or Theme.toolbar_h)
    elseif not landscape then
        need = Placement.revealRoom(opts.unlock_room and 1 or 0)
    end
    if geom and need and roomBelow(geom, H) < need then
        geom = fitWithRoom(puzzle, area, H, need) or geom
    end
    if geom and opts.note_h then
        placement.note = { x = area.x, y = geom.grid_y + geom.rows * geom.cell + Theme.space.l,
            w = area.w, h = opts.note_h }
    end
    if not geom then
        logger.warn("piclo: board does not fit in", area.w, "x", area.h)
    elseif geom.cell < Theme.min_cell then
        logger.info("piclo: small cells", geom.cell, "px for", puzzle.id)
    end
    placement.geom = geom
    return placement
end

--- The grid's cells as a picture box {x, y, w, h}, one cell per pixel.
function Placement.pictureBox(geom)
    return { x = geom.grid_x, y = geom.grid_y, w = geom.cols * geom.cell, h = geom.rows * geom.cell }
end

return Placement
