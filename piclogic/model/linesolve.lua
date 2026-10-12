--[[
Complete single-line solver. Given a clue and the known cells of a line, it
finds every cell that is filled in all valid arrangements (must be filled)
or empty in all of them (must be crossed). This is stronger than the
leftmost/rightmost overlap method, which misses some deductions.

Method: a forward table F[j][i] says whether cells 1..i can hold exactly the
first j blocks; a backward table G[j][i] says whether cells i..n can hold
blocks j..k. A cell can be empty if some split puts blocks 1..j before it and
j+1..k after it; it can be filled if some valid placement of a block covers
it. Cost is O(k * n * block) per line, trivial for v1 sizes.
]]

local Cell = require("piclogic/model/cell")

local UNKNOWN, FILLED, CROSSED = Cell.UNKNOWN, Cell.FILLED, Cell.CROSSED

local LineSolve = {}

local function forward(clue, k, n, line, can_fill)
    local F = { [0] = { [0] = true } }
    for i = 1, n do
        F[0][i] = F[0][i - 1] and line[i] ~= FILLED
    end
    for j = 1, k do
        local b, row, prev = clue[j], { [0] = false }, F[j - 1]
        for i = 1, n do
            local v = line[i] ~= FILLED and row[i - 1]
            if not v then
                local s = i - b + 1
                if s >= 1 and can_fill(s, i) then
                    if s == 1 then
                        v = j == 1
                    else
                        v = line[s - 1] ~= FILLED and prev[s - 2]
                    end
                end
            end
            row[i] = v and true or false
        end
        F[j] = row
    end
    return F
end

local function backward(clue, k, n, line, can_fill)
    local G = { [k + 1] = { [n + 1] = true } }
    for i = n, 1, -1 do
        G[k + 1][i] = G[k + 1][i + 1] and line[i] ~= FILLED
    end
    for j = k, 1, -1 do
        local b, row, nxt = clue[j], { [n + 1] = false }, G[j + 1]
        for i = n, 1, -1 do
            local v = line[i] ~= FILLED and row[i + 1]
            if not v then
                local e = i + b - 1
                if e <= n and can_fill(i, e) then
                    if e == n then
                        v = j == k
                    else
                        v = line[e + 1] ~= FILLED and nxt[e + 2]
                    end
                end
            end
            row[i] = v and true or false
        end
        G[j] = row
    end
    return G
end

--[[
Returns a new line with every forced cell decided plus the number of cells
newly decided, or nil when the known cells contradict the clue. Crossed cells
count as known-empty. The input line is not modified.
]]
function LineSolve.solve(clue, line, n)
    local k = clue[1] == 0 and 0 or #clue

    local crossed_before = { [0] = 0 }
    for i = 1, n do
        crossed_before[i] = crossed_before[i - 1] + (line[i] == CROSSED and 1 or 0)
    end
    local function can_fill(s, e)
        return crossed_before[e] == crossed_before[s - 1]
    end

    local F = forward(clue, k, n, line, can_fill)
    if not F[k][n] then
        return nil
    end
    local G = backward(clue, k, n, line, can_fill)

    local may_fill, may_empty = {}, {}
    for c = 1, n do
        if line[c] ~= FILLED then
            for j = 0, k do
                if F[j][c - 1] and G[j + 1][c + 1] then
                    may_empty[c] = true
                    break
                end
            end
        end
    end
    for j = 1, k do
        local b = clue[j]
        for s = 1, n - b + 1 do
            local e = s + b - 1
            if can_fill(s, e) then
                local left_ok
                if s == 1 then
                    left_ok = j == 1
                else
                    left_ok = line[s - 1] ~= FILLED and F[j - 1][s - 2]
                end
                local right_ok
                if e == n then
                    right_ok = j == k
                else
                    right_ok = line[e + 1] ~= FILLED and G[j + 1][e + 2]
                end
                if left_ok and right_ok then
                    for c = s, e do may_fill[c] = true end
                end
            end
        end
    end

    local out, changed = {}, 0
    for c = 1, n do
        local s = line[c]
        if s == UNKNOWN then
            if may_fill[c] and not may_empty[c] then
                s = FILLED
                changed = changed + 1
            elseif may_empty[c] and not may_fill[c] then
                s = CROSSED
                changed = changed + 1
            elseif not may_fill[c] then
                return nil
            end
        end
        out[c] = s
    end
    return out, changed
end

return LineSolve
