-- The logo on the home screen and the logo puzzle are one picture.
local Puzzle = require("piclo/model/puzzle")
local Solver = require("piclo/model/solver")

local rows = dofile("piclo/data/logo.lua")

-- Filled cells drawn in the wordmark SVG, as "r,c" keys.
local function svgCells()
    local f = assert(io.open("piclo/icons/wordmark.svg"))
    local src = f:read("*a")
    f:close()
    local width = tonumber(src:match('viewBox="0 0 (%d+) %d+"'))
    local cell = width / #rows[1]
    local fills = src:match('<path fill="#000000" d="([^"]*)"')
    local cells = {}
    for x, y in fills:gmatch("M(%d+) (%d+)h") do
        cells[math.floor(y / cell) + 1 .. "," .. math.floor(x / cell) + 1] = true
    end
    return cells
end

describe("logo", function()
    it("is a valid puzzle the line solver finishes", function()
        local p = assert(Puzzle.new({ id = "piclo/logo", rows = rows }))
        assert.is_true(p.w <= 15 and p.h <= 15)
        assert.is_true(Solver.validate(p))
    end)

    it("matches the wordmark drawn on the home screen", function()
        local want = {}
        for r, row in ipairs(rows) do
            for c = 1, #row do
                if row:sub(c, c) == "#" then want[r .. "," .. c] = true end
            end
        end
        assert.are.same(want, svgCells())
    end)
end)
