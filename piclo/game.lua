--[[
Controller for one puzzle in play. The UI never touches the board directly:
it calls tap/stroke/undo/redo/hint/check here and gets back a change report
listing the cells and lines to repaint. Also owns the clue "satisfied"
cache, the active tool, mistake marks, the line a hint points at and the
play timer.

Mistake modes: "off" (no feedback), "request" (check() marks wrong cells)
and "instant" (a fill stops at the first cell that shouldn't be filled,
which gets a cross and a mark instead).

Marks: "wrong" marks (from check or a hint) stay until their cell changes;
"rejected" marks (instant mode) and the hint line last until the next move.

Pure Lua: the clock is injected so tests can drive it.
]]

local Board = require("piclo/model/board")
local Cell = require("piclo/model/cell")
local Clues = require("piclo/model/clues")
local Grid = require("piclo/model/grid")
local History = require("piclo/model/history")
local Solver = require("piclo/model/solver")

local Game = {}
Game.__index = Game

Game.TOOL_FILL = Board.TOOL_FILL
Game.TOOL_CROSS = Board.TOOL_CROSS

--[[
opts: puzzle (required), cells (saved board, optional), elapsed (seconds
already played), solved (bool), clock (function returning seconds),
mistakes (mode, default "off").
]]
function Game.new(opts)
    local p = opts.puzzle
    local self = setmetatable({
        puzzle = p,
        board = Board.new(p.w, p.h, opts.cells),
        history = History.new(),
        tool = Game.TOOL_FILL,
        clock = opts.clock or os.time,
        elapsed_before = opts.elapsed or 0,
        running_since = nil,
        solved = opts.solved or false,
        mistakes = opts.mistakes or "off",
        marks = {},
        focus = nil,
        row_done = {},
        row_nums = {},
        col_done = {},
        col_nums = {},
        line = {},
    }, Game)
    for r = 1, p.h do self:refreshRow(r) end
    for c = 1, p.w do self:refreshCol(c) end
    return self
end

function Game:refreshRow(r)
    local p = self.puzzle
    Grid.row(self.board.cells, p.w, r, self.line)
    self.row_done[r], self.row_nums[r] = Clues.status(p.row_clues[r], self.line, p.w, self.row_nums[r])
end

function Game:refreshCol(c)
    local p = self.puzzle
    Grid.col(self.board.cells, p.w, p.h, c, self.line)
    self.col_done[c], self.col_nums[c] = Clues.status(p.col_clues[c], self.line, p.h, self.col_nums[c])
end

function Game:otherTool(tool)
    return (tool or self.tool) == Game.TOOL_FILL and Game.TOOL_CROSS or Game.TOOL_FILL
end

function Game:setTool(tool)
    self.tool = tool
end

function Game:cell(r, c)
    return self.board:get(r, c)
end

function Game:setMistakeMode(mode)
    self.mistakes = mode
end

--- Mark on cell i: nil, "wrong" or "rejected".
function Game:mark(i)
    return self.marks[i]
end

-- Change report: { cells = {indices}, rows = {r = true}, cols = {c = true},
-- solved = bool }, plus hint/mistakes from hint() and check().
local function newReport()
    return { cells = {}, rows = {}, cols = {}, solved = false, seen = {} }
end

-- Adds cell i to a report; with `lines`, its row and column clues too.
function Game:addCell(report, i, lines)
    if not report.seen[i] then
        report.seen[i] = true
        report.cells[#report.cells + 1] = i
    end
    if lines then
        local r, c = Grid.position(self.puzzle.w, i)
        report.rows[r] = true
        report.cols[c] = true
    end
end

-- Drops what only lasts until the next action: rejected marks and the hint line.
function Game:clearTransient(report)
    for i, kind in pairs(self.marks) do
        if kind == "rejected" then
            self.marks[i] = nil
            self:addCell(report, i)
        end
    end
    local f = self.focus
    if f then
        if f.axis == "row" then report.rows[f.index] = true else report.cols[f.index] = true end
        self.focus = nil
    end
end

-- Applies (or reverts) a move and builds its change report.
function Game:commit(move, reverse)
    if reverse then
        self.board:revert(move)
    else
        self.board:apply(move)
    end
    local report = newReport()
    self:clearTransient(report)
    for _, ch in ipairs(move.changes) do
        self.marks[ch.i] = nil
        self:addCell(report, ch.i, true)
    end
    for r in pairs(report.rows) do self:refreshRow(r) end
    for c in pairs(report.cols) do self:refreshCol(c) end
    if self.board:isSolved(self.puzzle) then
        self:finish()
        report.solved = true
    end
    return report
end

-- Instant checking: cuts a fill short at the first cell that shouldn't be
-- filled, which becomes a cross instead. Returns the move and that cell.
function Game:screenFill(move)
    local sol = self.puzzle.solution
    for k, ch in ipairs(move.changes) do
        if ch.to == Cell.FILLED and sol[ch.i] ~= Cell.FILLED then
            local kept = {}
            for j = 1, k - 1 do kept[j] = move.changes[j] end
            kept[k] = { i = ch.i, from = ch.from, to = Cell.CROSSED }
            return { changes = kept }, ch.i
        end
    end
    return move
end

--[[
Applies `tool` along the straight run from (r1, c1) towards (r2, c2), as
one undoable move. Returns a change report, or nil when nothing changed or
the puzzle is already solved. In instant mode report.rejected names a fill
that was turned away.
]]
function Game:stroke(tool, r1, c1, r2, c2)
    if self.solved then return nil end
    local indices = Grid.strokeIndices(self.puzzle.w, r1, c1, r2 or r1, c2 or c1)
    local move = self.board:planStroke(tool, indices)
    if not move then return nil end
    local rejected
    if self.mistakes == "instant" then move, rejected = self:screenFill(move) end
    self.history:push(move)
    local report = self:commit(move)
    if rejected and not report.solved then
        self.marks[rejected] = "rejected"
        report.rejected = rejected
    end
    return report
end

function Game:tap(r, c)
    return self:stroke(self.tool, r, c)
end

function Game:canUndo()
    return not self.solved and self.history:canUndo()
end

function Game:canRedo()
    return not self.solved and self.history:canRedo()
end

function Game:undo()
    if not self:canUndo() then return nil end
    return self:commit(self.history:undo(), true)
end

function Game:redo()
    if not self:canRedo() then return nil end
    return self:commit(self.history:redo())
end

--[[
Marks every cell that contradicts the solution (the Check action). The
report lists the marked cells; report.mistakes is how many there are.
]]
function Game:check()
    local report = newReport()
    self:clearTransient(report)
    local list = self.board:mistakes(self.puzzle)
    for _, i in ipairs(list) do
        self.marks[i] = "wrong"
        self:addCell(report, i)
    end
    report.mistakes = #list
    return report
end

--[[
One teaching step from the line solver, as one undoable move that also
corrects wrong cells in that line. The line stays highlighted (game.focus)
until the next action. When only mistakes block progress, marks the first
one instead. report.hint is "line" or "mistake"; nil when there is nothing
to hint.
]]
function Game:hint()
    if self.solved then return nil end
    local h = Solver.hint(self.puzzle, self.board.cells)
    if not h then return nil end
    if h.mistake then
        local report = newReport()
        self:clearTransient(report)
        self.marks[h.mistake] = "wrong"
        self:addCell(report, h.mistake)
        report.hint = "mistake"
        return report
    end
    local move = self.board:planSet(h.assignments)
    if not move then return nil end
    self.history:push(move)
    local report = self:commit(move)
    report.hint = "line"
    if not report.solved then
        self.focus = { axis = h.axis, index = h.index }
        if h.axis == "row" then report.rows[h.index] = true else report.cols[h.index] = true end
    end
    return report
end

--- Clears the board, history, marks and time for a fresh attempt.
function Game:restart()
    self.board = Board.new(self.puzzle.w, self.puzzle.h)
    self.history:clear()
    self.solved = false
    self.marks, self.focus = {}, nil
    self.elapsed_before = 0
    if self.running_since then self.running_since = self.clock() end
    for r = 1, self.puzzle.h do self:refreshRow(r) end
    for c = 1, self.puzzle.w do self:refreshCol(c) end
end

-- Completion: stop the clock and cross out what's left, so a saved board
-- reads as finished.
function Game:finish()
    self:pause()
    self.solved = true
    self.marks, self.focus = {}, nil
    self.board:crossRemaining()
    self.history:clear()
end

function Game:isFilled(i)
    return self.board.cells[i] == Cell.FILLED
end

-- Timer ----------------------------------------------------------------

function Game:resume()
    if not self.solved and not self.running_since then
        self.running_since = self.clock()
    end
end

function Game:pause()
    if self.running_since then
        self.elapsed_before = self.elapsed_before + (self.clock() - self.running_since)
        self.running_since = nil
    end
end

function Game:elapsed()
    local running = self.running_since and (self.clock() - self.running_since) or 0
    return self.elapsed_before + running
end

return Game
