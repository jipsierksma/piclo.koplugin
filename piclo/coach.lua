--[[
The guide for a practice puzzle (see piclo/data/practice.lua): which step
the player is on, the lines it highlights, and whether the board shows a
mistake. Pure Lua; the game screen shows what it says.
]]

local logger = require("logger")
local _ = require("gettext")
local Catalog = require("piclo/data/catalog")
local Cell = require("piclo/model/cell")
local Grid = require("piclo/model/grid")
local Puzzle = require("piclo/model/puzzle")

local Coach = {}
Coach.__index = Coach

--[[
Reads the practice lessons from a data file, sandboxed like the packs.
Returns the list, or an empty one (logged) when the file can't be read, so
How to play just offers no practice.
]]
function Coach.load(path)
    local data, err = Catalog.loadSandboxed(path)
    if not data then
        logger.warn("piclo: no practice puzzles:", err)
        return {}
    end
    local list = {}
    for k, lesson in ipairs(data) do
        local ok = type(lesson) == "table" and type(lesson.steps) == "table" and #lesson.steps > 0
        local puzzle, perr = ok and Puzzle.new{ id = lesson.id, art = lesson.art }
        if puzzle then
            lesson.puzzle = puzzle
            list[#list + 1] = lesson
        else
            logger.warn("piclo: practice puzzle", k, "skipped:", perr)
        end
    end
    return list
end

--- The guide for one lesson from Coach.load, from its first step.
function Coach.new(lesson)
    return setmetatable({ lesson = lesson, puzzle = lesson.puzzle, step = 1 }, Coach)
end

-- Positions along a line: every one for "all", else the list given.
local function positions(which, n)
    if which ~= "all" then return which or {} end
    local all = {}
    for p = 1, n do all[p] = p end
    return all
end

--[[
What step s asks for: a list of {i, state}, the picture's squares to fill
and its empty squares to cross on the step's lines.
]]
function Coach:required(s)
    local p, step, out = self.puzzle, self.lesson.steps[s], {}
    for __, line in ipairs(step.lines) do
        local idx = Grid.lineIndices(p.w, p.h, line[1], line[2])
        for __, pos in ipairs(positions(step.fill, #idx)) do
            if p.solution[idx[pos]] == Cell.FILLED then out[#out + 1] = { idx[pos], Cell.FILLED } end
        end
        for __, pos in ipairs(positions(step.cross, #idx)) do
            if p.solution[idx[pos]] ~= Cell.FILLED then out[#out + 1] = { idx[pos], Cell.CROSSED } end
        end
    end
    return out
end

function Coach:stepDone(s, cells)
    if self.lesson.steps[s].solve then return false end
    for __, want in ipairs(self:required(s)) do
        if cells[want[1]] ~= want[2] then return false end
    end
    return true
end

--[[
Finds the first step the board doesn't show yet (so Undo can take the guide
back a step too); true when the step changed.
]]
function Coach:update(cells)
    local before = self.step
    self.step = 1
    while self.step < #self.lesson.steps and self:stepDone(self.step, cells) do
        self.step = self.step + 1
    end
    return self.step ~= before
end

--- The current step's lines, as a set: { row = {[r] = true}, col = {...} }.
function Coach:lines()
    local set = { row = {}, col = {} }
    for __, line in ipairs(self.lesson.steps[self.step].lines) do set[line[1]][line[2]] = true end
    return set
end

function Coach:text()
    return self.lesson.steps[self.step].text
end

function Coach:doneText()
    return self.lesson.done
end

--- True when a square is marked against the picture.
function Coach:hasMistake(cells)
    local sol = self.puzzle.solution
    for i = 1, self.puzzle.w * self.puzzle.h do
        local v = cells[i]
        if v ~= Cell.UNKNOWN and (v == Cell.FILLED) ~= (sol[i] == Cell.FILLED) then return true end
    end
    return false
end

--- Every text the guide can show, to size its room once.
function Coach:texts()
    local list = {}
    for __, step in ipairs(self.lesson.steps) do list[#list + 1] = step.text end
    list[#list + 1] = self.lesson.done
    list[#list + 1] = Coach.mistakeText()
    return list
end

function Coach.mistakeText()
    return _("The marked square doesn't fit the numbers. Tap it to change it, or use Undo.")
end

return Coach
