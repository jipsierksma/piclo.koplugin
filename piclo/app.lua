--[[
App controller: owns the plugin window (ui/host), the catalog, saved
progress and the game in play. Screens call it to move around; the window
passes lifecycle events (suspend, close) up to it.

Its methods come in three parts: this file (data, settings, lifecycle),
piclo/app/routes.lua (the screen stack and moving around) and
piclo/app/play.lua (the game in play and saving it).
]]

local UIManager = require("ui/uimanager")
local Catalog = require("piclo/data/catalog")
local Coach = require("piclo/coach")
local Collection = require("piclo/collection")
local Icons = require("piclo/ui/icons")
local L10n = require("piclo/l10n")
local Progress = require("piclo/storage/progress")
local _ = require("gettext")

local App = {}
App.__index = App

for __, part in ipairs({ "piclo/app/routes", "piclo/app/play" }) do
    for k, v in pairs(require(part)) do App[k] = v end
end

--- opts: ui (ReaderUI or FileManager), path (plugin dir), version, progress (tests)
function App.new(opts)
    -- Before anything builds text: pack titles are translated when loaded.
    L10n.load(opts.path, _)
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

--- The practice puzzles offered in How to play (see piclo/data/practice.lua).
function App:lessons()
    if not self._lessons then
        self._lessons = Coach.load(self.path .. "/piclo/data/practice.lua")
    end
    return self._lessons
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

function App:close()
    if self.host then
        UIManager:close(self.host, "flashui")
    end
end

-- Lifecycle, called by the window ------------------------------------

function App:onClosed()
    self:cancelReveal()
    if self.close_task then
        UIManager:unschedule(self.close_task)
        self.close_task = nil
    end
    self:stopGame()
    self.held_game = nil
    self:flush()
    self.stack = {}
    self.host = nil
    Icons.free()
end

function App:onSuspend()
    if self.game then self.game:pause() end
    self:flush()
end

-- The timer only runs while the board is actually in front of the player.
function App:playing()
    local route = self.stack[#self.stack]
    return self.game ~= nil and route ~= nil and route.name == "game"
end

--[[
Waking up: another window (e.g. a home-screen plugin) may have come up over
us, so only restart the clock when we're on top. Otherwise the next touch
on the board restarts it (onInput).
]]
function App:onResume()
    if self:playing() and UIManager:getTopmostVisibleWidget() == self.host then self.game:resume() end
end

--- Any gesture on our window: the player is here.
function App:onInput()
    if self:playing() then self.game:resume() end
end

return App
