--[[
Navigation controller: owns the plugin window (ui/host), the catalog and the
puzzle in play, and reacts to lifecycle events the window passes up.

This milestone only has the game screen; home, pack and reveal screens and
saved progress plug in here next.
]]

local UIManager = require("ui/uimanager")
local logger = require("logger")
local T = require("ffi/util").template
local _ = require("gettext")
local Catalog = require("piclogic/data/catalog")
local Game = require("piclogic/game")
local GameScreen = require("piclogic/ui/screens/game")
local Host = require("piclogic/ui/host")
local Icons = require("piclogic/ui/icons")

local App = {}
App.__index = App

-- Edits between ghost-clearing flashes of the board (a setting later).
App.DEGHOST_EVERY = 20

--- opts: ui (ReaderUI or FileManager), path (plugin directory)
function App.new(opts)
    Icons.init(opts.path)
    return setmetatable({ ui = opts.ui, path = opts.path }, App)
end

function App:catalog()
    if not self._catalog then
        self._catalog = Catalog.load(self.path .. "/piclogic/data/packs")
    end
    return self._catalog
end

function App:ensureWindow()
    if not self.host then
        self.host = Host:new{ app = self }
        UIManager:show(self.host)
    end
end

function App:openPuzzle(puzzle)
    self:ensureWindow()
    if self.game then self.game:pause() end
    local pack = self:catalog():pack(puzzle.pack_id)
    self.game = Game.new{ puzzle = puzzle }
    self.game:resume()
    self.host:setScreen(GameScreen.new{
        app = self,
        game = self.game,
        -- e.g. "Around the House · 7"
        title = T(_("%1 · %2"), pack.title, puzzle.number),
        deghost_every = App.DEGHOST_EVERY,
    })
end

--- Opens the first puzzle of the index-th pack (preview entry point).
function App:openPack(index)
    local pack = self:catalog().packs[index]
    if not pack then
        logger.warn("piclogic: no pack number", index)
        return
    end
    self:openPuzzle(pack.puzzles[1])
end

--- The next puzzle in the pack, else the first of the next pack, else close.
function App:nextPuzzle(puzzle)
    local catalog = self:catalog()
    local nxt = catalog:nextInPack(puzzle)
    if not nxt then
        for k, pack in ipairs(catalog.packs) do
            if pack.id == puzzle.pack_id and catalog.packs[k + 1] then
                nxt = catalog.packs[k + 1].puzzles[1]
            end
        end
    end
    if nxt then
        self:openPuzzle(nxt)
    else
        self:back()
    end
end

function App:back()
    self:close()
end

function App:close()
    if self.host then
        UIManager:close(self.host, "flashui")
    end
end

-- Lifecycle, called by the window ------------------------------------

function App:onClosed()
    if self.game then self.game:pause() end
    self.game = nil
    self.host = nil
    Icons.free()
end

function App:onSuspend()
    if self.game then self.game:pause() end
end

function App:onResume()
    if self.game then self.game:resume() end
end

function App:flush()
    -- Progress storage arrives with the next milestone.
end

function App:onMove(game, report) -- luacheck: ignore
    -- Saving after every move arrives with progress storage.
end

function App:onSolved(game) -- luacheck: ignore
    -- Recording the solve and the reveal screen arrive next milestone.
end

return App
