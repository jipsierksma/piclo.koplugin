local Cell = require("piclo/model/cell")
local Puzzle = require("piclo/model/puzzle")
local Solver = require("piclo/model/solver")

local function puzzle(rows)
    return assert(Puzzle.new({ id = "t", rows = rows }))
end

local HEART = puzzle({
    ".#.#.",
    "#####",
    "#####",
    ".###.",
    "..#..",
})

describe("validate", function()
    it("accepts a line-solvable picture", function()
        local ok, result = Solver.validate(HEART)
        assert.is_true(ok)
        assert.is_true(result.sweeps >= 1)
        assert.is_true(result.first_sweep_share > 0)
    end)

    it("rejects an ambiguous picture", function()
        -- the diagonal has the same clues as the anti-diagonal
        local ok, result = Solver.validate(puzzle({ "#.", ".#" }))
        assert.is_false(ok)
        assert.is_false(result.solved)
        assert.are.same({ "??", "??" }, Solver.render(puzzle({ "#.", ".#" }), result.cells))
    end)

    it("rejects a picture the line solver cannot start", function()
        -- no single line has a forced cell, so solving would need a guess
        local p = puzzle({
            "#..#",
            ".##.",
            ".##.",
            "#..#",
        })
        local ok = Solver.validate(p)
        assert.is_false(ok)
    end)

    it("handles empty rows and columns", function()
        assert.is_true((Solver.validate(puzzle({ ".....", ".###.", "....." }))))
    end)
end)

describe("hint", function()
    local function blank(p)
        local cells = {}
        for i = 1, p.w * p.h do cells[i] = Cell.UNKNOWN end
        return cells
    end

    it("picks the line with the most deductions", function()
        local h = Solver.hint(HEART, blank(HEART))
        assert.are.equal("row", h.axis)
        assert.are.equal(2, h.index)
        assert.are.equal(5, #h.assignments)
    end)

    it("corrects a wrong mark inside the hinted line", function()
        local cells = blank(HEART)
        cells[6] = Cell.CROSSED -- row 2, col 1 is really filled
        local h = Solver.hint(HEART, cells)
        local fixed = false
        for _, a in ipairs(h.assignments) do
            if a.i == 6 and a.to == Cell.FILLED then fixed = true end
        end
        assert.is_true(fixed)
    end)

    it("returns nil on a finished board", function()
        local cells = {}
        for i, s in ipairs(HEART.solution) do cells[i] = s end
        assert.is_nil(Solver.hint(HEART, cells))
    end)

    it("only proposes changes", function()
        local cells = blank(HEART)
        for i = 6, 10 do cells[i] = Cell.FILLED end
        for i = 11, 15 do cells[i] = Cell.FILLED end
        local h = Solver.hint(HEART, cells)
        for _, a in ipairs(h.assignments) do
            assert.is_true(cells[a.i] ~= a.to)
        end
    end)
end)
