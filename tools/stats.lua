--[[
Difficulty report per pack, in pack order. Run from the repo root:
    luajit tools/stats.lua
Columns: solver sweeps needed, share of cells decided by the first sweep,
and the combined score used for ordering (higher = harder). A '<' marks a
puzzle that is easier than the one before it.
]]

dofile("tools/koreader_stubs.lua")

local Catalog = require("piclo/data/catalog")
local Difficulty = require("tools/difficulty")

local catalog = Catalog.load("piclo/data/packs")

for _, pack in ipairs(catalog.packs) do
    io.write(string.format("\n%s (%s)\n", pack.title, pack.id))
    io.write(string.format("  %3s  %-28s %5s %6s %6s %6s\n", "#", "id", "size", "sweeps", "first", "score"))
    local previous = nil
    for _, p in ipairs(pack.puzzles) do
        local m = Difficulty.measure(p)
        local mark = (previous and m.score < previous) and " <" or ""
        if not m.ok then mark = mark .. " NOT SOLVABLE" end
        io.write(string.format("  %3d  %-28s %2dx%-2d %6d %5.0f%% %6.2f%s\n",
            p.number, p.id, p.w, p.h, m.sweeps, m.first_share * 100, m.score, mark))
        previous = m.score
    end
end
