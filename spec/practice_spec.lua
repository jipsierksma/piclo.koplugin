local Cell = require("piclo/model/cell")
local Coach = require("piclo/coach")
local Grid = require("piclo/model/grid")
local LineSolve = require("piclo/model/linesolve")
local Solver = require("piclo/model/solver")

local lessons = Coach.load("piclo/data/practice.lua")

local function blank(p)
    local cells = {}
    for i = 1, p.w * p.h do cells[i] = Cell.UNKNOWN end
    return cells
end

-- What line logic alone decides for cell i from the step's lines.
local function deduced(p, step, cells, i)
    for __, line in ipairs(step.lines) do
        local idx = Grid.lineIndices(p.w, p.h, line[1], line[2])
        local clue = line[1] == "row" and p.row_clues[line[2]] or p.col_clues[line[2]]
        local buf = {}
        for k, j in ipairs(idx) do buf[k] = cells[j] end
        local out = LineSolve.solve(clue, buf, #idx)
        for k, j in ipairs(idx) do
            if j == i and out and out[k] ~= Cell.UNKNOWN then return out[k] end
        end
    end
end

describe("practice", function()
    it("has two lessons", function()
        assert.are.equal(2, #lessons)
    end)

    for n, lesson in ipairs(lessons) do
        it("lesson " .. n .. ": every step follows from its lines and the steps before", function()
            local coach, p = Coach.new(lesson), lesson.puzzle
            local cells = blank(p)
            for s, step in ipairs(lesson.steps) do
                assert.are.equal(s, coach.step)
                if step.solve then
                    assert.are.equal(#lesson.steps, s, "solve is the last step")
                    assert.is_true(Solver.run(p, cells).solved, "the rest follows by line logic")
                else
                    local want = coach:required(s)
                    assert.is_true(#want > 0)
                    assert.is_false(coach:stepDone(s, cells), "step " .. s .. " asks for something new")
                    for __, w in ipairs(want) do
                        assert.are.equal(w[2], deduced(p, step, cells, w[1]), "step " .. s .. " cell " .. w[1])
                    end
                    for __, w in ipairs(want) do cells[w[1]] = w[2] end
                    assert.is_true(coach:update(cells))
                end
            end
        end)
    end

    it("skips steps the player already did and spots squares against the picture", function()
        local coach = Coach.new(lessons[1])
        local p = coach.puzzle
        local cells = blank(p)
        -- Rows 1, 3 and 5 at once: the first two steps are done.
        for __, r in ipairs({ 1, 3, 5 }) do
            for c = 1, 5 do cells[Grid.index(p.w, r, c)] = Cell.FILLED end
        end
        coach:update(cells)
        assert.are.equal(3, coach.step)
        assert.is_true(coach:lines().row[2])
        assert.is_false(coach:hasMistake(cells))
        cells[Grid.index(p.w, 2, 2)] = Cell.FILLED
        assert.is_true(coach:hasMistake(cells))
        cells[Grid.index(p.w, 2, 2)] = Cell.CROSSED
        cells[Grid.index(p.w, 2, 1)] = Cell.CROSSED
        assert.is_true(coach:hasMistake(cells), "a cross on a picture square")
    end)

    it("fails soft on a missing file", function()
        assert.are.same({}, Coach.load("no/such/file.lua"))
    end)
end)
