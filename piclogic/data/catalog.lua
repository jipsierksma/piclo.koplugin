--[[
Loads puzzle packs and resolves puzzles by their stable id.

Pack files are plain data. Each is run in a sandbox whose only global is the
translation function `_`, so a pack can't reach anything else and a broken
one can't take the plugin down. Problems are logged and collected; the
offending pack or puzzle is skipped and loading carries on.

The pack order comes from `index.lua` in the pack directory.
]]

local Puzzle = require("piclogic/model/puzzle")
local logger = require("logger")
local _ = require("gettext")

local Catalog = {}
Catalog.__index = Catalog

-- v1 shows at most 15x15; bigger boards need the pan/zoom viewport.
Catalog.MAX_SIZE = 15

local function loadSandboxed(path)
    local env = { _ = _ }
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    if not chunk then return nil, err end
    local ok, data = pcall(chunk)
    if not ok then return nil, data end
    if type(data) ~= "table" then return nil, path .. ": did not return a table" end
    return data
end

--- True when a license string requires a credit line (any CC-BY variant).
function Catalog.needsCredit(license)
    return type(license) == "string" and license:match("^CC%-BY") ~= nil
end

function Catalog.new()
    return setmetatable({ packs = {}, by_pack = {}, by_puzzle = {}, problems = {} }, Catalog)
end

function Catalog:problem(msg)
    logger.warn("piclogic catalog:", msg)
    self.problems[#self.problems + 1] = msg
end

function Catalog:checkHeader(data, name)
    if type(data.id) ~= "string" or data.id == "" then
        return string.format("pack %s has no id", name)
    end
    if self.by_pack[data.id] then
        return string.format("pack %s: duplicate pack id %s", name, data.id)
    end
    if type(data.title) ~= "string" then
        return string.format("pack %s has no title", data.id)
    end
    if type(data.license) ~= "string" then
        return string.format("pack %s has no license", data.id)
    end
    if Catalog.needsCredit(data.license) and type(data.credit) ~= "string" then
        return string.format("pack %s: license %s needs a credit", data.id, data.license)
    end
    if type(data.puzzles) ~= "table" then
        return string.format("pack %s has no puzzle list", data.id)
    end
end

function Catalog:checkUnlock(pack, unlock)
    if unlock == nil then return nil end
    local after = type(unlock) == "table" and self.by_pack[unlock.pack]
    local count = type(unlock) == "table" and tonumber(unlock.count)
    if not after or not count or count < 1 then
        self:problem(string.format("pack %s: bad unlock rule, leaving it unlocked", pack.id))
        return nil
    end
    return { pack = after.id, count = math.min(math.floor(count), #after.puzzles) }
end

function Catalog:addPuzzles(pack, defs)
    for k, def in ipairs(defs) do
        local p, err = Puzzle.new(def)
        if not p then
            self:problem(string.format("pack %s puzzle %d: %s", pack.id, k, err))
        elseif p.w > Catalog.MAX_SIZE or p.h > Catalog.MAX_SIZE then
            self:problem(string.format("%s: %dx%d is larger than %d", p.id, p.w, p.h, Catalog.MAX_SIZE))
        elseif self.by_puzzle[p.id] then
            self:problem(string.format("%s: duplicate puzzle id", p.id))
        else
            p.pack_id = pack.id
            p.number = #pack.puzzles + 1
            pack.puzzles[p.number] = p
            self.by_puzzle[p.id] = p
        end
    end
end

function Catalog:addPack(data, name)
    local err = self:checkHeader(data, name)
    if err then
        self:problem(err)
        return
    end
    local pack = {
        id = data.id,
        title = data.title,
        license = data.license,
        credit = data.credit,
        puzzles = {},
    }
    self:addPuzzles(pack, data.puzzles)
    if #pack.puzzles == 0 then
        self:problem(string.format("pack %s has no usable puzzles", pack.id))
        return
    end
    pack.unlock = self:checkUnlock(pack, data.unlock)
    self.packs[#self.packs + 1] = pack
    self.by_pack[pack.id] = pack
end

--[[
Loads every pack named in <dir>/index.lua. Always returns a catalog (possibly
empty); catalog.problems lists everything that was skipped.
]]
function Catalog.load(dir)
    local self = Catalog.new()
    local index, err = loadSandboxed(dir .. "/index.lua")
    if not index then
        self:problem("cannot read pack index: " .. tostring(err))
        return self
    end
    for __, name in ipairs(index) do
        local data, perr = loadSandboxed(dir .. "/" .. tostring(name) .. ".lua")
        if data then
            self:addPack(data, name)
        else
            self:problem(string.format("pack %s: %s", tostring(name), tostring(perr)))
        end
    end
    return self
end

function Catalog:pack(id)
    return self.by_pack[id]
end

function Catalog:puzzle(id)
    return self.by_puzzle[id]
end

--- The puzzle after `p` in its pack, or nil at the end.
function Catalog:nextInPack(p)
    local pack = self.by_pack[p.pack_id]
    return pack and pack.puzzles[p.number + 1]
end

--[[
Whether a pack is open, given solved_in(pack_id) -> number of puzzles solved
in that pack. Packs without an unlock rule are always open.
]]
function Catalog:isUnlocked(pack, solved_in)
    local rule = pack.unlock
    return rule == nil or solved_in(rule.pack) >= rule.count
end

return Catalog
