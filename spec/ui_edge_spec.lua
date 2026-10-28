--[[
Headless specs for edge cases found on the device or reasoned out after it
(see spec/ui_harness.lua): another window covering Piclo, puzzles changing
under saved progress, buttons-only devices, double taps, rotating at awkward
moments, other screen sizes, a failing disk and longer translations.
]]

local H = require("ui_harness")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local Host = require("piclo/ui/host")
local LuaSettings = require("luasettings")
local Progress = require("piclo/storage/progress")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local gettext = require("gettext")
local time = require("ui/time")

local tapRect, tapCell, shot, clean, top = H.tapRect, H.tapCell, H.shot, H.clean, H.top

-- A full-screen window over Piclo, as a home-screen plugin shows on wake.
local function cover()
    local w = { covers_fullscreen = true, paintTo = function() end, handleEvent = function() end }
    UIManager:show(w)
    return w
end

describe("covered by another window", function()
    it("keeps the clock stopped after waking until the board is touched again", function()
        local _, screen, game = H.play(2, 1)
        tapCell(screen, 1, 1)
        local w = cover()
        H.host:handleEvent(Event:new("Suspend"))
        H.host:handleEvent(Event:new("Resume"))
        assert.is_nil(game.running_since)
        UIManager:close(w)
        tapCell(screen, 2, 2)
        assert.is_not_nil(game.running_since)
    end)

    it("still restarts the clock on waking when Piclo is on top", function()
        local _, _, game = H.play(2, 1)
        H.host:handleEvent(Event:new("Suspend"))
        H.host:handleEvent(Event:new("Resume"))
        assert.is_not_nil(game.running_since)
    end)
end)

describe("puzzles changing under saved progress", function()
    -- Solves the first n of First Steps and reopens the plugin, as after an update.
    local function solvedThenReopened(n)
        local _, app = H.launch()
        app:back()
        for k = 1, n do app:progress():markSolved(app:catalog().packs[1].puzzles[k].id, 10) end
        app:collection():recordUnlocks()
        app:flush()
        app:close()
        return H.launch(nil, nil, true)
    end

    it("keeps a pack unlocked when a puzzle that opened it is replaced", function()
        local _, app = solvedThenReopened(3)
        local catalog = app:catalog()
        local starter = catalog.packs[1]
        -- An update swaps the first drawing for a new one with a new id.
        local gone = table.remove(starter.puzzles, 1)
        catalog.by_puzzle[gone.id] = nil
        app._collection = nil
        assert.are.equal(2, app:collection():solvedIn("starter"))
        assert.is_true(app:collection():packInfo(catalog.packs[2]).unlocked)
        app:showPacks()
        assert.is_true(H.host.screen.rows[2].info.unlocked)
        clean()
    end)

    it("still locks packs again after resetting all progress", function()
        local _, app = solvedThenReopened(3)
        app:resetProgress()
        assert.is_false(app:collection():packInfo(app:catalog().packs[2]).unlocked)
    end)

    it("opens home normally when the puzzle to continue no longer exists", function()
        local _, app = H.launch()
        app:back()
        app:progress():saveBoard("starter/retired", { 1, 1 }, 25, 30)
        app:progress():setLastPuzzle("starter/retired")
        app:render()
        assert.are.equal("start", H.host.screen.spot.kind)
        clean()
    end)
end)

describe("devices without a touchscreen", function()
    it("offers no menu entry and no gesture action", function()
        local touch = Device.isTouchDevice
        Device.isTouchDevice = function() return false end
        Dispatcher.actions.piclo_open = nil
        local registered = false
        local Piclo = dofile("main.lua")
        local ok, err = pcall(function()
            Piclo:new{ ui = { menu = { registerToMainMenu = function() registered = true end } }, path = "." }
        end)
        Device.isTouchDevice = touch
        assert.is_true(ok, tostring(err))
        assert.is_false(registered)
        assert.is_nil(Dispatcher.actions.piclo_open)
    end)
end)

describe("double taps", function()
    local function withGuard(fn)
        local _, app = H.launch()
        app:back()
        Host.TAP_GUARD = 0.35
        time.t = 100
        local ok, err = pcall(fn, app)
        Host.TAP_GUARD = 0
        assert(ok, err)
    end

    it("drops a second tap that lands on the screen the first one opened", function()
        withGuard(function()
            tapRect(H.host.screen.packs_row.rect)
            assert.are.equal("packs", top())
            time.t = 100.15
            tapRect(H.host.screen.rows[1].rect)
            assert.are.equal("packs", top())
            time.t = 101
            tapRect(H.host.screen.rows[1].rect)
            assert.are.equal("pack", top())
        end)
    end)

    it("waits a moment before closing, so a second tap can't reach the file browser", function()
        withGuard(function(app)
            time.t = 102
            tapRect(H.host.screen.close_row.rect)
            assert.are.equal(1, #UIManager.stack)
            time.t = 102.1
            tapRect(H.host.screen.close_row.rect)
            assert.are.equal(1, #UIManager.stack)
            UIManager:runScheduled()
            assert.are.equal(0, #UIManager.stack)
            assert.is_nil(app.host)
        end)
    end)

    it("reopens on top when opened again while a close is pending", function()
        withGuard(function(app)
            time.t = 103
            tapRect(H.host.screen.close_row.rect)
            H.plugin:onPicloOpen()
            UIManager:runScheduled()
            assert.are.equal(1, #UIManager.stack)
            assert.are.equal(app.host, UIManager:getTopmostVisibleWidget())
        end)
    end)
end)

describe("rotating at awkward moments", function()
    local function rotate()
        H.host:handleEvent(Event:new("SetRotationMode", (Screen.rotation + 1) % 4))
    end

    it("re-lays out an open menu", function()
        local _, screen = H.play(2, 1)
        tapRect(screen.header.right.rect)
        rotate()
        local r = H.host.sheet.rect
        assert.is_true(r.x >= 0 and r.y >= 0 and r.x + r.w <= Screen.w and r.y + r.h <= Screen.h)
        clean()
    end)

    it("reveals in the new orientation when rotated during the pause before it", function()
        local _, screen, game = H.play(1, 1)
        H.solveByTapping(screen, game)
        rotate()
        UIManager:runScheduled()
        assert.are.equal("reveal", top())
        local b = H.host.screen.box
        assert.is_true(b.x >= 0 and b.y >= 0 and b.x + b.w <= Screen.w and b.y + b.h <= Screen.h)
        clean()
    end)

    it("keeps the new picture marked", function()
        local _, screen, game = H.play(1, 1)
        H.solveByTapping(screen, game)
        UIManager:runScheduled()
        tapRect(H.host.screen.primary.rect)
        rotate()
        local pack = H.host.screen
        assert.are.equal(game.puzzle.id, pack.marked)
        for _, tile in ipairs(pack.tiles) do
            assert.is_true(tile.caption_rect.y + tile.caption_rect.h <= Screen.h)
        end
        clean()
    end)
end)

describe("other screen sizes", function()
    -- Kindle Scribe and Kobo Elipsa sized screens, both ways round, and a small 4:3 one.
    for _, size in ipairs({ { 1860, 2480 }, { 2480, 1860 }, { 1404, 1872 }, { 1872, 1404 }, { 480, 640 } }) do
        it("draws home, packs, a collection after a solve and settings at " .. size[1] .. "x" .. size[2], function()
            local _, screen, game = H.play(1, 1, size[1], size[2])
            H.solveByTapping(screen, game)
            UIManager:runScheduled()
            clean()
            tapRect(H.host.screen.primary.rect)
            assert.are.equal("pack", top())
            clean()
            H.app.stack = { { name = "home" } }
            H.app:render()
            local home = H.host.screen
            local last = home.rows[#home.rows].rect
            assert.is_true(last.y + last.h <= size[2])
            clean()
            H.app:showPacks()
            clean()
            H.app:back()
            H.app:showSettings()
            clean()
            H.app:showHelp()
            clean()
        end)
    end
end)

describe("a disk that can't be written", function()
    it("keeps playing and saves on a later try", function()
        local data, fail = {}, true
        local store = {
            readSetting = function(_, k) return data[k] end,
            saveSetting = function(_, k, v) data[k] = v end,
            flush = function() if fail then error("read-only file system") end end,
        }
        local progress = Progress.new(store)
        progress:markSolved("starter/mug", 10)
        H.warnings = {}
        assert.is_false(progress:flush())
        assert.is_true(progress.dirty)
        assert.are.equal(1, #H.warnings)
        fail = false
        assert.is_true(progress:flush())
        assert.is_false(progress.dirty)
    end)

    it("doesn't crash the app when saving on close fails", function()
        local _, screen = H.play(2, 1)
        tapCell(screen, 1, 1)
        local flush = LuaSettings.flush
        LuaSettings.flush = function() error("disk full") end
        local ok = pcall(function() H.host:handleEvent(Event:new("Close")) end)
        LuaSettings.flush = flush
        assert.is_true(ok)
    end)
end)

describe("longer translations", function()
    -- Every word twice as long, about German length; %1-style slots stay intact.
    local function longer(s)
        return (s:gsub("(%a+)", "%1%1"))
    end

    for _, size in ipairs({ { 1264, 1680 }, { 1680, 1264 }, { 600, 800 } }) do
        it("keeps every screen in bounds at " .. size[1] .. "x" .. size[2], function()
            gettext.translate = longer
            local ok, err = pcall(function()
                local _, screen = H.play(2, 1, size[1], size[2])
                tapCell(screen, 1, 1)
                clean()
                tapRect(screen.header.right.rect)
                clean()
                H.host:closeSheet()
                H.app:back()
                local home = H.host.screen
                assert.are.equal("continue", home.spot.kind)
                clean()
                H.app:showPacks()
                clean()
                H.app:back()
                H.app:showSettings()
                clean()
                H.app:back()
                H.app:showHelp()
                clean()
                shot("long_text_help_" .. size[1])
            end)
            gettext.translate = nil
            assert(ok, err)
        end)
    end
end)

describe("the longest clues", function()
    -- 15x15 with 8 numbers in every odd row and column: as long as clues get.
    local function worstCase()
        local Puzzle = require("piclo/model/puzzle")
        local rows = {}
        for r = 1, 15 do rows[r] = r % 2 == 1 and "#.#.#.#.#.#.#.#" or "..............." end
        local p = assert(Puzzle.new({ id = "woods/worst", rows = rows }))
        p.pack_id, p.number, p.title = "woods", 99, "Worst case"
        return p
    end

    local sizes = { { 1264, 1680 }, { 1680, 1264 }, { 1072, 1448 }, { 758, 1024 }, { 600, 800 }, { 800, 600 } }
    for _, size in ipairs(sizes) do
        it("fit beside and above the grid at " .. size[1] .. "x" .. size[2], function()
            local _, app = H.launch(size[1], size[2])
            app:back()
            local p = worstCase()
            assert.are.equal(8, #p.row_clues[1])
            app:openPuzzle(p)
            local g = H.host.screen.board.geom
            assert.is_not_nil(g)
            -- The clue gutters hold all 8 numbers inside the screen.
            assert.is_true(g.board.x >= 0 and g.board.y >= 0)
            assert.is_true(g.grid_x + g.cols * g.cell <= size[1])
            assert.is_true(g.grid_y + g.rows * g.cell <= size[2])
            shot("worst_clues_" .. size[1] .. "x" .. size[2])
            clean()
        end)
    end
end)

describe("night mode", function()
    it("paints finished drawings pre-inverted, on white, so they keep their tones", function()
        local Picture = require("piclo/ui/picture")
        local BB = require("ffi/blitbuffer")
        local Puzzle = require("piclo/model/puzzle")
        local p = assert(Puzzle.new({ id = "x/dot", rows = { "#.", ".." } }))
        local bb = BB.new(20, 20)
        Screen.night_mode = true
        local ok, err = pcall(function()
            Picture.paint(bb, p, { x = 0, y = 0, w = 20, h = 20 })
            -- KOReader inverts the screen once more: black shows black, the
            -- empty part of the picture white, as in day mode.
            assert.are.equal(0xFF, bb:get(2, 2))
            assert.are.equal(0x00, bb:get(15, 15))
            -- A board in play is left as it is.
            Picture.paint(bb, p, { x = 0, y = 0, w = 20, h = 20 }, { cells = { 1, 0, 0, 0 } })
            assert.are.equal(0x00, bb:get(2, 2))
        end)
        Screen.night_mode = nil
        assert(ok, err)
    end)
end)
