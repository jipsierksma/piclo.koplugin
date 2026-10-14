-- The logo is a solved nonogram: its black squares make a puzzle that line
-- logic solves (tools/logo.py explains what keeps it that way).
local Puzzle = require("piclo/model/puzzle")
local Solver = require("piclo/model/solver")

-- The logo's filled cells, read back from the SVG, as puzzle rows.
local function logoRows()
    local f = assert(io.open("piclo/icons/logo.svg"))
    local src = f:read("*a")
    f:close()
    local w, h = src:match('viewBox="0 0 (%d+) (%d+)"')
    local cell = 40
    local cols, rows = tonumber(w) / cell, tonumber(h) / cell
    local grid = {}
    for r = 1, rows do grid[r] = {} for c = 1, cols do grid[r][c] = "." end end
    local fills = src:match('<path fill="#000000" d="([^"]*)"')
    for x, y in fills:gmatch("M(%d+) (%d+)h") do
        grid[math.floor(y / cell) + 1][math.floor(x / cell) + 1] = "#"
    end
    local out = {}
    for r = 1, rows do out[r] = table.concat(grid[r]) end
    return out
end

describe("logo", function()
    it("is a puzzle that line logic solves", function()
        local rows = logoRows()
        assert.are.equal(24, #rows[1])
        local p = assert(Puzzle.new({ id = "piclo/logo", rows = rows }))
        assert.is_true(Solver.validate(p))
    end)
end)
