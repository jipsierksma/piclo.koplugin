--[[
Paints the board: clue gutters, cells and grid lines. The geometry comes
from board_placement; the font face, number widths and glyph bitmaps for it
are cached in setGeometry(), and paint methods only draw.

Changes are repainted cell by cell: paintChanges() redraws just the touched
cells and clue strips and returns the rects that need refreshing.

Mistake marks keep what was there: a wrong fill paints hatched, a wrong cross
as a heavy black cross. The line a hint points at gets its clues inverted
(white on black). A hairline in the clue area every 5 lines helps counting
without putting gray numbers on a gray band. All legible without color.
]]

local RenderText = require("ui/rendertext")
local Cell = require("piclo/model/cell")
local Geometry = require("piclo/ui/board_geometry")
local Glyphs = require("piclo/ui/glyphs")
local Grid = require("piclo/model/grid")
local Refresh = require("piclo/ui/refresh")
local Theme = require("piclo/ui/theme")

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

-- Lines 6, 11, ... start a new block of 5 (on grids of 10 or more): their
-- clue strip gets a divider, in line with the grid's block line.
local function startsGroup(k, n)
    return Geometry.blockLine(k - 1, n)
end

function BoardWidget:clueColor(done, focused)
    if focused then return Theme.WHITE end
    return (done and self.highlight_done) and Theme.SECONDARY or Theme.BLACK
end

-- Highlighted: the line a hint points at, or one a practice step is about.
function BoardWidget:focused(axis, k)
    local f = self.game.focus
    if f ~= nil and f.axis == axis and f.index == k then return true end
    return self.guide ~= nil and self.guide[axis][k] == true
end

--[[
Highlights the clues of a practice step's lines ({ row = {[r] = true},
col = {...} }, or nil for none). Returns a change report naming the clue
strips that changed, for changeRects and paintChanges.
]]
function BoardWidget:setGuide(set)
    local report = { cells = {}, rows = {}, cols = {} }
    for __, s in ipairs({ self.guide or {}, set or {} }) do
        for k in pairs(s.row or {}) do report.rows[k] = true end
        for k in pairs(s.col or {}) do report.cols[k] = true end
    end
    self.guide = set
    return report
end

-- Clue strip background: black when hinted, else white.
local function clueBackground(focused)
    return focused and Theme.BLACK or Theme.WHITE
end

function BoardWidget:paintRowClues(bb, r)
    local g = self.geom
    local x, y, w, h = g:rowClueRect(r)
    local focused = self:focused("row", r)
    bb:paintRect(x, y, w, h, clueBackground(focused))
    if startsGroup(r, self.game.puzzle.h) and not focused then
        bb:paintRect(x, y, w, Theme.line.hair, Theme.SECONDARY)
    end
    local clue, done = self.game.puzzle.row_clues[r], self.game.row_nums[r]
    local x_end = g.board.x + g.row_gutter
    local baseline = y + math.floor((h + self.cap_h) / 2)
    for j = #clue, 1, -1 do
        local n = clue[j]
        local sw = g.measure.slot_w(n)
        local sx = x_end - sw
        RenderText:renderUtf8Text(bb, sx + math.floor((sw - self.num_w[n]) / 2), baseline,
            self.face, self.num_s[n], false, false, self:clueColor(done[j], focused))
        x_end = sx
    end
end

function BoardWidget:paintColClues(bb, c)
    local g = self.geom
    local x, y, w, h = g:colClueRect(c)
    local focused = self:focused("col", c)
    bb:paintRect(x, y, w, h, clueBackground(focused))
    if startsGroup(c, self.game.puzzle.w) and not focused then
        bb:paintRect(x, y, Theme.line.hair, h, Theme.SECONDARY)
    end
    local clue, done = self.game.puzzle.col_clues[c], self.game.col_nums[c]
    local sh = g.measure.slot_h
    local y_end = g.board.y + g.col_gutter
    for j = #clue, 1, -1 do
        local n = clue[j]
        local sy = y_end - sh
        RenderText:renderUtf8Text(bb, x + math.floor((w - self.num_w[n]) / 2),
            sy + math.floor((sh + self.cap_h) / 2),
            self.face, self.num_s[n], false, false, self:clueColor(done[j], focused))
        y_end = sy
    end
end

function BoardWidget:paintCell(bb, r, c)
    local ix, iy, iw, ih = self.geom:cellInner(r, c)
    bb:paintRect(ix, iy, iw, ih, Theme.WHITE)
    local s = self.game:cell(r, c)
    local gl = self.glyphs
    local marked = self.game:mark(Grid.index(self.game.puzzle.w, r, c))
    if marked then
        -- A wrong fill stays recognisable as a fill, a wrong cross as a cross.
        local glyph = s == Cell.CROSSED and gl.wrong_cross or gl.mistake
        bb:blitFrom(glyph, ix + math.floor((iw - gl.w) / 2), iy + math.floor((ih - gl.h) / 2),
            0, 0, gl.w, gl.h)
    elseif s == Cell.FILLED then
        local gap = Theme.fill_gap
        bb:paintRect(ix + gap, iy + gap, iw - 2 * gap, ih - 2 * gap, Theme.BLACK)
    elseif s == Cell.CROSSED and self.show_crosses then
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
