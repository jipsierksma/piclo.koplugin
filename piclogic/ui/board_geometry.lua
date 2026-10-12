--[[
Pure layout math for the board (no KOReader requires, so it is unit tested).

Picks the largest integer cell size at which the clue gutters plus the grid
fit in a rectangle, so every grid line lands on a whole pixel, and maps
between cells and screen pixels.

Grid boundary k (0..n) sits at pixel grid_x + k * cell. Its line is centered
on that pixel: hairline inside 5-blocks, regular every 5 cells, strong at
the outer border. Cell contents sit strictly between the lines.
]]

local Geometry = {}
Geometry.__index = Geometry

local function lineWeight(lines, k, n)
    if k == 0 or k == n then return lines.strong end
    if k % 5 == 0 then return lines.regular end
    return lines.hair
end

local function rowGutter(row_clues, slot_w)
    local widest = 0
    for _, clue in ipairs(row_clues) do
        local w = 0
        for _, n in ipairs(clue) do w = w + slot_w(n) end
        if w > widest then widest = w end
    end
    return widest
end

local function colGutter(col_clues, slot_h)
    local tallest = 0
    for _, clue in ipairs(col_clues) do
        if #clue > tallest then tallest = #clue end
    end
    return tallest * slot_h
end

--[[
spec fields:
  cols, rows            grid size
  row_clues, col_clues  clue lists from the puzzle
  rect                  {x, y, w, h} to fit in
  lines                 {hair, regular, strong} widths in px
  gap                   px between clues and the grid border
  measure(cell)         -> slot_w(n) function and slot_h number for clues
                           rendered at that cell size
  max_cell              optional upper bound for the cell size
Returns a geometry, or nil when not even a 1px cell fits.
]]
function Geometry.fit(spec)
    local rect = spec.rect
    local outer = math.ceil(spec.lines.strong / 2)
    local cell = math.floor(math.min(rect.w / spec.cols, rect.h / spec.rows))
    if spec.max_cell then cell = math.min(cell, spec.max_cell) end

    while cell >= 1 do
        local m = spec.measure(cell)
        local rg = rowGutter(spec.row_clues, m.slot_w)
        local cg = colGutter(spec.col_clues, m.slot_h)
        local total_w = rg + spec.gap + spec.cols * cell + 2 * outer
        local total_h = cg + spec.gap + spec.rows * cell + 2 * outer
        if total_w <= rect.w and total_h <= rect.h then
            local bx = rect.x + math.floor((rect.w - total_w) / 2)
            local by = rect.y + math.floor((rect.h - total_h) / 2)
            return setmetatable({
                cell = cell,
                cols = spec.cols,
                rows = spec.rows,
                lines = spec.lines,
                outer = outer,
                gap = spec.gap,
                measure = m,
                board = { x = bx, y = by, w = total_w, h = total_h },
                grid_x = bx + rg + spec.gap + outer,
                grid_y = by + cg + spec.gap + outer,
                row_gutter = rg,
                col_gutter = cg,
            }, Geometry)
        end
        cell = cell - 1
    end
    return nil
end

--- Pixel x of vertical boundary k, or y of horizontal boundary k.
function Geometry:boundaryX(k) return self.grid_x + k * self.cell end
function Geometry:boundaryY(k) return self.grid_y + k * self.cell end

function Geometry:colLineWeight(k) return lineWeight(self.lines, k, self.cols) end
function Geometry:rowLineWeight(k) return lineWeight(self.lines, k, self.rows) end

--- Rect of the vertical grid line at boundary k (spans the outer border).
function Geometry:vLine(k)
    local lw = self:colLineWeight(k)
    local s = self.lines.strong
    return self:boundaryX(k) - math.floor(lw / 2), self.grid_y - math.floor(s / 2),
        lw, self.rows * self.cell + s
end

--- Rect of the horizontal grid line at boundary k.
function Geometry:hLine(k)
    local lw = self:rowLineWeight(k)
    local s = self.lines.strong
    return self.grid_x - math.floor(s / 2), self:boundaryY(k) - math.floor(lw / 2),
        self.cols * self.cell + s, lw
end

-- First pixel after the line at boundary k, and first pixel of the line at k.
local function spanBetween(origin, cell, w_before, w_after, k)
    local start = origin + (k - 1) * cell - math.floor(w_before / 2) + w_before
    local stop = origin + k * cell - math.floor(w_after / 2)
    return start, stop - start
end

--- Inner rect of a cell: the pixels strictly between its grid lines.
function Geometry:cellInner(r, c)
    local x, w = spanBetween(self.grid_x, self.cell, self:colLineWeight(c - 1), self:colLineWeight(c), c)
    local y, h = spanBetween(self.grid_y, self.cell, self:rowLineWeight(r - 1), self:rowLineWeight(r), r)
    return x, y, w, h
end

--- Outer box of a cell including its share of the lines (for refresh rects).
function Geometry:cellBox(r, c)
    local wl = math.ceil(self:colLineWeight(c - 1) / 2)
    local wr = math.ceil(self:colLineWeight(c) / 2)
    local ht = math.ceil(self:rowLineWeight(r - 1) / 2)
    local hb = math.ceil(self:rowLineWeight(r) / 2)
    return self:boundaryX(c - 1) - wl, self:boundaryY(r - 1) - ht,
        self.cell + wl + wr, self.cell + ht + hb
end

--- Clue area of row r: from the board's left edge up to the grid border.
function Geometry:rowClueRect(r)
    local x = self.board.x
    return x, self:boundaryY(r - 1), self.grid_x - self.outer - x, self.cell
end

--- Clue area of column c: from the board's top edge down to the grid border.
function Geometry:colClueRect(c)
    local y = self.board.y
    return self:boundaryX(c - 1), y, self.cell, self.grid_y - self.outer - y
end

--- Grid rect including the outer border.
function Geometry:gridRect()
    local o = self.outer
    return self.grid_x - o, self.grid_y - o, self.cols * self.cell + 2 * o, self.rows * self.cell + 2 * o
end

--- Cell under a point, or nil outside the grid.
function Geometry:hit(x, y)
    local c = math.floor((x - self.grid_x) / self.cell) + 1
    local r = math.floor((y - self.grid_y) / self.cell) + 1
    if r < 1 or r > self.rows or c < 1 or c > self.cols then return nil end
    return r, c
end

--- Cell under a point, clamped to the grid (for the end of a drag).
function Geometry:hitClamped(x, y)
    local c = math.floor((x - self.grid_x) / self.cell) + 1
    local r = math.floor((y - self.grid_y) / self.cell) + 1
    return math.max(1, math.min(self.rows, r)), math.max(1, math.min(self.cols, c))
end

return Geometry
