--[[
Navigation controller: owns the plugin window (ui/host), the catalog, saved
progress and the game in play. Screens call it to move around; the window
passes lifecycle events (suspend, close) up to it.

Navigation is a stack of routes ({name = "home" | "help" | "pack" | "game"
| "reveal", ...}); back pops one. Screens are rebuilt from data each time
they show, so they always reflect current progress.
]]

local UIManager = require("ui/uimanager")
local Catalog = require("piclogic/data/catalog")
local Game = require("piclogic/game")
local GameScreen = require("piclogic/ui/screens/game")
local HelpScreen = require("piclogic/ui/screens/help")
local HomeScreen = require("piclogic/ui/screens/home")
local Host = require("piclogic/ui/host")
local Icons = require("piclogic/ui/icons")
local PackScreen = require("piclogic/ui/screens/pack")
local Progress = require("piclogic/storage/progress")
local RevealScreen = require("piclogic/ui/screens/reveal")
local T = require("ffi/util").template
local _ = require("gettext")

local App = {}
App.__index = App

-- Seconds the finished grid stays up before the reveal.
App.REVEAL_DELAY = 0.8
-- At most one progress write per this many seconds while playing.
App.FLUSH_DELAY = 5

--- opts: ui (ReaderUI or FileManager), path (plugin dir), version, progress (tests)
function App.new(opts)
    Icons.init(opts.path)
    local self = setmetatable({
        ui = opts.ui,
        path = opts.path,
        version = opts.version,
        _progress = opts.progress,
        stack = {},
    }, App)
    self.flush_task = function()
        self.flush_pending = false
        self:progress():flush()
    end
    return self
end

function App:catalog()
    if not self._catalog then
        self._catalog = Catalog.load(self.path .. "/piclogic/data/packs")
    end
    return self._catalog
end

function App:progress()
    if not self._progress then self._progress = Progress.open() end
    return self._progress
end

-- Navigation --------------------------------------------------------------

--- Opens the app on its home screen (with help first, on the very first run).
function App:open()
    if not self.host then
        self.host = Host:new{ app = self }
        UIManager:show(self.host)
    end
    self.stack = { { name = "home" } }
    if not self:progress().seen_help then
        self:progress():setSeenHelp()
        self.stack[2] = { name = "help" }
    end
    self:render()
end

function App:build(route)
    if route.name == "home" then return HomeScreen.new{ app = self } end
    if route.name == "help" then return HelpScreen.new{ app = self } end
    if route.name == "pack" then
        return PackScreen.new{ app = self, pack = self:catalog():pack(route.pack_id), page = route.page }
    end
    if route.name == "game" then
        local p = self.game.puzzle
        local deghost = self:progress():setting("deghost_every")
        return GameScreen.new{
            app = self,
            game = self.game,
            -- e.g. "Around the House · 7"
            title = T(_("%1 · %2"), self:catalog():pack(p.pack_id).title, p.number),
            deghost_every = (deghost and deghost > 0) and deghost or nil,
        }
    end
    return RevealScreen.new{ app = self, data = route.data }
end

function App:render(refresh)
    local route = self.stack[#self.stack]
    self.host:setScreen(self:build(route), refresh)
end

function App:push(route)
    self.stack[#self.stack + 1] = route
    self:render()
end

function App:replaceTop(route, refresh)
    self.stack[#self.stack] = route
    self:render(refresh)
end

function App:cancelReveal()
    if self.reveal_task then
        UIManager:unschedule(self.reveal_task)
        self.reveal_task = nil
    end
end

function App:back()
    self:cancelReveal()
    local top = table.remove(self.stack)
    if top and top.name == "game" then self:stopGame() end
    if #self.stack == 0 then
        self:close()
    else
        self:render()
    end
end

function App:showHelp()
    self:push{ name = "help" }
end

function App:showPack(pack_id)
    self:push{ name = "pack", pack_id = pack_id }
end

--- Pack screens remember their page so back returns to it.
function App:rememberPage(page)
    local top = self.stack[#self.stack]
    if top and top.name == "pack" then top.page = page end
end

--- Unsolved puzzles open the board; solved ones open their picture.
function App:openPuzzle(puzzle)
    local progress = self:progress()
    if progress:isSolved(puzzle.id) then
        self:push{ name = "reveal", data = {
            mode = "view",
            puzzle = puzzle,
            best = progress:best(puzzle.id),
        } }
        return
    end
    self:startGame(puzzle)
    self:push{ name = "game" }
end

function App:playNext(puzzle)
    self:startGame(puzzle)
    self:replaceTop{ name = "game" }
end

function App:playAgain(puzzle)
    self:progress():restart(puzzle.id)
    self:startGame(puzzle)
    self:replaceTop{ name = "game" }
end

--- Returns to the pack's collection, reusing it from the stack if present.
function App:backToCollection(pack_id)
    for k = #self.stack, 1, -1 do
        local r = self.stack[k]
        if r.name == "pack" and r.pack_id == pack_id then
            for j = #self.stack, k + 1, -1 do self.stack[j] = nil end
            return self:render()
        end
    end
    self.stack = { { name = "home" }, { name = "pack", pack_id = pack_id } }
    self:render()
end

function App:close()
    if self.host then
        UIManager:close(self.host, "flashui")
    end
end

-- Data for screens ------------------------------------------------------

--- The puzzle to offer on the Continue card, or nil.
function App:continueTarget()
    local progress = self:progress()
    local id = progress.last_puzzle
    local p = id and self:catalog():puzzle(id)
    if not p or not progress:inProgress(id) then return nil end
    return {
        puzzle = p,
        pack = self:catalog():pack(p.pack_id),
        cells = progress:board(p),
        elapsed = progress:elapsed(id),
    }
end

function App:solvedIn(pack_id)
    local pack = self:catalog():pack(pack_id)
    return pack and self:progress():solvedCount(pack) or 0
end

function App:packInfo(pack)
    local catalog = self:catalog()
    local info = {
        unlocked = catalog:isUnlocked(pack, function(id) return self:solvedIn(id) end),
        solved = self:progress():solvedCount(pack),
        total = #pack.puzzles,
    }
    if pack.unlock then
        info.rule = { count = pack.unlock.count, after_title = catalog:pack(pack.unlock.pack).title }
    end
    return info
end

function App:lockedPacks()
    local locked = {}
    for __, pack in ipairs(self:catalog().packs) do
        if not self:packInfo(pack).unlocked then locked[pack.id] = true end
    end
    return locked
end

--[[
The puzzle to suggest after `puzzle`: the next unsolved one in its pack
(wrapping round), else the first unsolved one in a later unlocked pack.
]]
function App:nextAfter(puzzle)
    local catalog, progress = self:catalog(), self:progress()
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

-- The game in play ------------------------------------------------------

function App:startGame(puzzle)
    self:stopGame()
    local progress = self:progress()
    self.game = Game.new{
        puzzle = puzzle,
        cells = progress:board(puzzle),
        elapsed = progress:elapsed(puzzle.id),
    }
    self.game:resume()
    progress:setLastPuzzle(puzzle.id)
end

function App:saveGame()
    local game = self.game
    if not game or game.solved then return end
    local p = game.puzzle
    self:progress():saveBoard(p.id, game.board.cells, p.w * p.h, game:elapsed(), game.board:isEmpty())
end

--- Saves and lets go of the game (leaving its screen).
function App:stopGame()
    if not self.game then return end
    self.game:pause()
    self:saveGame()
    self.game = nil
    self:flush()
end

function App:scheduleFlush()
    if self.flush_pending then return end
    self.flush_pending = true
    UIManager:scheduleIn(App.FLUSH_DELAY, self.flush_task)
end

--- Writes progress now (also cancels a pending debounced write).
function App:flush()
    if self.flush_pending then
        UIManager:unschedule(self.flush_task)
        self.flush_pending = false
    end
    self:saveGame()
    if self._progress then self._progress:flush() end
end

function App:onMove()
    self:saveGame()
    self:scheduleFlush()
end

--- Records the solve, then shows the reveal after a short pause.
function App:onSolved(game)
    local progress, p = self:progress(), game.puzzle
    local locked_before = self:lockedPacks()
    progress:saveBoard(p.id, nil, 0, game:elapsed(), true)
    local result = progress:markSolved(p.id, game:elapsed())
    local unlocked = {}
    local locked_after = self:lockedPacks()
    for __, pack in ipairs(self:catalog().packs) do
        if locked_before[pack.id] and not locked_after[pack.id] then
            unlocked[#unlocked + 1] = pack.title
        end
    end
    self:flush()
    local data = {
        mode = "solved",
        puzzle = p,
        elapsed = game:elapsed(),
        best = progress:best(p.id),
        result = result,
        next = self:nextAfter(p),
        unlocked = unlocked,
    }
    self.reveal_task = function()
        self.reveal_task = nil
        if not self.host then return end
        self.game = nil
        self:replaceTop({ name = "reveal", data = data }, "full")
    end
    UIManager:scheduleIn(App.REVEAL_DELAY, self.reveal_task)
end

-- Lifecycle, called by the window ------------------------------------

function App:onClosed()
    self:cancelReveal()
    self:stopGame()
    self:flush()
    self.stack = {}
    self.host = nil
    Icons.free()
end

function App:onSuspend()
    if self.game then self.game:pause() end
    self:flush()
end

function App:onResume()
    if self.game then self.game:resume() end
end

return App
