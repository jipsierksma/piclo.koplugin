--[[
Paints the board: clue gutters, cells and grid lines. The geometry comes
from board_placement; the font face, number widths and glyph bitmaps for it
are cached in setGeometry(), and paint methods only draw.

Changes are repainted cell by cell: paintChanges() redraws just the touched
cells and clue strips and returns the rects that need refreshing.
]]

local RenderText = require("ui/rendertext")
local Cell = require("piclogic/model/cell")
local Glyphs = require("piclogic/ui/glyphs")
local Grid = require("piclogic/model/grid")
local Refresh = require("piclogic/ui/refresh")
local Theme = require("piclogic/ui/theme")

local BoardWidget = {}
BoardWidget.__index = BoardWidget

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

--- opts: game; show_crosses (default true); highlight_done (default true)
function BoardWidget.new(opts)
    return setmetatable({
        game = opts.game,
        show_crosses = opts.show_crosses ~= false,
        highlight_done = opts.highlight_done ~= false,
    }, BoardWidget)
end

function BoardWidget:free()
    if self.glyphs then
        self.glyphs:free()
        self.glyphs = nil
    end
end

--- Takes the geometry from board_placement and caches what painting needs.
function BoardWidget:setGeometry(g)
    local p = self.game.puzzle
    self.geom = g
    self:free()
    if not g then return end

    self.face = Theme.faceForPx("numeric", g.measure.px)
    self.cap_h = RenderText:sizeUtf8Text(0, nil, self.face, "0").y_top
    self.num_w, self.num_s = {}, {}
    for n = 0, math.max(p.w, p.h) do
        self.num_s[n] = tostring(n)
        self.num_w[n] = RenderText:sizeUtf8Text(0, nil, self.face, self.num_s[n]).x
    end

    -- Inner cell sizes differ by a pixel or two with line weights; size the
    -- glyphs to the smallest and center them.
    local gw, gh = math.huge, math.huge
    for k = 1, math.min(6, p.w, p.h) do
        local _, _, w, h = g:cellInner(k, k)
        gw, gh = math.min(gw, w), math.min(gh, h)
    end
    self.glyphs = Glyphs.new(gw, gh)
end

function BoardWidget:boardRect()
    local b = self.geom.board
    return rect(b.x, b.y, b.w, b.h)
end

-- Every other group of 5 lines gets a light band in the clue area.
local function banded(k)
    return math.floor((k - 1) / 5) % 2 == 1
end

function BoardWidget:clueColor(done)
    return (done and self.highlight_done) and Theme.SECONDARY or Theme.BLACK
end

function BoardWidget:paintRowClues(bb, r)
    local g = self.geom
    local x, y, w, h = g:rowClueRect(r)
    bb:paintRect(x, y, w, h, banded(r) and Theme.TINT or Theme.WHITE)
    local clue, done = self.game.puzzle.row_clues[r], self.game.row_nums[r]
    local x_end = g.board.x + g.row_gutter
    local baseline = y + math.floor((h + self.cap_h) / 2)
    for j = #clue, 1, -1 do
        local n = clue[j]
        local sw = g.measure.slot_w(n)
        local sx = x_end - sw
        RenderText:renderUtf8Text(bb, sx + math.floor((sw - self.num_w[n]) / 2), baseline,
            self.face, self.num_s[n], false, false, self:clueColor(done[j]))
        x_end = sx
    end
end

function BoardWidget:paintColClues(bb, c)
    local g = self.geom
    local x, y, w, h = g:colClueRect(c)
    bb:paintRect(x, y, w, h, banded(c) and Theme.TINT or Theme.WHITE)
    local clue, done = self.game.puzzle.col_clues[c], self.game.col_nums[c]
    local sh = g.measure.slot_h
    local y_end = g.board.y + g.col_gutter
    for j = #clue, 1, -1 do
        local n = clue[j]
        local sy = y_end - sh
        RenderText:renderUtf8Text(bb, x + math.floor((w - self.num_w[n]) / 2),
            sy + math.floor((sh + self.cap_h) / 2),
            self.face, self.num_s[n], false, false, self:clueColor(done[j]))
        y_end = sy
    end
end

function BoardWidget:paintCell(bb, r, c)
    local ix, iy, iw, ih = self.geom:cellInner(r, c)
    bb:paintRect(ix, iy, iw, ih, Theme.WHITE)
    local s = self.game:cell(r, c)
    if s == Cell.FILLED then
        local gap = Theme.fill_gap
        bb:paintRect(ix + gap, iy + gap, iw - 2 * gap, ih - 2 * gap, Theme.BLACK)
    elseif s == Cell.CROSSED and self.show_crosses then
        local gl = self.glyphs
        bb:blitFrom(gl.cross, ix + math.floor((iw - gl.w) / 2), iy + math.floor((ih - gl.h) / 2),
            0, 0, gl.w, gl.h)
    end
end

function BoardWidget:paintLines(bb)
    local g = self.geom
    for k = 0, g.cols do
        local x, y, w, h = g:vLine(k)
        bb:paintRect(x, y, w, h, Theme.BLACK)
    end
    for k = 0, g.rows do
        local x, y, w, h = g:hLine(k)
        bb:paintRect(x, y, w, h, Theme.BLACK)
    end
end

function BoardWidget:paint(bb)
    local g = self.geom
    if not g then return end
    local b = g.board
    bb:paintRect(b.x, b.y, b.w, b.h, Theme.WHITE)
    for r = 1, g.rows do self:paintRowClues(bb, r) end
    for c = 1, g.cols do self:paintColClues(bb, c) end
    for r = 1, g.rows do
        for c = 1, g.cols do self:paintCell(bb, r, c) end
    end
    self:paintLines(bb)
end

--[[
Rects touched by a change report (see Game:commit): the changed cells, and
the clue strips of their rows and columns. Computed before painting so the
caller can hand them to Refresh.
]]
function BoardWidget:changeRects(report)
    local g, w = self.geom, self.game.puzzle.w
    local cells, rows, cols = {}, {}, {}
    for _, i in ipairs(report.cells) do
        local r, c = Grid.position(w, i)
        cells[#cells + 1] = rect(g:cellBox(r, c))
    end
    for r in pairs(report.rows) do rows[#rows + 1] = rect(g:rowClueRect(r)) end
    for c in pairs(report.cols) do cols[#cols + 1] = rect(g:colClueRect(c)) end
    local out = {}
    for _, list in ipairs({ cells, rows, cols }) do
        out[#out + 1] = Refresh.union(list)
    end
    return out
end

--- Repaints the cells and clue strips named in a change report.
function BoardWidget:paintChanges(bb, report)
    local w = self.game.puzzle.w
    for _, i in ipairs(report.cells) do
        self:paintCell(bb, Grid.position(w, i))
    end
    for r in pairs(report.rows) do self:paintRowClues(bb, r) end
    for c in pairs(report.cols) do self:paintColClues(bb, c) end
    -- Lines between cells are untouched by cell painting, so no redraw.
end

--- Inverts one cell's inside (hold feedback); returns its box for refresh.
function BoardWidget:invertCell(bb, r, c)
    local ix, iy, iw, ih = self.geom:cellInner(r, c)
    bb:invertRect(ix, iy, iw, ih)
end

function BoardWidget:cellBox(r, c)
    return rect(self.geom:cellBox(r, c))
end

function BoardWidget:hit(x, y)
    if not self.geom then return nil end
    return self.geom:hit(x, y)
end

function BoardWidget:hitClamped(x, y)
    return self.geom:hitClamped(x, y)
end

return BoardWidget
