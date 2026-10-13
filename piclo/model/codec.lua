--[[
Compact string form of a board for storage: a format version, a colon, then
run-length encoded cells. Each run is an optional decimal count followed by
'.' (unknown), '#' (filled) or 'x' (crossed). Example: "1:12.#3x".
]]

local Cell = require("piclo/model/cell")

local Codec = {}

Codec.VERSION = "1"

local TO_CHAR = {
    [Cell.UNKNOWN] = ".",
    [Cell.FILLED] = "#",
    [Cell.CROSSED] = "x",
}
local FROM_CHAR = {
    ["."] = Cell.UNKNOWN,
    ["#"] = Cell.FILLED,
    ["x"] = Cell.CROSSED,
}

local function emit(parts, count, ch)
    parts[#parts + 1] = (count > 1 and tostring(count) or "") .. ch
end

function Codec.encode(cells, n)
    local parts = { Codec.VERSION, ":" }
    local prev, count = nil, 0
    for i = 1, n do
        local ch = TO_CHAR[cells[i]] or "."
        if ch == prev then
            count = count + 1
        else
            if prev then emit(parts, count, prev) end
            prev, count = ch, 1
        end
    end
    if prev then emit(parts, count, prev) end
    return table.concat(parts)
end

--- Returns a cell array of length n, or nil and a reason.
function Codec.decode(s, n)
    if type(s) ~= "string" then
        return nil, "not a string"
    end
    local version, body = s:match("^(%d+):(.*)$")
    if version ~= Codec.VERSION then
        return nil, "unknown format"
    end
    local cells, pos = {}, 1
    for count, ch in body:gmatch("(%d*)(.)") do
        local state = FROM_CHAR[ch]
        if not state then
            return nil, "bad cell character " .. ch
        end
        local run = count == "" and 1 or tonumber(count)
        if run < 1 or pos + run - 1 > n then
            return nil, "too many cells"
        end
        for i = pos, pos + run - 1 do
            cells[i] = state
        end
        pos = pos + run
    end
    if pos - 1 ~= n then
        return nil, string.format("expected %d cells, got %d", n, pos - 1)
    end
    return cells
end

return Codec
