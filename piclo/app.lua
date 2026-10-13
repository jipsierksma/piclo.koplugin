--[[
Navigation controller: owns the plugin window (ui/host), the catalog, saved
progress and the game in play. Screens call it to move around; the window
passes lifecycle events (suspend, close) up to it.

Navigation is a stack of routes ({name = "home" | "help" | "pack" | "game"
| "reveal" | "settings", ...}); back pops one. Screens are rebuilt from
data and settings each time they show, so a changed setting takes effect as
soon as its screen is back on top.
]]

local UIManager = require("ui/uimanager")
local Catalog = require("piclo/data/catalog")
local Collection = require("piclo/collection")
local Game = require("piclo/game")
local GameScreen = require("piclo/ui/screens/game")
local HelpScreen = require("piclo/ui/screens/help")
local HomeScreen = require("piclo/ui/screens/home")
local Host = require("piclo/ui/host")
local Icons = require("piclo/ui/icons")
local PackScreen = require("piclo/ui/screens/pack")
local Progress = require("piclo/storage/progress")
local RevealScreen = require("piclo/ui/screens/reveal")
local SettingsScreen = require("piclo/ui/screens/settings")
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
        self._catalog = Catalog.load(self.path .. "/piclo/data/packs")
    end
    return self._catalog
end

function App:progress()
    if not self._progress then self._progress = Progress.open() end
    return self._progress
end

function App:collection()
    if not self._collection then
        self._collection = Collection.new(self:catalog(), self:progress())
    end
    return self._collection
end

function App:setting(key)
    return self:progress():setting(key)
end

--- Saves a setting; screens pick it up when they are next built.
function App:setSetting(key, value)
    self:progress():setSetting(key, value)
    self:scheduleFlush()
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
        self.stack[2] = { name = "help", first_run = true }
    end
    self:render()
end

function App:build(route)
    if route.name == "home" then return HomeScreen.new{ app = self } end
    if route.name == "help" then return HelpScreen.new{ app = self, first_run = route.first_run } end
    if route.name == "settings" then return SettingsScreen.new{ app = self, cleared = route.cleared } end
    if route.name == "pack" then
        return PackScreen.new{ app = self, pack = self:catalog():pack(route.pack_id), page = route.page }
    end
    if route.name == "game" then
        local p = self.game.puzzle
        local deghost = self:setting("deghost_every")
        self.game:setMistakeMode(self:setting("mistakes"))
        return GameScreen.new{
            app = self,
            game = self.game,
            -- e.g. "Around the House · 7"
            title = T(_("%1 · %2"), self:catalog():pack(p.pack_id).title, p.number),
            deghost_every = (deghost and deghost > 0) and deghost or nil,
            highlight_done = self:setting("highlight_done"),
            hold_action = self:setting("hold_action"),
            show_timer = self:setting("show_timer"),
            rail_side = self:setting("rail_side"),
        }
    end
    return RevealScreen.new{ app = self, data = route.data, rail_side = self:setting("rail_side") }
end

-- The timer runs only while the board is on screen.
function App:render(refresh)
    local route = self.stack[#self.stack]
    if self.game then
        if route.name == "game" then self.game:resume() else self.game:pause() end
    end
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

function App:showSettings()
    self:push{ name = "settings" }
end

function App:showPack(pack_id)
    self:push{ name = "pack", pack_id = pack_id }
end

--- Pack screens remember their page so back returns to it.
function App:rememberPage(page)
    local top = self.stack[#self.stack]
    if top and top.name == "pack" then top.page = page end
end

--- Unsolved puzzles open the board; solved and revealed ones their picture.
function App:openPuzzle(puzzle)
    local progress = self:progress()
    local revealed = progress:isRevealed(puzzle.id)
    if revealed or progress:isSolved(puzzle.id) then
        self:push{ name = "reveal", data = {
            mode = "view",
            puzzle = puzzle,
            best = progress:best(puzzle.id),
            revealed = revealed,
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

-- The game in play ------------------------------------------------------

--- Clears the board in play and starts its time over.
function App:restartGame()
    if not self.game then return end
    self.game:restart()
    self:saveGame()
    self:scheduleFlush()
    self:render()
end

--[[
"Show solution": records the puzzle as revealed (not solved), forgets the
board in play and shows the picture.
]]
function App:showSolution()
    local game = self.game
    if not game then return end
    game:pause()
    local progress, p = self:progress(), game.puzzle
    progress:saveBoard(p.id, nil, 0, game:elapsed(), true)
    progress:markSolved(p.id, game:elapsed(), true)
    self.game = nil
    self:flush()
    self:replaceTop({ name = "reveal", data = {
        mode = "solved",
        puzzle = p,
        revealed = true,
        next = self:collection():nextAfter(p),
        unlocked = {},
    } }, "full")
end

--- Forgets all puzzle progress (settings stay) and drops the game in play.
function App:resetProgress()
    self:cancelReveal()
    self.game = nil
    self:progress():resetAll()
    self:flush()
    self.stack = { { name = "home" }, { name = "settings", cleared = true } }
    self:render()
end

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

-- Records the solve, then shows the reveal after a short pause.
function App:onSolved(game)
    local progress, p, collection = self:progress(), game.puzzle, self:collection()
    local locked_before = collection:lockedPacks()
    progress:saveBoard(p.id, nil, 0, game:elapsed(), true)
    local result = progress:markSolved(p.id, game:elapsed())
    local unlocked = collection:newlyUnlocked(locked_before)
    self:flush()
    local data = {
        mode = "solved",
        puzzle = p,
        elapsed = game:elapsed(),
        best = progress:best(p.id),
        result = result,
        next = collection:nextAfter(p),
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
    local route = self.stack[#self.stack]
    if self.game and route and route.name == "game" then self.game:resume() end
end

return App
