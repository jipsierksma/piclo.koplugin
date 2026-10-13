local Cell = require("piclo/model/cell")
local Game = require("piclo/game")
local Puzzle = require("piclo/model/puzzle")
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

describe("mistakes", function()
    local function instantGame()
        local g = newGame()
        g:setMistakeMode("instant")
        return g
    end

    it("stops an instant fill at the first wrong cell and crosses it", function()
        local g = instantGame()
        -- row 1 is "##.": the drag fills two cells, the third is turned away
        local report = g:stroke(Game.TOOL_FILL, 1, 1, 1, 3)
        assert.are.equal(Cell.FILLED, g:cell(1, 1))
        assert.are.equal(Cell.FILLED, g:cell(1, 2))
        assert.are.equal(Cell.CROSSED, g:cell(1, 3))
        assert.are.equal(3, report.rejected)
        assert.are.equal("rejected", g:mark(3))
    end)

    it("drops a rejected mark on the next move, and undoes as one step", function()
        local g = instantGame()
        g:tap(2, 2)
        assert.are.equal("rejected", g:mark(5))
        local report = g:tap(1, 1)
        assert.is_nil(g:mark(5))
        assert.truthy(report.seen[5])
        g:undo()
        g:undo()
        assert.are.equal(Cell.UNKNOWN, g:cell(2, 2))
    end)

    it("lets wrong fills through when checking is off or on request", function()
        for _, mode in ipairs({ "off", "request" }) do
            local g = newGame()
            g:setMistakeMode(mode)
            g:tap(2, 2)
            assert.are.equal(Cell.FILLED, g:cell(2, 2))
        end
    end)

    it("marks wrong fills and wrong crosses on check, until the cell changes", function()
        local g = newGame()
        g:tap(2, 2)
        g:setTool(Game.TOOL_CROSS)
        g:tap(1, 1)
        local report = g:check()
        assert.are.equal(2, report.mistakes)
        assert.are.same({ 1, 5 }, (function() local l = { unpack(report.cells) } table.sort(l) return l end)())
        assert.are.equal("wrong", g:mark(5))
        g:tap(3, 2)
        assert.are.equal("wrong", g:mark(5))
        g:setTool(Game.TOOL_FILL)
        g:tap(2, 2)
        assert.is_nil(g:mark(5))
    end)

    it("reports no mistakes on a clean board", function()
        local g = newGame()
        g:tap(1, 1)
        assert.are.equal(0, g:check().mistakes)
    end)
end)

describe("hints", function()
    it("deduces one line as one undoable move and highlights it", function()
        local g = newGame()
        local report = g:hint()
        assert.are.equal("line", report.hint)
        assert.truthy(g.focus)
        local line = g.focus
        assert.is_true(#report.cells > 0)
        if line.axis == "row" then
            assert.is_true(report.rows[line.index])
        else
            assert.is_true(report.cols[line.index])
        end
        g:undo()
        assert.is_true(g.board:isEmpty())
        assert.is_nil(g.focus)
    end)

    it("corrects wrong cells in the hinted line", function()
        local g = newGame()
        g:tap(2, 2) -- wrong
        local report
        repeat report = g:hint() until not report or report.solved or g:cell(2, 2) ~= Cell.FILLED
        assert.is_true(g:cell(2, 2) ~= Cell.FILLED)
    end)

    it("solves a puzzle by hints alone", function()
        local g = newGame()
        local report, steps = nil, 0
        repeat
            report = g:hint()
            steps = steps + 1
        until not report or report.solved or steps > 20
        assert.is_true(g.solved)
    end)

    it("fixes a wrong cross when everything else is done", function()
        local g = newGame()
        for _, rc in ipairs({ { 1, 1 }, { 1, 2 }, { 3, 1 } }) do g:tap(rc[1], rc[2]) end
        g:setTool(Game.TOOL_CROSS)
        for _, rc in ipairs({ { 1, 3 }, { 2, 1 }, { 2, 2 }, { 2, 3 }, { 3, 2 }, { 3, 3 } }) do g:tap(rc[1], rc[2]) end
        local report = g:hint()
        assert.are.equal("line", report.hint)
        assert.is_true(report.solved)
        assert.are.equal(Cell.FILLED, g:cell(3, 3))
    end)
end)

describe("restart", function()
    it("clears marks and the time", function()
        local g, t = newGame(100)
        g:resume()
        g:tap(2, 2)
        g:check()
        t.now = 160
        g:restart()
        assert.is_nil(g:mark(5))
        assert.are.equal(0, g:elapsed())
        t.now = 170
        assert.are.equal(10, g:elapsed())
    end)
end)
