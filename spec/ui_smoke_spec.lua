--[[
Headless smoke test of the real plugin UI against the stand-ins in
spec/kostub/. Opens puzzles through main.lua's menu entries and drives them
with synthetic gestures. Set PICLOGIC_SHOTS=<dir> to also write PGM
screenshots for eyeballing the layout.
]]

package.path = "./spec/kostub/?.lua;" .. package.path

local warnings = {}
package.loaded["logger"] = {
    dbg = function() end,
    info = function() end,
    warn = function(...)
        local parts = {}
        for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
        warnings[#warnings + 1] = table.concat(parts, " ")
    end,
    err = function() end,
}

local BB = require("ffi/blitbuffer")
local Cell = require("piclogic/model/cell")
local Event = require("ui/event")
local Game = require("piclogic/game")
local Geom = require("ui/geometry")
local Screen = require("device").screen
local Theme = require("piclogic/ui/theme")
local UIManager = require("ui/uimanager")

local SHOTS = os.getenv("PICLOGIC_SHOTS")

local function setScreen(w, h)
    Screen.w, Screen.h, Screen.rotation = w, h, 0
    Screen.bb = BB.new(w, h)
    Theme.update()
end

local PicLogic = dofile("main.lua")
local plugin, menu

local function open(index, w, h)
    setScreen(w or 1264, h or 1680)
    UIManager:reset()
    BB.out_of_bounds = 0
    warnings = {}
    local ui = { menu = { registerToMainMenu = function() end } }
    plugin = PicLogic:new{ ui = ui, path = "." }
    menu = {}
    plugin:addToMainMenu(menu)
    menu.piclogic.sub_item_table[index].callback()
    UIManager:repaint()
    UIManager:takeRefreshes()
    local host = UIManager.stack[1]
    return host, host.screen, plugin.app.game
end

local function cellPoint(screen, r, c)
    local g = screen.board.geom
    return g.grid_x + math.floor((c - 0.5) * g.cell), g.grid_y + math.floor((r - 0.5) * g.cell)
end

local function point(x, y) return Geom:new{ x = x, y = y } end

local function gesture(host, kind, x, y, extra)
    local ev = { ges = kind, pos = point(x, y) }
    for k, v in pairs(extra or {}) do ev[k] = v end
    host:onGesture(ev)
end

local function tapCell(host, screen, r, c)
    gesture(host, "tap", cellPoint(screen, r, c))
end

local function tapRect(host, rect)
    gesture(host, "tap", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))
end

local function shot(name)
    if SHOTS then Screen.bb:writePGM(SHOTS .. "/" .. name .. ".pgm") end
end

describe("opening", function()
    it("shows a 15x15 board on a Kindle Oasis screen without overflow", function()
        local host, screen, game = open(3)
        assert.are.equal(15, game.puzzle.w)
        assert.is_true(host.covers_fullscreen)
        local g = screen.board.geom
        assert.is_true(g.cell >= Theme.min_cell)
        assert.is_true(g.board.y >= Theme.header_h)
        assert.is_true(g.board.y + g.board.h <= screen.toolbar.y)
        assert.are.equal(0, BB.out_of_bounds)
        assert.are.same({}, warnings)
        shot("game_15_portrait")
    end)

    for _, size in ipairs({ { 1072, 1448 }, { 758, 1024 }, { 600, 800 } }) do
        it("fits 15x15 on " .. size[1] .. "x" .. size[2], function()
            local _, screen = open(3, size[1], size[2])
            assert.is_not_nil(screen.board.geom)
            assert.are.equal(0, BB.out_of_bounds)
            assert.are.same({}, warnings)
        end)
    end
end)

describe("playing", function()
    it("fills a tapped cell and refreshes only small regions directly", function()
        local host, screen, game = open(2)
        tapCell(host, screen, 1, 1)
        assert.are.equal(Cell.FILLED, game:cell(1, 1))
        local x, y = cellPoint(screen, 1, 1)
        assert.are.equal(0, Screen.bb:get(x, y))
        local refreshes = UIManager:takeRefreshes()
        assert.is_true(#refreshes >= 3)
        local screen_area = Screen.w * Screen.h
        for _, r in ipairs(refreshes) do
            assert.is_nil(r.widget)
            assert.are.equal("ui", r.mode)
            assert.is_true(r.region.w * r.region.h < screen_area / 10)
        end
    end)

    it("lays a dragged line as one undo step", function()
        local host, screen, game = open(2)
        local sx, sy = cellPoint(screen, 2, 1)
        gesture(host, "pan", sx + 30, sy, { start_pos = point(sx, sy) })
        gesture(host, "pan", sx + 60, sy + 5, { start_pos = point(sx, sy) })
        gesture(host, "pan_release", cellPoint(screen, 2, 5))
        for c = 1, 5 do assert.are.equal(Cell.FILLED, game:cell(2, c)) end
        assert.is_true(screen.undo_btn.enabled)
        tapRect(host, screen.undo_btn.rect)
        for c = 1, 5 do assert.are.equal(Cell.UNKNOWN, game:cell(2, c)) end
        assert.is_false(screen.undo_btn.enabled)
        tapRect(host, screen.redo_btn.rect)
        assert.are.equal(Cell.FILLED, game:cell(2, 3))
    end)

    it("ignores a drag that starts off the board", function()
        local host, screen, game = open(2)
        gesture(host, "pan", 5, 5, { start_pos = point(5, 5) })
        gesture(host, "pan_release", cellPoint(screen, 2, 5))
        assert.is_true(game.board:isEmpty())
    end)

    it("lays a flicked line from the swipe's start", function()
        local host, screen, game = open(2)
        local x, y = cellPoint(screen, 4, 1)
        gesture(host, "swipe", x, y, { end_pos = point(cellPoint(screen, 4, 4)), direction = "east" })
        for c = 1, 4 do assert.are.equal(Cell.FILLED, game:cell(4, c)) end
    end)

    it("crosses with a hold and highlights the held cell first", function()
        local host, screen, game = open(2)
        gesture(host, "hold", cellPoint(screen, 3, 3))
        local refreshes = UIManager:takeRefreshes()
        assert.are.equal("fast", refreshes[1].mode)
        gesture(host, "hold_release", cellPoint(screen, 3, 6))
        for c = 3, 6 do assert.are.equal(Cell.CROSSED, game:cell(3, c)) end
        assert.are.equal(Game.TOOL_FILL, game.tool)
    end)

    it("switches tools with the segmented control and the page keys", function()
        local host, screen, game = open(2)
        tapRect(host, screen.tools.segs[2])
        assert.are.equal(Game.TOOL_CROSS, game.tool)
        tapCell(host, screen, 1, 2)
        assert.are.equal(Cell.CROSSED, game:cell(1, 2))
        host:handleEvent(Event:new("PageKey"))
        assert.are.equal(Game.TOOL_FILL, game.tool)
        shot("game_10_portrait")
    end)
end)

describe("lifecycle", function()
    it("re-lays out in landscape with the toolbar as a right rail", function()
        local host, screen = open(3)
        host:handleEvent(Event:new("SetRotationMode", 1))
        assert.is_true(Screen.w > Screen.h)
        assert.is_true(screen.landscape)
        assert.is_true(screen.toolbar.x > screen.board.geom.board.x + screen.board.geom.board.w)
        UIManager:repaint()
        assert.are.equal(0, BB.out_of_bounds)
        assert.are.same({}, warnings)
        shot("game_15_landscape")
    end)

    it("pauses the timer on suspend and resumes after", function()
        local host, _, game = open(1)
        host:handleEvent(Event:new("Suspend"))
        assert.is_nil(game.running_since)
        host:handleEvent(Event:new("Resume"))
        assert.is_not_nil(game.running_since)
    end)

    it("closes on the back key and frees the window", function()
        local host = open(1)
        host:handleEvent(Event:new("Close"))
        assert.are.equal(0, #UIManager.stack)
        assert.is_nil(plugin.app.host)
        assert.is_nil(plugin.app.game)
    end)

    it("closes with the header back button", function()
        local host, screen = open(1)
        tapRect(host, screen.header.back.rect)
        assert.are.equal(0, #UIManager.stack)
    end)
end)

describe("solving", function()
    it("shows the bare picture, flashes, then moves to the next puzzle", function()
        local host, screen, game = open(1)
        local p = game.puzzle
        for r = 1, p.h do
            for c = 1, p.w do
                if p:isFilled(r, c) then tapCell(host, screen, r, c) end
            end
        end
        assert.is_true(game.solved)
        local flashed = false
        for _, r in ipairs(UIManager:takeRefreshes()) do
            if r.mode == "full" then flashed = true end
        end
        assert.is_true(flashed)
        assert.are.equal(p.title, screen.header.title)
        UIManager:repaint()
        shot("game_5_solved")
        -- an empty cell shows no cross once solved
        for r = 1, p.h do
            for c = 1, p.w do
                if not p:isFilled(r, c) then
                    local ix, iy, iw, ih = screen.board.geom:cellInner(r, c)
                    for yy = iy, iy + ih - 1, 3 do
                        for xx = ix, ix + iw - 1, 3 do
                            assert.are.equal(0xFF, Screen.bb:get(xx, yy))
                        end
                    end
                end
            end
        end
        tapCell(host, screen, 1, 1)
        assert.are.equal(2, plugin.app.game.puzzle.number)
    end)
end)

describe("icons", function()
    it("has a file for every icon the UI names", function()
        for _, file in ipairs({ "piclogic/ui/screens/game.lua", "piclogic/ui/components/header_bar.lua" }) do
            local src = io.open(file):read("*a")
            for name in src:gmatch('icon = "([%w_]+)"') do
                assert(io.open("piclogic/icons/" .. name .. ".svg"), "missing icon " .. name)
            end
        end
    end)
end)
