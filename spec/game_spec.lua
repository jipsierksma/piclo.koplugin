local Cell = require("piclogic/model/cell")
local Game = require("piclogic/game")
local Puzzle = require("piclogic/model/puzzle")
local H = require("helpers")

local P = assert(Puzzle.new({ id = "t", rows = {
    "##.",
    "...",
    "#.#",
} }))

local function newGame(now)
    local t = { now = now or 100 }
    local g = Game.new({ puzzle = P, clock = function() return t.now end })
    return g, t
end

local function keys(set)
    local list = {}
    for k in pairs(set) do list[#list + 1] = k end
    table.sort(list)
    return list
end

describe("strokes", function()
    it("taps with the active tool and reports what changed", function()
        local g = newGame()
        local report = g:tap(1, 1)
        assert.are.same({ 1 }, report.cells)
        assert.are.same({ 1 }, keys(report.rows))
        assert.are.same({ 1 }, keys(report.cols))
        assert.are.equal(Cell.FILLED, g:cell(1, 1))
        g:setTool(Game.TOOL_CROSS)
        g:tap(2, 2)
        assert.are.equal(Cell.CROSSED, g:cell(2, 2))
    end)

    it("toggles a tapped cell back to unknown", function()
        local g = newGame()
        g:tap(1, 1)
        g:tap(1, 1)
        assert.are.equal(Cell.UNKNOWN, g:cell(1, 1))
    end)

    it("returns nil when a tap changes nothing", function()
        local g = newGame()
        g:setTool(Game.TOOL_CROSS)
        g:tap(1, 1)
        g:setTool(Game.TOOL_FILL)
        assert.is_nil(g:tap(1, 1))
        assert.is_false(g:canRedo())
    end)

    it("lays a line as one undo step", function()
        local g = newGame()
        local report = g:stroke(Game.TOOL_CROSS, 2, 1, 2, 3)
        assert.are.equal(3, #report.cells)
        assert.are.same({ 1, 2, 3 }, keys(report.cols))
        g:undo()
        assert.are.equal("...", H.str({ g:cell(2, 1), g:cell(2, 2), g:cell(2, 3) }))
        g:redo()
        assert.are.equal("xxx", H.str({ g:cell(2, 1), g:cell(2, 2), g:cell(2, 3) }))
    end)

    it("knows the other tool", function()
        local g = newGame()
        assert.are.equal(Game.TOOL_CROSS, g:otherTool())
        assert.are.equal(Game.TOOL_FILL, g:otherTool(Game.TOOL_CROSS))
    end)
end)

describe("clue status", function()
    it("updates only the touched lines", function()
        local g = newGame()
        assert.is_false(g.row_done[1])
        assert.is_true(g.row_done[2]) -- an empty line with clue 0 is satisfied
        g:stroke(Game.TOOL_FILL, 1, 1, 1, 2)
        assert.is_true(g.row_done[1])
        assert.are.same({ true }, g.row_nums[1])
        assert.is_false(g.col_done[1])
    end)

    it("follows undo", function()
        local g = newGame()
        g:stroke(Game.TOOL_FILL, 1, 1, 1, 2)
        g:undo()
        assert.is_false(g.row_done[1])
    end)
end)

describe("completion", function()
    local function solve(g)
        g:stroke(Game.TOOL_FILL, 1, 1, 1, 2)
        g:tap(3, 1)
        return g:tap(3, 3)
    end

    it("detects the solve, crosses the rest and locks the board", function()
        local g = newGame()
        local report = solve(g)
        assert.is_true(report.solved)
        assert.is_true(g.solved)
        assert.are.equal(Cell.CROSSED, g:cell(2, 2))
        assert.is_false(g:canUndo())
        assert.is_nil(g:tap(2, 2))
    end)

    it("ignores crosses when checking the picture", function()
        local g = newGame()
        g:setTool(Game.TOOL_CROSS)
        g:tap(1, 3)
        g:setTool(Game.TOOL_FILL)
        assert.is_true(solve(g).solved)
    end)

    it("restarts to an empty board", function()
        local g = newGame()
        solve(g)
        g:restart()
        assert.is_false(g.solved)
        assert.is_true(g.board:isEmpty())
        assert.is_false(g.row_done[1])
    end)
end)

describe("timer", function()
    it("counts only while running and stops on solve", function()
        local g, t = newGame(100)
        g:resume()
        t.now = 130
        assert.are.equal(30, g:elapsed())
        g:pause()
        t.now = 500
        assert.are.equal(30, g:elapsed())
        g:resume()
        t.now = 510
        g:stroke(Game.TOOL_FILL, 1, 1, 1, 2)
        g:tap(3, 1)
        g:tap(3, 3)
        t.now = 900
        assert.are.equal(40, g:elapsed())
        g:resume()
        assert.are.equal(40, g:elapsed())
    end)

    it("starts from saved time", function()
        local t = { now = 0 }
        local g = Game.new({ puzzle = P, elapsed = 75, clock = function() return t.now end })
        g:resume()
        t.now = 5
        assert.are.equal(80, g:elapsed())
    end)
end)
