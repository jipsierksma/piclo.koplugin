--[[
Where the board goes on a screen of a given size: the header, the toolbar
(bottom in portrait, a rail on the right or left in landscape), the area
left for the board, and the board geometry fitted into it.

This is the one place that decides it. The game screen draws the board here
and the reveal draws the finished picture on the same grid, so the picture
appears exactly where the board was.
]]

local RenderText = require("ui/rendertext")
local logger = require("logger")
local Geometry = require("piclogic/ui/board_geometry")
local Theme = require("piclogic/ui/theme")

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

--[[
Returns { landscape, rail_side, toolbar = rect, area = rect, geom } for a
puzzle on a W x H screen; rail_side ("right" by default, or "left") places
the landscape toolbar. geom is nil (and a warning logged) when the board
doesn't fit.
]]
function Placement.compute(puzzle, W, H, rail_side)
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
    local ref = refMetrics()
    local geom = Geometry.fit{
        cols = puzzle.w, rows = puzzle.h,
        row_clues = puzzle.row_clues, col_clues = puzzle.col_clues,
        rect = area,
        lines = Theme.line,
        gap = Theme.space.s,
        measure = function(cell) return slotsFor(cell, ref) end,
        max_cell = Theme.max_cell,
    }
    if not geom then
        logger.warn("piclogic: board does not fit in", area.w, "x", area.h)
    elseif geom.cell < Theme.min_cell then
        logger.info("piclogic: small cells", geom.cell, "px for", puzzle.id)
    end
    return { landscape = landscape, rail_side = rail_side, toolbar = toolbar, area = area, geom = geom }
end

--- The grid's cells as a picture box {x, y, w, h}, one cell per pixel.
function Placement.pictureBox(geom)
    return { x = geom.grid_x, y = geom.grid_y, w = geom.cols * geom.cell, h = geom.rows * geom.cell }
end

return Placement
