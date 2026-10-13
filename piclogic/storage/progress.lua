--[[
Saved progress and settings, kept in <settings dir>/piclogic.lua through
LuaSettings. This is the only module that touches LuaSettings or
DataStorage; everything else goes through its methods.

Layout of the file (schema 1):
  schema_version = 1
  puzzles = { [puzzle id] = { state, elapsed, solved, best, solved_at, revealed } }
  settings = { [key] = value }     -- only values the user changed
  last_puzzle = id
  seen_help = bool

Writes land in memory at once; flush() writes the file. The app debounces
flushes and always flushes on close and suspend. Ids are never derived from
list positions, so adding or reordering puzzles can't corrupt progress, and
records for unknown ids are simply ignored.
]]

local Codec = require("piclogic/model/codec")
local logger = require("logger")

local Progress = {}
Progress.__index = Progress

Progress.SCHEMA = 1
Progress.FILE = "piclogic.lua"

Progress.DEFAULTS = {
    mistakes = "off", -- "off" | "request" | "instant"
    highlight_done = true,
    hold_action = "opposite", -- hold uses the other tool, or "cross" always
    show_timer = false,
    deghost_every = 20, -- edits; 0 = never
    rail_side = "right", -- landscape toolbar: "right" | "left"
}

--- Progress backed by KOReader's settings directory.
function Progress.open()
    local DataStorage = require("datastorage")
    local LuaSettings = require("luasettings")
    return Progress.new(LuaSettings:open(DataStorage:getSettingsDir() .. "/" .. Progress.FILE))
end

--[[
store: anything with LuaSettings' readSetting/saveSetting/flush.
clock: returns seconds (os.time by default).
]]
function Progress.new(store, clock)
    local self = setmetatable({ store = store, clock = clock or os.time, dirty = false }, Progress)
    self:load()
    return self
end

local function tableOr(value, what)
    if value == nil then return {} end
    if type(value) ~= "table" then
        logger.warn("piclogic: ignoring corrupt", what)
        return {}
    end
    return value
end

function Progress:load()
    local store = self.store
    local version = store:readSetting("schema_version")
    if version == nil then
        self.dirty = true
    elseif type(version) ~= "number" or version > Progress.SCHEMA then
        -- Written by a newer plugin: use what we can, but never overwrite it.
        logger.warn("piclogic: progress schema", version, "is newer; not saving")
        self.read_only = true
    end
    self.puzzles = tableOr(store:readSetting("puzzles"), "puzzle progress")
    for id, rec in pairs(self.puzzles) do
        if type(id) ~= "string" or type(rec) ~= "table" then
            logger.warn("piclogic: dropping corrupt progress for", tostring(id))
            self.puzzles[id] = nil
        end
    end
    self.settings = tableOr(store:readSetting("settings"), "settings")
    local last = store:readSetting("last_puzzle")
    self.last_puzzle = type(last) == "string" and last or nil
    self.seen_help = store:readSetting("seen_help") == true
end

function Progress:touch()
    self.dirty = true
end

--- Writes to disk if anything changed. Returns true when it wrote.
function Progress:flush()
    if not self.dirty or self.read_only then return false end
    local store = self.store
    store:saveSetting("schema_version", Progress.SCHEMA)
    store:saveSetting("puzzles", self.puzzles)
    store:saveSetting("settings", self.settings)
    store:saveSetting("last_puzzle", self.last_puzzle)
    store:saveSetting("seen_help", self.seen_help)
    store:flush()
    self.dirty = false
    return true
end

-- Puzzles --------------------------------------------------------------

function Progress:record(id)
    return self.puzzles[id]
end

local function ensure(self, id)
    local rec = self.puzzles[id]
    if not rec then
        rec = {}
        self.puzzles[id] = rec
    end
    return rec
end

--- Saves a board in play. An empty board clears the saved state.
function Progress:saveBoard(id, cells, n, elapsed, empty)
    local rec = ensure(self, id)
    rec.state = (not empty) and Codec.encode(cells, n) or nil
    rec.elapsed = math.floor(elapsed or 0)
    self:touch()
end

--- The saved cells for a puzzle, or nil (none saved, or unreadable).
function Progress:board(puzzle)
    local rec = self.puzzles[puzzle.id]
    if not rec or not rec.state then return nil end
    local cells, err = Codec.decode(rec.state, puzzle.w * puzzle.h)
    if not cells then
        logger.warn("piclogic: unreadable board for", puzzle.id, err)
    end
    return cells
end

function Progress:elapsed(id)
    local rec = self.puzzles[id]
    return rec and tonumber(rec.elapsed) or 0
end

function Progress:isSolved(id)
    local rec = self.puzzles[id]
    return rec ~= nil and rec.solved == true
end

--- Shown with "Show solution" and not solved since.
function Progress:isRevealed(id)
    local rec = self.puzzles[id]
    return rec ~= nil and rec.revealed == true and rec.solved ~= true
end

--- Started (has a saved board) and not solved.
function Progress:inProgress(id)
    local rec = self.puzzles[id]
    return rec ~= nil and rec.state ~= nil and not rec.solved
end

--[[
Records a finished puzzle. With `revealed` (the solution was shown) it is
marked revealed instead of solved. Returns { first = bool, new_best = bool }:
new_best only when an earlier best time was beaten.
]]
function Progress:markSolved(id, elapsed, revealed)
    local rec = ensure(self, id)
    elapsed = math.floor(elapsed or 0)
    local result = { first = false, new_best = false }
    rec.elapsed = elapsed
    if revealed then
        rec.revealed = true
    else
        result.first = not rec.solved
        result.new_best = rec.best ~= nil and elapsed < rec.best
        rec.solved = true
        rec.solved_at = rec.solved_at or self.clock()
        if rec.best == nil or elapsed < rec.best then rec.best = elapsed end
    end
    self:touch()
    return result
end

function Progress:best(id)
    local rec = self.puzzles[id]
    return rec and rec.best
end

--- Clears the board and time for a replay; keeps solved and best.
function Progress:restart(id)
    local rec = self.puzzles[id]
    if not rec then return end
    rec.state = nil
    rec.elapsed = 0
    self:touch()
end

function Progress:solvedCount(pack)
    local n = 0
    for _, p in ipairs(pack.puzzles) do
        if self:isSolved(p.id) then n = n + 1 end
    end
    return n
end

function Progress:setLastPuzzle(id)
    if self.last_puzzle ~= id then
        self.last_puzzle = id
        self:touch()
    end
end

function Progress:setSeenHelp()
    if not self.seen_help then
        self.seen_help = true
        self:touch()
    end
end

--- Forgets all puzzle progress; settings stay.
function Progress:resetAll()
    self.puzzles = {}
    self.last_puzzle = nil
    self:touch()
end

-- Settings ----------------------------------------------------------------

function Progress:setting(key)
    local v = self.settings[key]
    if v == nil then return Progress.DEFAULTS[key] end
    return v
end

function Progress:setSetting(key, value)
    if value == Progress.DEFAULTS[key] then value = nil end
    if self.settings[key] ~= value then
        self.settings[key] = value
        self:touch()
    end
end

return Progress
