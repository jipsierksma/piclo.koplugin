--[[
Immutable puzzle definition. Built from a data table with `rows` strings
('#' filled, '.' empty) and an optional `shade` layer (digits 0-3 give the
reveal gray of a filled pixel, '.' elsewhere). Clues are always derived from
the rows, so they can never disagree with the picture.

Puzzle.new never throws: on bad input it returns nil and a message.
]]

local Cell = require("piclogic/model/cell")
local Clues = require("piclogic/model/clues")
local Grid = require("piclogic/model/grid")

local Puzzle = {}
Puzzle.__index = Puzzle

Puzzle.MAX_SIZE = 50
Puzzle.SHADE_LEVELS = 4

local function parseRows(rows)
    if type(rows) ~= "table" or #rows == 0 then
        return nil, "rows must be a non-empty list"
    end
    local w = type(rows[1]) == "string" and #rows[1] or 0
    if w == 0 then
        return nil, "row 1 is empty or not a string"
    end
    local cells = {}
    for r, row in ipairs(rows) do
        if type(row) ~= "string" or #row ~= w then
            return nil, string.format("row %d has width %s, expected %d",
                r, type(row) == "string" and #row or type(row), w)
        end
        for c = 1, w do
            local ch = row:sub(c, c)
            if ch == "#" then
                cells[#cells + 1] = Cell.FILLED
            elseif ch == "." then
                cells[#cells + 1] = Cell.CROSSED
            else
                return nil, string.format("row %d col %d: unexpected %q", r, c, ch)
            end
        end
    end
    return cells, w, #rows
end

local function parseShade(shade, w, h)
    if shade == nil then return nil end
    if type(shade) ~= "table" or #shade ~= h then
        return nil, "shade must have one string per row"
    end
    local levels = {}
    for r, row in ipairs(shade) do
        if type(row) ~= "string" or #row ~= w then
            return nil, string.format("shade row %d has the wrong width", r)
        end
        for c = 1, w do
            local ch = row:sub(c, c)
            local v = tonumber(ch)
            if ch == "." then
                v = 0
            elseif not v or v >= Puzzle.SHADE_LEVELS then
                return nil, string.format("shade row %d col %d: unexpected %q", r, c, ch)
            end
            levels[#levels + 1] = v
        end
    end
    return levels
end

function Puzzle.new(def)
    if type(def) ~= "table" then
        return nil, "puzzle definition must be a table"
    end
    if type(def.id) ~= "string" or def.id == "" then
        return nil, "puzzle needs a string id"
    end
    local solution, w, h = parseRows(def.rows)
    if not solution then
        return nil, def.id .. ": " .. w
    end
    if w > Puzzle.MAX_SIZE or h > Puzzle.MAX_SIZE then
        return nil, string.format("%s: %dx%d exceeds the maximum size", def.id, w, h)
    end
    local shade, err = parseShade(def.shade, w, h)
    if def.shade ~= nil and not shade then
        return nil, def.id .. ": " .. err
    end

    local self = setmetatable({
        id = def.id,
        title = def.title or def.id,
        w = w,
        h = h,
        solution = solution,
        shade = shade,
        row_clues = {},
        col_clues = {},
    }, Puzzle)

    local line = {}
    for r = 1, h do
        self.row_clues[r] = Clues.derive(Grid.row(solution, w, r, line), w)
    end
    for c = 1, w do
        self.col_clues[c] = Clues.derive(Grid.col(solution, w, h, c, line), h)
    end
    return self
end

function Puzzle:isFilled(r, c)
    return self.solution[Grid.index(self.w, r, c)] == Cell.FILLED
end

--- Number of picture pixels; handy for stats and thumbnails.
function Puzzle:filledCount()
    local n = 0
    for i = 1, self.w * self.h do
        if self.solution[i] == Cell.FILLED then n = n + 1 end
    end
    return n
end

return Puzzle
