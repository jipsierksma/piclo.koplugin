local Geometry = require("piclogic/ui/board_geometry")

local LINES = { hair = 1, regular = 2, strong = 4 }

-- Clue slots scale with the cell: half a cell wide per digit, 0.6 cell tall.
local function measure(cell)
    return {
        slot_w = function(n) return math.ceil(#tostring(n) * cell / 2) end,
        slot_h = math.ceil(cell * 0.6),
    }
end

local function fit(cols, rows, w, h, extra)
    local row_clues, col_clues = {}, {}
    for r = 1, rows do row_clues[r] = { 1, 1 } end
    for c = 1, cols do col_clues[c] = { 1, 1, 1 } end
    local spec = {
        cols = cols, rows = rows,
        row_clues = row_clues, col_clues = col_clues,
        rect = { x = 10, y = 20, w = w, h = h },
        lines = LINES, gap = 3, measure = measure,
    }
    for k, v in pairs(extra or {}) do spec[k] = v end
    return Geometry.fit(spec)
end

describe("fit", function()
    it("picks the largest cell that fits clues and grid", function()
        local g = fit(10, 10, 600, 800)
        -- width: gutter 2*ceil(c/2) + 3 + 10c + 4 <= 600 -> c = 53
        assert.are.equal(53, g.cell)
        assert.is_true(g.board.w <= 600)
        local g2 = fit(10, 10, 600, 800)
        assert.are.equal(g.cell, g2.cell)
    end)

    it("fits a 15x15 board on a 6 inch portrait screen", function()
        local g = fit(15, 15, 1072, 1200)
        assert.is_true(g.cell >= 28)
        assert.is_true(g.board.w <= 1072 and g.board.h <= 1200)
    end)

    it("centers the grid itself when the clues leave room", function()
        local g = fit(5, 5, 600, 800, { max_cell = 40 })
        local left = g.grid_x - 10
        local right = 10 + 600 - (g.grid_x + 5 * g.cell)
        assert.is_true(math.abs(left - right) <= 1)
        assert.is_true(g.board.x >= 10)
    end)

    it("shifts the grid only as far as the clues allow", function()
        local g = fit(10, 10, 600, 800)
        assert.is_true(g.board.x >= 10)
        assert.is_true(g.board.x + g.board.w <= 610)
        assert.are.equal(g.board.x + g.row_gutter + 3 + 2, g.grid_x)
    end)

    it("centers the whole board vertically", function()
        local g = fit(5, 5, 600, 800)
        local top = g.board.y - 20
        local bottom = 20 + 800 - (g.board.y + g.board.h)
        assert.is_true(math.abs(top - bottom) <= 1)
    end)

    it("respects max_cell", function()
        assert.are.equal(40, fit(5, 5, 600, 800, { max_cell = 40 }).cell)
    end)

    it("returns nil when nothing fits", function()
        assert.is_nil(fit(10, 10, 5, 5))
    end)
end)

describe("lines and cells", function()
    local g = fit(10, 10, 600, 800)

    it("weights lines by position", function()
        assert.are.equal(4, g:colLineWeight(0))
        assert.are.equal(1, g:colLineWeight(3))
        assert.are.equal(2, g:colLineWeight(5))
        assert.are.equal(4, g:colLineWeight(10))
    end)

    it("keeps cell insides between their lines", function()
        for c = 1, 10 do
            local x, _, w = g:cellInner(1, c)
            local lx, _, lw = g:vLine(c - 1)
            local rx = g:vLine(c)
            assert.are.equal(lx + lw, x)
            assert.are.equal(rx, x + w)
        end
    end)

    it("tiles the grid with no gaps or overlaps", function()
        local covered = 0
        for k = 0, 10 do
            local _, _, lw = g:vLine(k)
            covered = covered + lw
        end
        for c = 1, 10 do
            local _, _, w = g:cellInner(1, c)
            covered = covered + w
        end
        local _, _, gw = g:gridRect()
        assert.are.equal(gw, covered)
    end)

    it("boxes a cell including its lines", function()
        local x, y, w, h = g:cellBox(1, 1)
        local ix, iy, iw, ih = g:cellInner(1, 1)
        assert.is_true(x < ix and y < iy)
        assert.is_true(x + w > ix + iw and y + h > iy + ih)
    end)
end)

describe("hit testing", function()
    local g = fit(10, 10, 600, 800)

    it("maps points to cells", function()
        assert.are.same({ 1, 1 }, { g:hit(g.grid_x, g.grid_y) })
        assert.are.same({ 2, 3 }, { g:hit(g.grid_x + 2 * g.cell + 1, g.grid_y + g.cell) })
        assert.are.same({ 10, 10 }, { g:hit(g.grid_x + 10 * g.cell - 1, g.grid_y + 10 * g.cell - 1) })
    end)

    it("misses outside the grid", function()
        assert.is_nil(g:hit(g.grid_x - 1, g.grid_y))
        assert.is_nil(g:hit(g.grid_x, g.grid_y + 10 * g.cell))
    end)

    it("clamps drag ends to the grid", function()
        assert.are.same({ 1, 10 }, { g:hitClamped(9999, -50) })
        assert.are.same({ 10, 1 }, { g:hitClamped(-5, 9999) })
    end)
end)

describe("clue areas", function()
    local g = fit(10, 10, 600, 800)

    it("puts row clues left of the grid and column clues above", function()
        local x, y, w, h = g:rowClueRect(3)
        assert.are.equal(g.board.x, x)
        assert.are.equal(g:boundaryY(2), y)
        assert.are.equal(g.cell, h)
        assert.is_true(x + w <= g.grid_x)
        local cx, cy, cw, ch = g:colClueRect(4)
        assert.are.equal(g:boundaryX(3), cx)
        assert.are.equal(g.board.y, cy)
        assert.are.equal(g.cell, cw)
        assert.is_true(cy + ch <= g.grid_y)
    end)
end)
