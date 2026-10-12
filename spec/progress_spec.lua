local Cell = require("piclogic/model/cell")
local Progress = require("piclogic/storage/progress")
local Puzzle = require("piclogic/model/puzzle")

-- In-memory stand-in for LuaSettings that remembers what was flushed.
local function store(data)
    local s = { data = data or {}, flushed = nil, flushes = 0 }
    function s:readSetting(k) return self.data[k] end
    function s:saveSetting(k, v) self.data[k] = v end
    function s:flush()
        self.flushes = self.flushes + 1
        self.flushed = {}
        for k, v in pairs(self.data) do self.flushed[k] = v end
    end
    return s
end

local P = assert(Puzzle.new({ id = "pack/p", rows = { "#.", ".#" } }))
local PACK = { puzzles = { P, { id = "pack/q" } } }

local function cells(s)
    local map = { ["."] = Cell.UNKNOWN, ["#"] = Cell.FILLED, ["x"] = Cell.CROSSED }
    local out = {}
    for i = 1, #s do out[i] = map[s:sub(i, i)] end
    return out
end

describe("a fresh file", function()
    it("starts empty with defaults and writes the schema on first flush", function()
        local s = store()
        local pr = Progress.new(s)
        assert.is_nil(pr:record("pack/p"))
        assert.are.equal("off", pr:setting("mistakes"))
        assert.are.equal(20, pr:setting("deghost_every"))
        assert.is_false(pr.seen_help)
        assert.is_true(pr:flush())
        assert.are.equal(Progress.SCHEMA, s.flushed.schema_version)
        assert.is_false(pr:flush())
        assert.are.equal(1, s.flushes)
    end)
end)

describe("boards", function()
    it("round-trips a board through a new session", function()
        local s = store()
        local pr = Progress.new(s)
        pr:saveBoard("pack/p", cells("#x.#"), 4, 42.7)
        pr:setLastPuzzle("pack/p")
        pr:flush()
        local again = Progress.new(store(s.flushed))
        assert.are.same(cells("#x.#"), again:board(P))
        assert.are.equal(42, again:elapsed("pack/p"))
        assert.are.equal("pack/p", again.last_puzzle)
        assert.is_true(again:inProgress("pack/p"))
    end)

    it("forgets the state of an emptied board", function()
        local pr = Progress.new(store())
        pr:saveBoard("pack/p", cells("...."), 4, 3, true)
        assert.is_nil(pr:board(P))
        assert.is_false(pr:inProgress("pack/p"))
    end)

    it("treats an unreadable board as none", function()
        local pr = Progress.new(store({ schema_version = 1, puzzles = { ["pack/p"] = { state = "1:9#" } } }))
        assert.is_nil(pr:board(P))
    end)
end)

describe("solving", function()
    it("records the first solve, then only real improvements as new bests", function()
        local pr = Progress.new(store(), function() return 1000 end)
        local r1 = pr:markSolved("pack/p", 90)
        assert.is_true(r1.first)
        assert.is_false(r1.new_best)
        assert.is_true(pr:isSolved("pack/p"))
        assert.are.equal(1000, pr:record("pack/p").solved_at)
        local r2 = pr:markSolved("pack/p", 120)
        assert.is_false(r2.first)
        assert.is_false(r2.new_best)
        assert.are.equal(90, pr:best("pack/p"))
        assert.is_true(pr:markSolved("pack/p", 60).new_best)
        assert.are.equal(60, pr:best("pack/p"))
    end)

    it("marks a shown solution as revealed, not solved", function()
        local pr = Progress.new(store())
        pr:markSolved("pack/p", 10, true)
        assert.is_false(pr:isSolved("pack/p"))
        assert.is_true(pr:record("pack/p").revealed)
    end)

    it("counts solved puzzles per pack", function()
        local pr = Progress.new(store())
        assert.are.equal(0, pr:solvedCount(PACK))
        pr:markSolved("pack/q", 5)
        assert.are.equal(1, pr:solvedCount(PACK))
    end)

    it("restarts a replay but keeps the solve and best time", function()
        local pr = Progress.new(store())
        pr:saveBoard("pack/p", cells("#..#"), 4, 30)
        pr:markSolved("pack/p", 30)
        pr:restart("pack/p")
        assert.is_nil(pr:board(P))
        assert.are.equal(0, pr:elapsed("pack/p"))
        assert.is_true(pr:isSolved("pack/p"))
        assert.are.equal(30, pr:best("pack/p"))
    end)
end)

describe("robustness", function()
    it("drops corrupt records and keeps the rest", function()
        local pr = Progress.new(store({
            schema_version = 1,
            puzzles = { ["pack/p"] = "junk", ["pack/q"] = { solved = true }, [7] = {} },
            settings = "junk",
            last_puzzle = 12,
        }))
        assert.is_nil(pr:record("pack/p"))
        assert.is_true(pr:isSolved("pack/q"))
        assert.are.equal("off", pr:setting("mistakes"))
        assert.is_nil(pr.last_puzzle)
    end)

    it("keeps records for puzzle ids it no longer knows", function()
        local s = store({ schema_version = 1, puzzles = { ["gone/old"] = { solved = true } } })
        local pr = Progress.new(s)
        pr:markSolved("pack/p", 1)
        pr:flush()
        assert.is_not_nil(s.flushed.puzzles["gone/old"])
    end)

    it("never writes over a newer schema", function()
        local s = store({ schema_version = 99 })
        local pr = Progress.new(s)
        pr:markSolved("pack/p", 1)
        assert.is_false(pr:flush())
        assert.are.equal(0, s.flushes)
    end)
end)

describe("settings and reset", function()
    it("stores only values that differ from the defaults", function()
        local pr = Progress.new(store())
        pr:setSetting("mistakes", "instant")
        assert.are.equal("instant", pr:setting("mistakes"))
        pr:setSetting("mistakes", "off")
        assert.is_nil(pr.settings.mistakes)
    end)

    it("resets progress but keeps settings", function()
        local pr = Progress.new(store())
        pr:setSetting("show_timer", true)
        pr:markSolved("pack/p", 1)
        pr:setLastPuzzle("pack/p")
        pr:resetAll()
        assert.is_false(pr:isSolved("pack/p"))
        assert.is_nil(pr.last_puzzle)
        assert.is_true(pr:setting("show_timer"))
    end)
end)
