--[[
Controller for one puzzle in play. The UI never touches the board directly:
it calls tap/stroke/undo/redo here and gets back a change report listing the
cells and lines to repaint. Also owns the clue "satisfied" cache, the active
tool and the play timer.

Pure Lua: the clock is injected so tests can drive it.
]]

local Board = require("piclogic/model/board")
local Cell = require("piclogic/model/cell")
local Clues = require("piclogic/model/clues")
local Grid = require("piclogic/model/grid")
local History = require("piclogic/model/history")

local Game = {}
Game.__index = Game

Game.TOOL_FILL = Board.TOOL_FILL
Game.TOOL_CROSS = Board.TOOL_CROSS

--[[
opts: puzzle (required), cells (saved board, optional), elapsed (seconds
already played), solved (bool), clock (function returning seconds).
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

-- Applies (or reverts) a move and builds the change report:
-- { cells = {indices}, rows = {r = true}, cols = {c = true}, solved = bool }
function Game:commit(move, reverse)
    if reverse then
        self.board:revert(move)
    else
        self.board:apply(move)
    end
    local report = { cells = {}, rows = {}, cols = {}, solved = false }
    local w = self.puzzle.w
    for _, ch in ipairs(move.changes) do
        report.cells[#report.cells + 1] = ch.i
        local r, c = Grid.position(w, ch.i)
        report.rows[r] = true
        report.cols[c] = true
    end
    for r in pairs(report.rows) do self:refreshRow(r) end
    for c in pairs(report.cols) do self:refreshCol(c) end
    if self.board:isSolved(self.puzzle) then
        self:finish()
        report.solved = true
    end
    return report
end

--[[
Applies `tool` along the straight run from (r1, c1) towards (r2, c2), as
one undoable move. Returns a change report, or nil when nothing changed or
the puzzle is already solved.
]]
function Game:stroke(tool, r1, c1, r2, c2)
    if self.solved then return nil end
    local indices = Grid.strokeIndices(self.puzzle.w, r1, c1, r2 or r1, c2 or c1)
    local move = self.board:planStroke(tool, indices)
    if not move then return nil end
    self.history:push(move)
    return self:commit(move)
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

--- Clears the board and history (the timer keeps running).
function Game:restart()
    self.board = Board.new(self.puzzle.w, self.puzzle.h)
    self.history:clear()
    self.solved = false
    for r = 1, self.puzzle.h do self:refreshRow(r) end
    for c = 1, self.puzzle.w do self:refreshCol(c) end
end

-- Completion: stop the clock and cross out what's left, so a saved board
-- reads as finished.
function Game:finish()
    self:pause()
    self.solved = true
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
