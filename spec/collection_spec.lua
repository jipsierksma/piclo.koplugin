local Catalog = require("piclo/data/catalog")
local Collection = require("piclo/collection")
local Progress = require("piclo/storage/progress")

local function store()
    local s = { data = {} }
    function s:readSetting(k) return self.data[k] end
    function s:saveSetting(k, v) self.data[k] = v end
    function s:flush() end
    return s
end

-- The shipped packs: starter (8), then house after 5 in starter, then woods.
local catalog = Catalog.load("piclo/data/packs")

local function fresh()
    local progress = Progress.new(store())
    return Collection.new(catalog, progress), progress
end

local function solve(progress, pack_id, n)
    for k = 1, n do progress:markSolved(catalog:pack(pack_id).puzzles[k].id, 10) end
end

describe("pack info", function()
    it("locks later packs until enough are solved before them", function()
        local col, progress = fresh()
        assert.is_true(col:packInfo(catalog:pack("starter")).unlocked)
        local house = col:packInfo(catalog:pack("house"))
        assert.is_false(house.unlocked)
        assert.are.equal("First Steps", house.rule.after_title)
        solve(progress, "starter", house.rule.count)
        assert.is_true(col:packInfo(catalog:pack("house")).unlocked)
    end)

    it("names the packs a solve just unlocked", function()
        local col, progress = fresh()
        local before = col:lockedPacks()
        solve(progress, "starter", 4)
        assert.are.same({}, col:newlyUnlocked(before))
        solve(progress, "starter", 5)
        assert.are.same({ "Around the House" }, col:newlyUnlocked(before))
    end)

    it("doesn't count revealed puzzles towards unlocks", function()
        local col, progress = fresh()
        for k = 1, 5 do progress:markSolved(catalog:pack("starter").puzzles[k].id, 10, true) end
        assert.is_false(col:packInfo(catalog:pack("house")).unlocked)
    end)
end)

describe("continue", function()
    it("offers the last puzzle while it is in progress", function()
        local col, progress = fresh()
        assert.is_nil(col:continueTarget())
        local p = catalog:pack("starter").puzzles[2]
        progress:setLastPuzzle(p.id)
        progress:saveBoard(p.id, { 1 }, p.w * p.h, 42)
        local cont = col:continueTarget()
        assert.are.equal(p, cont.puzzle)
        assert.are.equal(42, cont.elapsed)
        progress:markSolved(p.id, 50)
        assert.is_nil(col:continueTarget())
    end)
end)

describe("next puzzle", function()
    it("suggests the next unsolved one in the pack, wrapping round", function()
        local col, progress = fresh()
        local starter = catalog:pack("starter").puzzles
        assert.are.equal(starter[2], col:nextAfter(starter[1]))
        progress:markSolved(starter[2].id, 10)
        assert.are.equal(starter[3], col:nextAfter(starter[1]))
        assert.are.equal(starter[1], col:nextAfter(starter[#starter]))
    end)

    it("moves on to an unlocked later pack when the pack is done", function()
        local col, progress = fresh()
        local starter = catalog:pack("starter").puzzles
        solve(progress, "starter", #starter)
        assert.are.equal(catalog:pack("house").puzzles[1], col:nextAfter(starter[1]))
    end)
end)
