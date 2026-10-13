--[[
Read-only views over the catalog plus saved progress, for the screens: the
puzzle to continue, each pack's progress and lock state, and the puzzle to
suggest next. Pure Lua (no KOReader requires), so it is unit tested.
]]

local Collection = {}
Collection.__index = Collection

function Collection.new(catalog, progress)
    return setmetatable({ catalog = catalog, progress = progress }, Collection)
end

--- The puzzle to offer on the Continue card, or nil.
function Collection:continueTarget()
    local progress = self.progress
    local id = progress.last_puzzle
    local p = id and self.catalog:puzzle(id)
    if not p or not progress:inProgress(id) then return nil end
    return {
        puzzle = p,
        pack = self.catalog:pack(p.pack_id),
        cells = progress:board(p),
        elapsed = progress:elapsed(id),
    }
end

function Collection:solvedIn(pack_id)
    local pack = self.catalog:pack(pack_id)
    return pack and self.progress:solvedCount(pack) or 0
end

--- { unlocked, solved, total, rule = {count, after_title} (locked packs) }
function Collection:packInfo(pack)
    local catalog = self.catalog
    local info = {
        unlocked = catalog:isUnlocked(pack, function(id) return self:solvedIn(id) end),
        solved = self.progress:solvedCount(pack),
        total = #pack.puzzles,
    }
    if pack.unlock then
        info.rule = { count = pack.unlock.count, after_title = catalog:pack(pack.unlock.pack).title }
    end
    return info
end

--- Set of locked pack ids.
function Collection:lockedPacks()
    local locked = {}
    for __, pack in ipairs(self.catalog.packs) do
        if not self:packInfo(pack).unlocked then locked[pack.id] = true end
    end
    return locked
end

--- True when solving `puzzle` (not solved yet) would unlock a pack.
function Collection:wouldUnlock(puzzle)
    if self.progress:isSolved(puzzle.id) then return false end
    local function solvedAfter(id)
        return self:solvedIn(id) + (id == puzzle.pack_id and 1 or 0)
    end
    for __, pack in ipairs(self.catalog.packs) do
        if not self:packInfo(pack).unlocked and self.catalog:isUnlocked(pack, solvedAfter) then
            return true
        end
    end
    return false
end

--- Titles of the packs that are unlocked now but were in `locked_before`.
function Collection:newlyUnlocked(locked_before)
    local titles = {}
    local locked_now = self:lockedPacks()
    for __, pack in ipairs(self.catalog.packs) do
        if locked_before[pack.id] and not locked_now[pack.id] then
            titles[#titles + 1] = pack.title
        end
    end
    return titles
end

--[[
The puzzle to suggest after `puzzle`: the next unsolved one in its pack
(wrapping round), else the first unsolved one in a later unlocked pack.
]]
function Collection:nextAfter(puzzle)
    local catalog, progress = self.catalog, self.progress
    local pack = catalog:pack(puzzle.pack_id)
    local n = #pack.puzzles
    for k = 1, n - 1 do
        local p = pack.puzzles[(puzzle.number - 1 + k) % n + 1]
        if not progress:isSolved(p.id) then return p end
    end
    local after = false
    for __, other in ipairs(catalog.packs) do
        if after and self:packInfo(other).unlocked then
            for __, p in ipairs(other.puzzles) do
                if not progress:isSolved(p.id) then return p end
            end
        end
        if other.id == pack.id then after = true end
    end
    return nil
end

return Collection
