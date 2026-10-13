local Board = require("piclo/model/board")
local Cell = require("piclo/model/cell")
local Grid = require("piclo/model/grid")
local History = require("piclo/model/history")
local Puzzle = require("piclo/model/puzzle")
local H = require("helpers")

local FILL, CROSS = Board.TOOL_FILL, Board.TOOL_CROSS

local function row(board, r)
    return H.str(Grid.row(board.cells, board.w, r), board.w)
end

describe("planStroke", function()
    local board
    before_each(function()
        board = Board.new(5, 1, H.line("..x#."))
    end)

    it("fills unknown cells and skips crosses", function()
        board:apply(board:planStroke(FILL, { 1, 2, 3 }))
        assert.are.equal("##x#.", row(board, 1))
    end)

    it("fills along a drag that starts on a cross, leaving every X alone", function()
        board = Board.new(6, 1, H.line("x..x.#"))
        board:apply(board:planStroke(FILL, Grid.strokeIndices(6, 1, 1, 1, 6)))
        assert.are.equal("x##x##", row(board, 1))
    end)

    it("clears fills when the stroke starts on a filled cell", function()
        board = Board.new(5, 1, H.line("###x#"))
        board:apply(board:planStroke(FILL, { 2, 3, 4, 5 }))
        assert.are.equal("#..x.", row(board, 1))
    end)

    it("toggles a single tapped cell", function()
        board:apply(board:planStroke(FILL, { 4 }))
        assert.are.equal("..x..", row(board, 1))
    end)

    it("crosses unknown cells only", function()
        board:apply(board:planStroke(CROSS, { 1, 2, 3, 4, 5 }))
        assert.are.equal("xxx#x", row(board, 1))
    end)

    it("clears crosses when starting on a cross", function()
        board = Board.new(4, 1, H.line("xx#x"))
        board:apply(board:planStroke(CROSS, { 1, 2, 3, 4 }))
        assert.are.equal("..#.", row(board, 1))
    end)

    it("returns nil when nothing changes", function()
        assert.is_nil(board:planStroke(FILL, { 3 }))
        assert.is_nil(board:planStroke("pencil", { 1 }))
    end)
end)

describe("compound moves with history", function()
    it("undoes and redoes a whole drag as one step", function()
        local board, history = Board.new(7, 1), History.new()
        local move = board:planStroke(FILL, Grid.strokeIndices(7, 1, 1, 1, 7))
        board:apply(move)
        history:push(move)
        assert.are.equal("#######", row(board, 1))

        board:revert(history:undo())
        assert.are.equal(".......", row(board, 1))
        assert.is_false(history:canUndo())

        board:apply(history:redo())
        assert.are.equal("#######", row(board, 1))
        assert.is_false(history:canRedo())
    end)

    it("reverts changes in reverse order", function()
        local board = Board.new(2, 1)
        local move = { changes = {
            { i = 1, from = Cell.UNKNOWN, to = Cell.FILLED },
            { i = 1, from = Cell.FILLED, to = Cell.CROSSED },
        } }
        board:apply(move)
        assert.are.equal("x.", row(board, 1))
        board:revert(move)
        assert.are.equal("..", row(board, 1))
    end)

    it("applies explicit assignments", function()
        local board = Board.new(3, 1, H.line("#.."))
        local move = board:planSet({ { i = 1, to = Cell.FILLED }, { i = 3, to = Cell.CROSSED } })
        assert.are.equal(1, #move.changes)
        board:apply(move)
        assert.are.equal("#.x", row(board, 1))
    end)
end)

describe("completion and mistakes", function()
    local p = assert(Puzzle.new({ id = "t", rows = { "#.", ".#" } }))

    it("is solved when fills match, whatever the crosses", function()
        assert.is_true(Board.new(2, 2, H.line("#..#")):isSolved(p))
        assert.is_true(Board.new(2, 2, H.line("#xx#")):isSolved(p))
        assert.is_false(Board.new(2, 2, H.line("##.#")):isSolved(p))
        assert.is_false(Board.new(2, 2, H.line("#...")):isSolved(p))
    end)

    it("lists wrong fills and wrong crosses", function()
        local board = Board.new(2, 2, H.line("x#.#"))
        assert.are.same({ 1, 2 }, board:mistakes(p))
        assert.is_true(board:isWrong(p, 2))
        assert.is_false(board:isWrong(p, 3))
    end)

    it("crosses the remaining cells", function()
        local board = Board.new(2, 2, H.line("#..#"))
        board:crossRemaining()
        assert.are.equal("#xx#", H.str(board.cells))
    end)
end)

describe("strokeIndices", function()
    it("snaps to the dominant axis", function()
        assert.are.same({ 1, 2, 3 }, Grid.strokeIndices(5, 1, 1, 2, 3))
        assert.are.same({ 2, 7, 12 }, Grid.strokeIndices(5, 1, 2, 3, 3))
    end)

    it("runs backwards from the start cell", function()
        assert.are.same({ 3, 2, 1 }, Grid.strokeIndices(5, 1, 3, 1, 1))
        assert.are.same({ 11, 6, 1 }, Grid.strokeIndices(5, 3, 1, 1, 1))
    end)

    it("is a single cell for a tap", function()
        assert.are.same({ 7 }, Grid.strokeIndices(5, 2, 2, 2, 2))
    end)
end)
