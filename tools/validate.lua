--[[
Build-time check of every shipped pack. Run from the repo root:
    luajit tools/validate.lua
Fails (exit 1) when a pack or puzzle doesn't load, a puzzle id doesn't start
with its pack id, a pack isn't mentioned in CREDITS.md, or a puzzle can't be
solved by the line solver alone. Stuck puzzles are printed next to the
picture so the blocking area is easy to spot. Difficulty order problems are
reported as warnings.
]]

dofile("tools/koreader_stubs.lua")

local Catalog = require("piclogic/data/catalog")
local Difficulty = require("tools/difficulty")
local Solver = require("piclogic/model/solver")

local PACK_DIR = "piclogic/data/packs"
local failures = 0

local function fail(msg)
    failures = failures + 1
    io.write("FAIL ", msg, "\n")
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local s = f:read("*a")
    f:close()
    return s
end

local function printStuck(p, cells)
    local stuck = Solver.render(p, cells)
    local col = "%-" .. math.max(p.w, #"picture") .. "s"
    io.write("     ", string.format(col, "picture"), "   solver\n")
    for r = 1, p.h do
        local pic = {}
        for c = 1, p.w do pic[c] = p:isFilled(r, c) and "#" or "." end
        io.write("     ", string.format(col, table.concat(pic)), "   ", stuck[r], "\n")
    end
end

local catalog = Catalog.load(PACK_DIR)
for _, msg in ipairs(catalog.problems) do
    fail(msg)
end

local credits = readFile("CREDITS.md")
local total = 0
for _, pack in ipairs(catalog.packs) do
    if not credits:find("`" .. pack.id .. "`", 1, true) then
        fail(string.format("pack %s is not listed in CREDITS.md", pack.id))
    end
    local measures = {}
    for _, p in ipairs(pack.puzzles) do
        total = total + 1
        if p.id:sub(1, #pack.id + 1) ~= pack.id .. "/" then
            fail(string.format("%s: id should start with %s/", p.id, pack.id))
        end
        local m = Difficulty.measure(p)
        measures[p.id] = m
        if not m.ok then
            fail(string.format("%s (%dx%d) is not line-solvable", p.id, p.w, p.h))
            printStuck(p, m.result.cells)
        end
    end
    for _, k in ipairs(Difficulty.outOfOrder(pack, measures)) do
        io.write(string.format("warn %s: #%d is easier than #%d (see make stats)\n",
            pack.id, k, k - 1))
    end
end

io.write(string.format("%d packs, %d puzzles, %d failures\n", #catalog.packs, total, failures))
os.exit(failures == 0 and 0 or 1)
