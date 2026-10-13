--[[
Headless smoke test of the real plugin UI (see spec/ui_harness.lua):
launching, the collection, solving and the reveal, layouts, and play.
]]

local H = require("ui_harness")
local BB = require("ffi/blitbuffer")
local Cell = require("piclogic/model/cell")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local Game = require("piclogic/game")
local LuaSettings = require("luasettings")
local Screen = require("device").screen
local Theme = require("piclogic/ui/theme")
local UIManager = require("ui/uimanager")

local host, app
local function launch(...)
    host, app = H.launch(...)
    return host, app
end
local function play(...)
    local h, screen, game = H.play(...)
    host, app = H.host, H.app
    return h, screen, game
end
local top, point, gesture, tapRect = H.top, H.point, H.gesture, H.tapRect
local cellPoint, tapCell, gridBox = H.cellPoint, H.tapCell, H.gridBox
local solveByTapping, shot, clean = H.solveByTapping, H.shot, H.clean

describe("launching", function()
    it("registers one menu entry and a dispatcher action", function()
        launch()
        assert.is_not_nil(Dispatcher.actions.piclogic_open)
        assert.is_true(host.covers_fullscreen)
    end)

    it("shows how to play on the first run, then home", function()
        launch()
        assert.are.equal("help", top())
        assert.is_nil(host.screen.header.back)
        shot("help")
        clean()
        tapRect(host.screen.done_btn.rect)
        assert.are.equal("home", top())
        tapRect(host.screen.help_btn.rect)
        assert.are.equal("help", top())
        assert.is_not_nil(host.screen.header.back)
        assert.is_nil(host.screen.done_btn)
        tapRect(host.screen.header.back.rect)
        assert.is_nil(host.screen.card)
        shot("home_first_run")
        clean()
    end)

    it("goes straight home once help was seen", function()
        launch()
        app:close()
        launch(nil, nil, true)
        assert.are.equal("home", top())
    end)

    it("lists packs with the later ones locked", function()
        launch()
        app:back()
        assert.is_not_nil(host.screen.wordmark)
        local rows = host.screen.rows
        assert.are.equal(3, #rows)
        assert.is_true(rows[1].info.unlocked)
        assert.is_false(rows[2].info.unlocked)
        tapRect(rows[2].rect)
        assert.are.equal("home", top())
        tapRect(rows[1].rect)
        assert.are.equal("pack", top())
    end)
end)

describe("collection", function()
    it("shows a pack's tiles on one page and opens a puzzle", function()
        launch()
        app:back()
        tapRect(host.screen.rows[1].rect)
        local screen = host.screen
        assert.are.equal(1, screen.grid.pages)
        assert.are.equal(8, #screen.tiles)
        shot("pack_new")
        clean()
        tapRect(screen.tiles[3].rect)
        assert.are.equal("game", top())
        assert.are.equal(3, app.game.puzzle.number)
    end)

    it("saves a game when leaving and resumes it from the Continue card", function()
        launch()
        app:back()
        tapRect(host.screen.rows[1].rect)
        tapRect(host.screen.tiles[2].rect)
        tapCell(host.screen, 1, 1)
        tapCell(host.screen, 2, 2)
        app:back()
        assert.are.equal("pack", top())
        assert.is_not_nil(host.screen.tiles[2].cells)
        shot("pack_in_progress")
        app:back()
        local card = host.screen.card
        assert.is_not_nil(card)
        assert.are.equal(2, card.cont.puzzle.number)
        shot("home_continue")
        clean()
        tapRect(card.rect)
        assert.are.equal("game", top())
        assert.are.equal(Cell.FILLED, app.game:cell(1, 1))
        assert.are.equal(Cell.FILLED, app.game:cell(2, 2))
    end)

    it("keeps progress after closing and reopening the plugin", function()
        local _, screen = play(1, 4)
        tapCell(screen, 1, 1)
        host:handleEvent(Event:new("Close"))
        host:handleEvent(Event:new("Close"))
        assert.are.equal(0, #UIManager.stack)
        launch(nil, nil, true)
        assert.are.equal("home", top())
        assert.are.equal(4, host.screen.card.cont.puzzle.number)
        tapRect(host.screen.card.rect)
        assert.are.equal(Cell.FILLED, app.game:cell(1, 1))
    end)

    it("debounces saves during play and flushes on suspend", function()
        local _, screen = play(1, 1)
        local before = LuaSettings.files["/settings/piclogic.lua"]
        tapCell(screen, 1, 1)
        assert.are.equal(before, LuaSettings.files["/settings/piclogic.lua"])
        assert.are.equal(1, #UIManager.tasks)
        host:handleEvent(Event:new("Suspend"))
        local saved = LuaSettings.files["/settings/piclogic.lua"]
        assert.is_not_nil(saved.puzzles[app.game.puzzle.id].state)
        assert.are.equal(0, #UIManager.tasks)
    end)
end)

describe("solving", function()
    it("clears the crosses, then reveals the picture with a full flash", function()
        local _, screen, game = play(1, 1)
        solveByTapping(screen, game)
        assert.is_true(game.solved)
        assert.are.equal("game", top())
        assert.is_false(screen.board.show_crosses)
        UIManager:runScheduled()
        assert.are.equal("reveal", top())
        local flashed = false
        for _, r in ipairs(UIManager:takeRefreshes()) do
            if r.mode == "full" then flashed = true end
        end
        assert.is_true(flashed)
        local reveal = host.screen
        assert.are.same(gridBox(screen), reveal.box)
        -- a 5x5 grid is centered, and so is its picture
        assert.is_true(math.abs(reveal.box.x * 2 + reveal.box.w - Screen.w) <= 1)
        assert.is_true(reveal.secondary.rect.x < reveal.primary.rect.x)
        assert.are.equal(reveal.secondary.rect.y, reveal.primary.rect.y)
        assert.are.equal(game.puzzle.title, reveal.title.widget.text)
        assert.truthy(reveal.summary.widget.text:find("Solved in"))
        assert.are.equal("Next puzzle", reveal.primary.text)
        shot("reveal_portrait")
        clean()
        assert.is_true(app:progress():isSolved(game.puzzle.id))
        tapRect(reveal.primary.rect)
        assert.are.equal("game", top())
        assert.are.equal(2, app.game.puzzle.number)
    end)

    it("announces a newly unlocked pack", function()
        local _, screen, game = play(1, 5)
        local progress = app:progress()
        for k = 1, 4 do progress:markSolved(app:catalog().packs[1].puzzles[k].id, 10) end
        solveByTapping(screen, game)
        UIManager:runScheduled()
        assert.are.same({ "Around the House" }, host.screen.data.unlocked)
        shot("reveal_unlock")
        clean()
        tapRect(host.screen.secondary.rect)
        assert.are.equal("pack", top())
        app:back()
        assert.is_true(host.screen.rows[2].info.unlocked)
    end)

    it("drops a pending reveal when leaving during the pause", function()
        local _, screen, game = play(1, 1)
        solveByTapping(screen, game)
        app:back()
        assert.are.equal(0, #UIManager.tasks)
        assert.are.equal("home", top())
    end)

    it("shows a solved puzzle's picture from the collection and can replay it", function()
        launch()
        app:back()
        app:progress():markSolved(app:catalog().packs[1].puzzles[1].id, 42)
        tapRect(host.screen.rows[1].rect)
        assert.is_true(host.screen.tiles[1].solved)
        shot("pack_solved")
        tapRect(host.screen.tiles[1].rect)
        assert.are.equal("reveal", top())
        assert.are.equal("Play again", host.screen.primary.text)
        assert.are.equal("Best 0:42", host.screen.summary.widget.text)
        tapRect(host.screen.primary.rect)
        assert.are.equal("game", top())
        assert.is_true(app.game.board:isEmpty())
    end)
end)

describe("reveal placement", function()
    -- Oasis and a 6" screen in both orientations, plus a small 6" one.
    local sizes = { { 1264, 1680 }, { 1680, 1264 }, { 1072, 1448 }, { 1448, 1072 }, { 758, 1024 } }
    for _, size in ipairs(sizes) do
        it("draws every picture exactly on its grid at " .. size[1] .. "x" .. size[2], function()
            launch(size[1], size[2])
            local misplaced = {}
            for pi, pack in ipairs(app:catalog().packs) do
                for k = 1, #pack.puzzles do
                    local _, screen, game = play(pi, k, size[1], size[2])
                    local grid = gridBox(screen)
                    solveByTapping(screen, game)
                    UIManager:runScheduled()
                    assert.are.equal("reveal", top())
                    local box = host.screen.box
                    if box.x ~= grid.x or box.y ~= grid.y or box.w ~= grid.w or box.h ~= grid.h then
                        misplaced[#misplaced + 1] = game.puzzle.id
                    end
                    clean()
                end
            end
            assert.are.same({}, misplaced)
            if size[1] == 1680 then shot("reveal_landscape_solved") end
        end)
    end

    it("draws a collection picture where its board will be", function()
        launch()
        app:back()
        local p = app:catalog().packs[2].puzzles[1]
        app:progress():markSolved(p.id, 42)
        app:openPuzzle(p)
        assert.are.equal("reveal", top())
        host:handleEvent(Event:new("SetRotationMode", 1))
        assert.is_true(Screen.w > Screen.h)
        local box = host.screen.box
        clean()
        tapRect(host.screen.primary.rect)
        assert.are.equal("game", top())
        assert.are.same(gridBox(host.screen), box)
    end)
end)

describe("layouts", function()
    for _, size in ipairs({ { 1264, 1680 }, { 1680, 1264 }, { 1072, 1448 }, { 758, 1024 }, { 600, 800 } }) do
        it("draws every screen in bounds at " .. size[1] .. "x" .. size[2], function()
            play(3, 1, size[1], size[2])
            assert.is_not_nil(host.screen.board.geom)
            clean()
            app:back()
            local home = host.screen
            local last = home.rows[#home.rows].rect
            assert.is_true(last.y + last.h <= home.help_btn.rect.y)
            if home.wordmark then
                assert.is_true(home.wordmark.y >= Theme.header_h)
            end
            if size[1] == 1680 then shot("home_landscape_game") end
            clean()
            app:showHelp()
            clean()
            app:back()
            app:showPack("woods")
            clean()
            app:progress():markSolved("woods/" .. app:catalog().packs[3].puzzles[1].id:match("/(.*)"), 99)
            app:openPuzzle(app:catalog().packs[3].puzzles[1])
            assert.are.equal("reveal", top())
            clean()
            if size[1] == 1680 then shot("reveal_landscape") end
        end)
    end

    it("re-lays out a screen on rotation", function()
        launch()
        app:back()
        host:handleEvent(Event:new("SetRotationMode", 1))
        assert.is_true(Screen.w > Screen.h)
        shot("home_landscape")
        clean()
    end)
end)

describe("playing", function()
    it("shows a 15x15 board on a Kindle Oasis screen", function()
        local _, screen, game = play(3, 1)
        assert.are.equal(15, game.puzzle.w)
        local g = screen.board.geom
        assert.is_true(g.cell >= Theme.min_cell)
        assert.is_true(g.board.y >= Theme.header_h)
        assert.is_true(g.board.y + g.board.h <= screen.toolbar.rect.y)
        shot("game_15_portrait")
        clean()
    end)

    it("fills a tapped cell and refreshes only small regions directly", function()
        local _, screen, game = play(2, 1)
        tapCell(screen, 1, 1)
        assert.are.equal(Cell.FILLED, game:cell(1, 1))
        local x, y = cellPoint(screen, 1, 1)
        assert.are.equal(0, Screen.bb:get(x, y))
        local refreshes = UIManager:takeRefreshes()
        assert.is_true(#refreshes >= 3)
        for _, r in ipairs(refreshes) do
            assert.is_nil(r.widget)
            assert.are.equal("ui", r.mode)
            assert.is_true(r.region.w * r.region.h < Screen.w * Screen.h / 10)
        end
    end)

    it("lays a dragged line as one undo step", function()
        local _, screen, game = play(2, 1)
        local sx, sy = cellPoint(screen, 2, 1)
        gesture("pan", sx + 30, sy, { start_pos = point(sx, sy) })
        gesture("pan", sx + 60, sy + 5, { start_pos = point(sx, sy) })
        gesture("pan_release", cellPoint(screen, 2, 5))
        for c = 1, 5 do assert.are.equal(Cell.FILLED, game:cell(2, c)) end
        tapRect(screen.toolbar.undo_btn.rect)
        for c = 1, 5 do assert.are.equal(Cell.UNKNOWN, game:cell(2, c)) end
        assert.is_false(screen.toolbar.undo_btn.enabled)
        tapRect(screen.toolbar.redo_btn.rect)
        assert.are.equal(Cell.FILLED, game:cell(2, 3))
    end)

    it("ignores a drag that starts off the board", function()
        local _, screen, game = play(2, 1)
        gesture("pan", 5, 5, { start_pos = point(5, 5) })
        gesture("pan_release", cellPoint(screen, 2, 5))
        assert.is_true(game.board:isEmpty())
    end)

    it("lays a flicked line from the swipe's start", function()
        local _, screen, game = play(2, 1)
        local x, y = cellPoint(screen, 4, 1)
        gesture("swipe", x, y, { end_pos = point(cellPoint(screen, 4, 4)), direction = "east" })
        for c = 1, 4 do assert.are.equal(Cell.FILLED, game:cell(4, c)) end
    end)

    it("crosses with a hold and highlights the held cell first", function()
        local _, screen, game = play(2, 1)
        gesture("hold", cellPoint(screen, 3, 3))
        assert.are.equal("fast", UIManager:takeRefreshes()[1].mode)
        gesture("hold_release", cellPoint(screen, 3, 6))
        for c = 3, 6 do assert.are.equal(Cell.CROSSED, game:cell(3, c)) end
        assert.are.equal(Game.TOOL_FILL, game.tool)
    end)

    it("switches tools with the segmented control and the page keys", function()
        local _, screen, game = play(2, 1)
        tapRect(screen.toolbar.tools.segs[2])
        assert.are.equal(Game.TOOL_CROSS, game.tool)
        tapCell(screen, 1, 2)
        assert.are.equal(Cell.CROSSED, game:cell(1, 2))
        host:handleEvent(Event:new("PageKey", nil, { key = "RPgFwd" }))
        assert.are.equal(Game.TOOL_FILL, game.tool)
        shot("game_10_portrait")
    end)

    it("pauses the timer on suspend and resumes after", function()
        local _, _, game = play(1, 1)
        host:handleEvent(Event:new("Suspend"))
        assert.is_nil(game.running_since)
        host:handleEvent(Event:new("Resume"))
        assert.is_not_nil(game.running_since)
    end)

    it("goes back from the game to where it came from", function()
        play(1, 1)
        tapRect(host.screen.header.back.rect)
        assert.are.equal("home", top())
        tapRect(host.screen.header.back.rect)
        assert.are.equal(0, #UIManager.stack)
        assert.is_nil(app.host)
    end)
end)

describe("icons", function()
    it("has a file for every icon the UI names", function()
        local files = { "piclogic/ui/screens/game.lua", "piclogic/ui/screens/home.lua",
            "piclogic/ui/components/header_bar.lua" }
        for _, file in ipairs(files) do
            local src = io.open(file):read("*a")
            for name in src:gmatch('icon = "([%w_]+)"') do
                assert(io.open("piclogic/icons/" .. name .. ".svg"), "missing icon " .. name)
            end
            for name in src:gmatch('Icons%.path%("([%w_]+)"') do
                assert(io.open("piclogic/icons/" .. name .. ".svg"), "missing icon " .. name)
            end
            for name in src:gmatch('Icons%.paint%(bb, "([%w_]+)"') do
                assert(io.open("piclogic/icons/" .. name .. ".svg"), "missing icon " .. name)
            end
        end
    end)
end)
