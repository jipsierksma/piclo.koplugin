--[[
Clue derivation and "satisfied" status for a single line.

A line is an array of cell states (model/cell). A clue is the list of filled
run lengths; an empty line has the clue {0}.

Satisfied status only looks at the player's own marks, never the solution,
so greying out numbers can't leak the answer:
  * the whole line is satisfied when its filled runs equal the clue;
  * a single number is satisfied when, reading from either end, every cell
    up to and including its run is decided, the run is closed off by crosses
    or the grid edge, and its length matches.
]]

local Cell = require("piclo/model/cell")

local FILLED, CROSSED, UNKNOWN = Cell.FILLED, Cell.CROSSED, Cell.UNKNOWN

local Clues = {}

function Clues.derive(line, n)
    local clue, run = {}, 0
    for i = 1, n do
        if line[i] == FILLED then
            run = run + 1
        elseif run > 0 then
            clue[#clue + 1] = run
            run = 0
        end
    end
    if run > 0 then
        clue[#clue + 1] = run
    end
    if #clue == 0 then
        clue[1] = 0
    end
    return clue
end

local function sameRuns(a, b)
    if #a ~= #b then return false end
    for j = 1, #a do
        if a[j] ~= b[j] then return false end
    end
    return true
end

-- Matches runs from the left. Returns how many clue numbers matched and the
-- last cell index the scan consumed.
local function scanLeft(clue, line, n, done)
    local j, i, consumed = 1, 1, 0
    while i <= n and j <= #clue do
        local s = line[i]
        if s == CROSSED then
            consumed = i
            i = i + 1
        elseif s == UNKNOWN then
            break
        else
            local e = i
            while e < n and line[e + 1] == FILLED do e = e + 1 end
            if e < n and line[e + 1] ~= CROSSED then break end
            if e - i + 1 ~= clue[j] then break end
            done[j] = true
            j = j + 1
            consumed = e
            i = e + 1
        end
    end
    return j - 1, consumed
end

-- Mirror of scanLeft that stops before cells the left scan already claimed,
-- so one physical run is never matched to two clue numbers.
local function scanRight(clue, line, n, done, matched_left, left_consumed)
    local j, i = #clue, n
    while i > left_consumed and j > matched_left do
        local s = line[i]
        if s == CROSSED then
            i = i - 1
        elseif s == UNKNOWN then
            return
        else
            local b = i
            while b > 1 and line[b - 1] == FILLED do b = b - 1 end
            if b > 1 and line[b - 1] ~= CROSSED then return end
            if i - b + 1 ~= clue[j] then return end
            done[j] = true
            j = j - 1
            i = b - 1
        end
    end
end

--[[
Returns line_satisfied, done where done[j] tells whether clue number j is
satisfied. Pass `done` to reuse a table and avoid allocation.
]]
function Clues.status(clue, line, n, done)
    done = done or {}
    for j = 1, #clue do done[j] = false end
    for j = #clue + 1, #done do done[j] = nil end

    local runs = Clues.derive(line, n)
    if sameRuns(runs, clue) then
        for j = 1, #clue do done[j] = true end
        return true, done
    end
    -- More runs than numbers (or any run on a 0 line): something is wrong,
    -- so marking individual numbers done would mislead.
    if clue[1] == 0 or (runs[1] ~= 0 and #runs > #clue) then
        return false, done
    end

    local matched, consumed = scanLeft(clue, line, n, done)
    scanRight(clue, line, n, done, matched, consumed)
    return false, done
end

return Clues
