local Clues = require("piclogic/model/clues")
local H = require("helpers")

local function status(clue, s)
    local line_done, done = Clues.status(clue, H.line(s), #s)
    return line_done, done
end

describe("derive", function()
    it("lists filled runs in order", function()
        assert.are.same({ 2, 1, 3 }, Clues.derive(H.line("##x#.###"), 8))
    end)

    it("gives 0 for an empty line", function()
        assert.are.same({ 0 }, Clues.derive(H.line("x.x.."), 5))
    end)

    it("handles a full line", function()
        assert.are.same({ 5 }, Clues.derive(H.line("#####"), 5))
    end)
end)

describe("status", function()
    it("marks the whole line when runs match, ignoring missing crosses", function()
        local line_done, done = status({ 1, 2 }, "#.##.")
        assert.is_true(line_done)
        assert.are.same({ true, true }, done)
    end)

    it("treats a 0 clue as satisfied only without fills", function()
        assert.is_true((status({ 0 }, "x...")))
        local line_done, done = status({ 0 }, ".#..")
        assert.is_false(line_done)
        assert.are.same({ false }, done)
    end)

    it("marks a run closed by the edge and a cross", function()
        local line_done, done = status({ 2, 1 }, "##x....")
        assert.is_false(line_done)
        assert.are.same({ true, false }, done)
    end)

    it("does not mark a run with an open end", function()
        local _, done = status({ 3, 1 }, "###....")
        assert.are.same({ false, false }, done)
    end)

    it("does not mark a run with an open start, even from the right", function()
        local _, done = status({ 1, 3 }, "..###x")
        assert.are.same({ false, false }, done)
    end)

    it("marks from the right end", function()
        local _, done = status({ 1, 3 }, "....x###")
        assert.are.same({ false, true }, done)
    end)

    it("does not mark a run whose length is wrong", function()
        local _, done = status({ 2, 2 }, "###x....")
        assert.are.same({ false, false }, done)
    end)

    it("never matches one run to two numbers", function()
        local _, done = status({ 2, 2 }, "##xxxxx")
        assert.are.same({ true, false }, done)
    end)

    it("marks nothing when there are more runs than numbers", function()
        local _, done = status({ 1 }, "#x#xx")
        assert.are.same({ false }, done)
    end)

    it("reuses the done table", function()
        local t = { true, true, true }
        local _, done = Clues.status({ 1 }, H.line("...."), 4, t)
        assert.are.equal(t, done)
        assert.are.same({ false }, done)
    end)
end)
