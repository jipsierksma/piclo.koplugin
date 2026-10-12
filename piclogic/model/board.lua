--[[
Mutable player state: a flat array of cell states plus the rules for turning
a tool stroke into a move.

A move is { changes = { {i = index, from = state, to = state}, ... } } and is
always applied or reverted as a whole, which is what makes a seven-cell drag
a single undo step.
]]

local Cell = require("piclogic/model/cell")

local UNKNOWN, FILLED, CROSSED = Cell.UNKNOWN, Cell.FILLED, Cell.CROSSED

local Board = {}
Board.__index = Board

Board.TOOL_FILL = "fill"
Board.TOOL_CROSS = "cross"

local TOOL_STATE = {
    [Board.TOOL_FILL] = FILLED,
    [Board.TOOL_CROSS] = CROSSED,
}

function Board.new(w, h, cells)
    local self = setmetatable({ w = w, h = h, cells = {} }, Board)
    for i = 1, w * h do
        self.cells[i] = cells and cells[i] or UNKNOWN
    end
    return self
end

function Board:get(r, c)
    return self.cells[(r - 1) * self.w + c]
end

function Board:size()
    return self.w * self.h
end

--[[
Plans a stroke over the given indices. Like the handheld classics, the
stroke's mode comes from its first cell: if that cell already holds the
tool's state the stroke clears that state, otherwise it sets it. Only
unknown cells are ever set, so a fill never paints over a cross and vice
versa. Returns a move, or nil when nothing would change.
]]
function Board:planStroke(tool, indices)
    local target = TOOL_STATE[tool]
    if not target or #indices == 0 then return nil end
    local clearing = self.cells[indices[1]] == target
    local from_state = clearing and target or UNKNOWN
    local to_state = clearing and UNKNOWN or target

    local changes = {}
    for _, i in ipairs(indices) do
        if self.cells[i] == from_state then
            changes[#changes + 1] = { i = i, from = from_state, to = to_state }
        end
    end
    if #changes == 0 then return nil end
    return { changes = changes }
end

--- Builds a move that sets explicit states, e.g. from a hint.
function Board:planSet(assignments)
    local changes = {}
    for _, a in ipairs(assignments) do
        local from = self.cells[a.i]
        if from ~= a.to then
            changes[#changes + 1] = { i = a.i, from = from, to = a.to }
        end
    end
    if #changes == 0 then return nil end
    return { changes = changes }
end

function Board:apply(move)
    for _, ch in ipairs(move.changes) do
        self.cells[ch.i] = ch.to
    end
end

function Board:revert(move)
    local changes = move.changes
    for k = #changes, 1, -1 do
        self.cells[changes[k].i] = changes[k].from
    end
end

--- True when the filled cells exactly match the solution; crosses don't matter.
function Board:isSolved(puzzle)
    local sol = puzzle.solution
    for i = 1, self:size() do
        if (self.cells[i] == FILLED) ~= (sol[i] == FILLED) then
            return false
        end
    end
    return true
end

--- Indices of marks that contradict the solution (wrong fills and wrong crosses).
function Board:mistakes(puzzle)
    local sol, list = puzzle.solution, {}
    for i = 1, self:size() do
        local s = self.cells[i]
        if s ~= UNKNOWN and s ~= sol[i] then
            list[#list + 1] = i
        end
    end
    return list
end

function Board:isWrong(puzzle, i)
    local s = self.cells[i]
    return s ~= UNKNOWN and s ~= puzzle.solution[i]
end

--- Turns every remaining unknown cell into a cross (used on completion).
function Board:crossRemaining()
    for i = 1, self:size() do
        if self.cells[i] == UNKNOWN then
            self.cells[i] = CROSSED
        end
    end
end

function Board:isEmpty()
    for i = 1, self:size() do
        if self.cells[i] ~= UNKNOWN then return false end
    end
    return true
end

return Board
