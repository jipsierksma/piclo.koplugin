--[[
Harness for the headless UI specs: runs the real plugin against the
stand-ins in spec/kostub/, launched through main.lua's menu entry and
driven with synthetic gestures. Set PICLO_SHOTS=<dir> to also write PGM
screenshots for eyeballing layouts.

H.host, H.app and H.plugin are the window, app and plugin instance of the
latest launch.
]]

package.path = "./spec/kostub/?.lua;" .. package.path

local H = { warnings = {} }

-- Capture warnings. Patch the logger in place, so modules that already hold
-- a reference to it report here too.
local logger = package.loaded["logger"] or {}
package.loaded["logger"] = logger
logger.dbg = function() end
logger.info = function() end
logger.err = function() end
logger.warn = function(...)
    local parts = {}
    for __, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
    H.warnings[#H.warnings + 1] = table.concat(parts, " ")
end

local BB = require("ffi/blitbuffer")
local Cell = require("piclo/model/cell")
local Geom = require("ui/geometry")
local LuaSettings = require("luasettings")
local Screen = require("device").screen
local Theme = require("piclo/ui/theme")
local UIManager = require("ui/uimanager")

local SHOTS = os.getenv("PICLO_SHOTS")
local Piclo = dofile("main.lua")

function H.setScreen(w, h)
    Screen.w, Screen.h, Screen.rotation = w, h, 0
    Screen.bb = BB.new(w, h)
    Theme.update()
end

function H.settle()
    UIManager:repaint()
    UIManager:takeRefreshes()
end

--- Starts the plugin as from the menu. keep_disk keeps saved progress.
function H.launch(w, h, keep_disk)
    H.setScreen(w or 1264, h or 1680)
    UIManager:reset()
    BB.out_of_bounds = 0
    H.warnings = {}
    if not keep_disk then LuaSettings.files = {} end
    local menu = {}
    local plugin = Piclo:new{ ui = { menu = { registerToMainMenu = function() end } }, path = ".",
        version = "0.4.0" }
    plugin:addToMainMenu(menu)
    menu.piclo.callback()
    H.settle()
    H.host, H.app, H.plugin = UIManager.stack[1], plugin.app, plugin
    return H.host, H.app
end

function H.top() return H.app.stack[#H.app.stack].name end

--- Launches past the first-run help and opens a puzzle directly.
function H.play(pack_index, puzzle_index, w, h)
    H.launch(w, h)
    if H.top() == "help" then H.app:back() end
    H.app:openPuzzle(H.app:catalog().packs[pack_index].puzzles[puzzle_index or 1])
    H.settle()
    return H.host, H.host.screen, H.app.game
end

function H.point(x, y) return Geom:new{ x = x, y = y } end

function H.gesture(kind, x, y, extra)
    local ev = { ges = kind, pos = H.point(x, y) }
    for k, v in pairs(extra or {}) do ev[k] = v end
    H.host:onGesture(ev)
end

function H.tapRect(rect)
    H.gesture("tap", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))
end

function H.cellPoint(screen, r, c)
    local g = screen.board.geom
    return g.grid_x + math.floor((c - 0.5) * g.cell), g.grid_y + math.floor((r - 0.5) * g.cell)
end

function H.tapCell(screen, r, c) H.gesture("tap", H.cellPoint(screen, r, c)) end

--- The game's grid as a picture box: where the reveal must draw.
function H.gridBox(screen)
    local g = screen.board.geom
    return { x = g.grid_x, y = g.grid_y, w = g.cols * g.cell, h = g.rows * g.cell }
end

function H.solveByTapping(screen, game)
    local p = game.puzzle
    for r = 1, p.h do
        for c = 1, p.w do
            if p:isFilled(r, c) and game:cell(r, c) ~= Cell.FILLED then H.tapCell(screen, r, c) end
        end
    end
end

function H.shot(name)
    UIManager:repaint()
    if SHOTS then Screen.bb:writePGM(SHOTS .. "/" .. name .. ".pgm") end
end

--- Asserts the last screen drew in bounds and logged no warnings.
function H.clean()
    UIManager:repaint()
    assert.are.equal(0, BB.out_of_bounds)
    assert.are.same({}, H.warnings)
end

return H
