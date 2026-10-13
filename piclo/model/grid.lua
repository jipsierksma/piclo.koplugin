--[[
Index math for row-major flat grids: line extraction and write-back, and the
cell run covered by a straight drag. Used by puzzle, board and solver.
]]

local Grid = {}

function Grid.index(w, r, c)
    return (r - 1) * w + c
end

function Grid.position(w, i)
    local r = math.floor((i - 1) / w) + 1
    return r, i - (r - 1) * w
end

--- Copies row r of cells into out[1..w] and returns out.
function Grid.row(cells, w, r, out)
    out = out or {}
    local base = (r - 1) * w
    for c = 1, w do
        out[c] = cells[base + c]
    end
    return out
end

--- Copies column c of cells into out[1..h] and returns out.
function Grid.col(cells, w, h, c, out)
    out = out or {}
    for r = 1, h do
        out[r] = cells[(r - 1) * w + c]
    end
    return out
end

--- Flat indices of row r (axis "row") or column c (axis "col").
function Grid.lineIndices(w, h, axis, k)
    local list = {}
    if axis == "row" then
        local base = (k - 1) * w
        for c = 1, w do list[c] = base + c end
    else
        for r = 1, h do list[r] = (r - 1) * w + k end
    end
    return list
end

--[[
Flat indices from (r1, c1) towards (r2, c2), snapped to the dominant axis.
The run starts at the first cell, so callers can take the stroke's mode from
it. Ties go to the row, which is the more common drag direction.
]]
function Grid.strokeIndices(w, r1, c1, r2, c2)
    local list = {}
    local dr, dc = r2 - r1, c2 - c1
    if math.abs(dr) > math.abs(dc) then
        local step = dr > 0 and 1 or -1
        for r = r1, r2, step do
            list[#list + 1] = (r - 1) * w + c1
        end
    else
        local step = dc >= 0 and 1 or -1
        for c = c1, c2, step do
            list[#list + 1] = (r1 - 1) * w + c
        end
    end
    return list
end

return Grid
