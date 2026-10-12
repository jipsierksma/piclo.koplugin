local LineSolve = require("piclogic/model/linesolve")
local H = require("helpers")

local function solve(clue, s)
    local out, changed = LineSolve.solve(clue, H.line(s), #s)
    return out and H.str(out), changed
end

describe("solve", function()
    it("finds the overlap of a long block", function()
        assert.are.equal("..###..", (solve({ 5 }, ".......")))
    end)

    it("solves an exact fit", function()
        assert.are.equal("##x###", (solve({ 2, 3 }, "......")))
    end)

    it("crosses a 0 line", function()
        local out, changed = solve({ 0 }, "....")
        assert.are.equal("xxxx", out)
        assert.are.equal(4, changed)
    end)

    it("crosses cells no block can reach", function()
        -- the 2 is pinned by the filled cell, far cells can't be reached
        assert.are.equal("x.#.xxx", (solve({ 2 }, "..#....")))
    end)

    it("uses crosses to place blocks", function()
        assert.are.equal("xx###", (solve({ 3 }, ".x...")))
    end)

    it("completes a block that touches the edge", function()
        assert.are.equal("###xx", (solve({ 3 }, "#....")))
    end)

    it("makes deductions the overlap method misses", function()
        -- clue 1 1 with a fill at cell 2: cell 1 and 3 must be empty
        assert.are.equal("x#x..", (solve({ 1, 1 }, ".#...")))
    end)

    it("reports a contradiction", function()
        assert.is_nil((solve({ 3 }, "#x#..")))
        assert.is_nil((solve({ 0 }, "..#")))
        assert.is_nil((solve({ 2, 2 }, "....")))
    end)

    it("leaves an undecidable line alone", function()
        local out, changed = solve({ 1 }, "...")
        assert.are.equal("...", out)
        assert.are.equal(0, changed)
    end)

    it("does not modify its input", function()
        local line = H.line(".......")
        LineSolve.solve({ 5 }, line, 7)
        assert.are.equal(".......", H.str(line))
    end)
end)

describe("solve against brute force", function()
    local Cell = require("piclogic/model/cell")
    local Clues = require("piclogic/model/clues")

    -- Small deterministic LCG so runs are reproducible on any Lua.
    local seed = 12345
    local function rand(n)
        seed = (seed * 16807) % 2147483647 -- Park-Miller, exact in doubles
        return seed % n
    end

    local function bruteForce(clue, line, n)
        local may_fill, may_empty, any = {}, {}, false
        local cand = {}
        for mask = 0, 2 ^ n - 1 do
            local ok, m = true, mask
            for i = 1, n do
                local filled = m % 2 == 1
                m = math.floor(m / 2)
                cand[i] = filled and Cell.FILLED or Cell.CROSSED
                if (line[i] == Cell.FILLED and not filled) or (line[i] == Cell.CROSSED and filled) then
                    ok = false
                end
            end
            if ok then
                local runs = Clues.derive(cand, n)
                if #runs == #clue then
                    for j = 1, #clue do
                        if runs[j] ~= clue[j] then ok = false end
                    end
                else
                    ok = false
                end
            end
            if ok then
                any = true
                for i = 1, n do
                    if cand[i] == Cell.FILLED then may_fill[i] = true else may_empty[i] = true end
                end
            end
        end
        if not any then return nil end
        local out = {}
        for i = 1, n do
            if may_fill[i] and not may_empty[i] then out[i] = Cell.FILLED
            elseif may_empty[i] and not may_fill[i] then out[i] = Cell.CROSSED
            else out[i] = Cell.UNKNOWN end
        end
        return out
    end

    it("agrees on 3000 random lines", function()
        for _ = 1, 3000 do
            local n = 1 + rand(10)
            local picture, line = {}, {}
            for i = 1, n do
                picture[i] = rand(2) == 0 and Cell.FILLED or Cell.CROSSED
            end
            -- clue from one picture, known cells sometimes from another, so
            -- contradictions get exercised too
            local clue = Clues.derive(picture, n)
            local source = picture
            if rand(4) == 0 then
                source = {}
                for i = 1, n do source[i] = rand(2) == 0 and Cell.FILLED or Cell.CROSSED end
            end
            for i = 1, n do
                line[i] = rand(3) == 0 and source[i] or Cell.UNKNOWN
            end
            local expected = bruteForce(clue, line, n)
            local got = LineSolve.solve(clue, line, n)
            local label = table.concat(clue, ",") .. " | " .. H.str(line)
            if expected == nil then
                assert(got == nil, "expected contradiction for " .. label)
            else
                assert(got ~= nil, "unexpected contradiction for " .. label)
                assert(H.str(expected) == H.str(got),
                    label .. ": expected " .. H.str(expected) .. ", got " .. H.str(got))
            end
        end
    end)
end)
