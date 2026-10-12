-- Shared spec helpers: compact line and board notation.
local Cell = require("piclogic/model/cell")

local Helpers = {}

local FROM = { ["."] = Cell.UNKNOWN, ["#"] = Cell.FILLED, ["x"] = Cell.CROSSED }
local TO = { [Cell.UNKNOWN] = ".", [Cell.FILLED] = "#", [Cell.CROSSED] = "x" }

--- "#x.." -> { FILLED, CROSSED, UNKNOWN, UNKNOWN }
function Helpers.line(s)
    local out = {}
    for i = 1, #s do out[i] = FROM[s:sub(i, i)] end
    return out
end

function Helpers.str(line, n)
    local chars = {}
    for i = 1, n or #line do chars[i] = TO[line[i]] end
    return table.concat(chars)
end

return Helpers
