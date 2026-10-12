--[[
Difficulty estimate shared by validate.lua and stats.lua. Puzzles needing
more solver sweeps are harder; at equal sweeps, the less the first sweep
decides, the harder. Larger score = harder.
]]

local Solver = require("piclogic/model/solver")

local Difficulty = {}

function Difficulty.measure(puzzle)
    local ok, result = Solver.validate(puzzle)
    return {
        ok = ok,
        result = result,
        sweeps = result.sweeps,
        first_share = result.first_sweep_share,
        score = result.sweeps + (1 - result.first_sweep_share),
    }
end

--- Puzzle numbers in `pack` that are easier than the puzzle before them.
function Difficulty.outOfOrder(pack, measures)
    local list = {}
    for k = 2, #pack.puzzles do
        if measures[pack.puzzles[k].id].score < measures[pack.puzzles[k - 1].id].score then
            list[#list + 1] = k
        end
    end
    return list
end

return Difficulty
