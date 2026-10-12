local Catalog = require("piclogic/data/catalog")

local function hasProblem(catalog, needle)
    for _, msg in ipairs(catalog.problems) do
        if msg:find(needle, 1, true) then return true end
    end
    return false
end

describe("load fixtures", function()
    local catalog = Catalog.load("spec/fixtures/packs")

    it("loads good packs in index order", function()
        assert.are.equal("good", catalog.packs[1].id)
        assert.are.equal("Good", catalog.packs[1].title)
        assert.are.equal(2, #catalog:pack("good").puzzles)
    end)

    it("keeps the valid puzzle of a pack with malformed entries", function()
        local mixed = catalog:pack("mixed")
        assert.are.equal(1, #mixed.puzzles)
        assert.are.equal("mixed/ok", mixed.puzzles[1].id)
        assert.are.equal(1, mixed.puzzles[1].number)
        assert.is_true(hasProblem(catalog, "row 2 has width 1"))
        assert.is_true(hasProblem(catalog, "mixed puzzle 3"))
        assert.is_true(hasProblem(catalog, "good/a: duplicate puzzle id"))
        assert.is_true(hasProblem(catalog, "mixed/badshade"))
    end)

    it("skips packs that fail to load or don't return a table", function()
        assert.is_nil(catalog:pack("broken"))
        assert.is_nil(catalog:pack("returns_string"))
        assert.is_true(hasProblem(catalog, "pack broken"))
        assert.is_true(hasProblem(catalog, "pack missing"))
        assert.is_true(hasProblem(catalog, "did not return a table"))
    end)

    it("runs pack files in a sandbox", function()
        assert.is_nil(catalog:pack("escape"))
        assert.is_true(hasProblem(catalog, "pack escape"))
    end)

    it("requires a credit for attribution licenses", function()
        assert.is_nil(catalog:pack("nocredit"))
        assert.is_true(Catalog.needsCredit("CC-BY-4.0"))
        assert.is_true(Catalog.needsCredit("CC-BY-SA-3.0"))
        assert.is_false(Catalog.needsCredit("CC0-1.0"))
        assert.is_false(Catalog.needsCredit("original"))
    end)

    it("skips puzzles over the v1 size limit", function()
        assert.is_nil(catalog:pack("big"))
        assert.is_true(hasProblem(catalog, "big/a: 16x1 is larger than 15"))
    end)

    it("resolves puzzles by id and finds the next one", function()
        local a = catalog:puzzle("good/a")
        assert.are.equal("good", a.pack_id)
        assert.are.equal("good/b", catalog:nextInPack(a).id)
        assert.is_nil(catalog:nextInPack(catalog:puzzle("good/b")))
        assert.is_nil(catalog:puzzle("nope/nope"))
    end)
end)

describe("unlocks", function()
    local catalog = Catalog.load("spec/fixtures/packs")
    local function solved(counts)
        return function(pack_id) return counts[pack_id] or 0 end
    end

    it("clamps the count to the size of the previous pack", function()
        assert.are.same({ pack = "good", count = 2 }, catalog:pack("locked").unlock)
    end)

    it("opens a pack after enough solves in the previous one", function()
        local locked = catalog:pack("locked")
        assert.is_false(catalog:isUnlocked(locked, solved({ good = 1 })))
        assert.is_true(catalog:isUnlocked(locked, solved({ good = 2 })))
        assert.is_true(catalog:isUnlocked(catalog:pack("good"), solved({})))
    end)

    it("leaves a pack with a bad rule unlocked", function()
        assert.is_nil(catalog:pack("badunlock").unlock)
        assert.is_true(hasProblem(catalog, "badunlock: bad unlock rule"))
    end)
end)

describe("load failures", function()
    it("returns an empty catalog without an index", function()
        local catalog = Catalog.load("spec/fixtures/noindex")
        assert.are.equal(0, #catalog.packs)
        assert.is_true(hasProblem(catalog, "cannot read pack index"))
    end)
end)

describe("shipped packs", function()
    it("load without problems", function()
        local catalog = Catalog.load("piclogic/data/packs")
        assert.are.same({}, catalog.problems)
        assert.are.equal(3, #catalog.packs)
    end)
end)
