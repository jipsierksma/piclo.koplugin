local Cell = require("piclogic/model/cell")
local Puzzle = require("piclogic/model/puzzle")

describe("puzzle", function()
    it("derives row and column clues from the rows", function()
        local p = assert(Puzzle.new({ id = "p", rows = {
            "##.#",
            "....",
            "#.##",
        } }))
        assert.are.equal(4, p.w)
        assert.are.equal(3, p.h)
        assert.are.same({ { 2, 1 }, { 0 }, { 1, 2 } }, p.row_clues)
        assert.are.same({ { 1, 1 }, { 1 }, { 1 }, { 1, 1 } }, p.col_clues)
        assert.is_true(p:isFilled(1, 1))
        assert.is_false(p:isFilled(2, 1))
        assert.are.equal(Cell.CROSSED, p.solution[5])
        assert.are.equal(6, p:filledCount())
    end)

    it("uses the id as a fallback title", function()
        assert.are.equal("p", Puzzle.new({ id = "p", rows = { "#" } }).title)
    end)

    it("parses an optional shade layer", function()
        local p = assert(Puzzle.new({ id = "p", rows = { "##", ".#" }, shade = { "02", ".4" } }))
        assert.are.same({ 0, 2, 0, 4 }, p.shade)
    end)

    it("reads a single tone grid as picture plus shade", function()
        local p = assert(Puzzle.new({ id = "p", art = { "03.", ".42" } }))
        assert.are.same({ { 2 }, { 2 } }, p.row_clues)
        assert.are.same({ { 1 }, { 2 }, { 1 } }, p.col_clues)
        assert.are.same({ 0, 3, 0, 0, 4, 2 }, p.shade)
        assert.is_true(p:isFilled(1, 1))
        assert.is_false(p:isFilled(1, 3))
    end)

    it("rejects malformed definitions without throwing", function()
        local bad = {
            "not a table",
            { rows = { "#" } },
            { id = "p" },
            { id = "p", rows = {} },
            { id = "p", rows = { "##", "#" } },
            { id = "p", rows = { "#?" } },
            { id = "p", rows = { "#" }, shade = { "5" } },
            { id = "p", rows = { "#" }, shade = { "." } },
            { id = "p", rows = { "." }, shade = { "0" } },
            { id = "p", rows = { "##" }, shade = { "0" } },
            { id = "p", rows = { "#", 7 } },
            { id = "p", art = { "05" } },
            { id = "p", art = { "0#" } },
            { id = "p", art = { "01", "2" } },
            { id = "p", art = "01" },
            { id = "p", art = { "01" }, rows = { "##" } },
        }
        for _, def in ipairs(bad) do
            local p, err = Puzzle.new(def)
            assert.is_nil(p)
            assert.are.equal("string", type(err))
        end
    end)
end)
