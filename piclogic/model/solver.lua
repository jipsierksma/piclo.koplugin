--[[
Whole-puzzle line solver: repeatedly runs the single-line solver over all
rows and columns until nothing changes.

Uses:
  * build-time validation: a puzzle is valid only when this alone solves it,
    which proves the solution is unique and reachable without guessing;
  * difficulty stats (sweeps needed, share decided by the first sweep);
  * runtime hints, which run one line-solver step from the player's board.
]]

local Cell = require("piclogic/model/cell")
local Grid = require("piclogic/model/grid")
local LineSolve = require("piclogic/model/linesolve")

local UNKNOWN, FILLED = Cell.UNKNOWN, Cell.FILLED

local Solver = {}

local function countKnown(cells, n)
    local known = 0
    for i = 1, n do
        if cells[i] ~= UNKNOWN then known = known + 1 end
    end
    return known
end

-- Solves one line of `cells` in place. Returns the number of newly decided
-- cells, or nil on contradiction.
local function solveLineInPlace(cells, indices, clue, buf)
    local n = #indices
    for p = 1, n do buf[p] = cells[indices[p]] end
    local out, changed = LineSolve.solve(clue, buf, n)
    if not out then return nil end
    if changed > 0 then
        for p = 1, n do cells[indices[p]] = out[p] end
    end
    return changed
end

local function lines(puzzle)
    local list = {}
    for r = 1, puzzle.h do
        list[#list + 1] = { axis = "row", index = r, clue = puzzle.row_clues[r],
            cells = Grid.lineIndices(puzzle.w, puzzle.h, "row", r) }
    end
    for c = 1, puzzle.w do
        list[#list + 1] = { axis = "col", index = c, clue = puzzle.col_clues[c],
            cells = Grid.lineIndices(puzzle.w, puzzle.h, "col", c) }
    end
    return list
end

--[[
Runs the line solver to a fixed point from `start` (or an empty board).
Only clues are used, never the solution. Returns
  { cells, solved, contradiction, sweeps, first_sweep_share }
where sweeps counts full passes that decided something.
]]
function Solver.run(puzzle, start)
    local n = puzzle.w * puzzle.h
    local cells = {}
    for i = 1, n do cells[i] = start and start[i] or UNKNOWN end

    local all, buf = lines(puzzle), {}
    local sweeps, first_share = 0, nil
    repeat
        local progress = false
        for _, line in ipairs(all) do
            local changed = solveLineInPlace(cells, line.cells, line.clue, buf)
            if not changed then
                return { cells = cells, solved = false, contradiction = true,
                    sweeps = sweeps, first_sweep_share = first_share or 0 }
            end
            if changed > 0 then progress = true end
        end
        if progress then sweeps = sweeps + 1 end
        first_share = first_share or countKnown(cells, n) / n
    until not progress

    return {
        cells = cells,
        solved = countKnown(cells, n) == n,
        contradiction = false,
        sweeps = sweeps,
        first_sweep_share = first_share,
    }
end

--- Valid means: line-solvable from nothing, and the result is the picture.
function Solver.validate(puzzle)
    local result = Solver.run(puzzle)
    if not result.solved then
        return false, result
    end
    for i = 1, puzzle.w * puzzle.h do
        if (result.cells[i] == FILLED) ~= (puzzle.solution[i] == FILLED) then
            return false, result
        end
    end
    return true, result
end

--[[
Next teaching step from the player's board. Marks that contradict the
solution are treated as unknown, then the line with the most new deductions
wins (ties: rows before columns, top/left first). Returns one of
  { axis, index, assignments = { {i, to}, ... } }  -- a line deduction
  { mistake = i }                                   -- only errors remain
  nil                                               -- nothing left to do
Assignments may correct wrong cells in that line.
]]
function Solver.hint(puzzle, cells)
    local n = puzzle.w * puzzle.h
    local clean, first_mistake = {}, nil
    for i = 1, n do
        local s = cells[i]
        if s ~= UNKNOWN and s ~= puzzle.solution[i] then
            s = UNKNOWN
            first_mistake = first_mistake or i
        end
        clean[i] = s
    end

    local best, best_count, buf = nil, 0, {}
    for _, line in ipairs(lines(puzzle)) do
        local m = #line.cells
        for p = 1, m do buf[p] = clean[line.cells[p]] end
        local out, changed = LineSolve.solve(line.clue, buf, m)
        if out and changed > best_count then
            best_count = changed
            best = { axis = line.axis, index = line.index, assignments = {} }
            for p = 1, m do
                local i = line.cells[p]
                if out[p] ~= cells[i] and out[p] ~= UNKNOWN then
                    best.assignments[#best.assignments + 1] = { i = i, to = out[p] }
                end
            end
        end
    end
    if best then return best end
    if first_mistake then return { mistake = first_mistake } end
    return nil
end

--- Rows of '#', 'x' and '?' for printing a (stuck) solver state.
function Solver.render(puzzle, cells)
    local glyph = { [UNKNOWN] = "?", [FILLED] = "#", [Cell.CROSSED] = "x" }
    local rows = {}
    for r = 1, puzzle.h do
        local chars = {}
        for c = 1, puzzle.w do
            chars[c] = glyph[cells[Grid.index(puzzle.w, r, c)]]
        end
        rows[r] = table.concat(chars)
    end
    return rows
end

return Solver
