--[[
Headless smoke test of the real plugin UI (see spec/ui_harness.lua):
launching, the collection, solving and the reveal, layouts, and play.
]]

local H = require("ui_harness")
local BB = require("ffi/blitbuffer")
local Cell = require("piclo/model/cell")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local Game = require("piclo/game")
local LuaSettings = require("luasettings")
local Screen = require("device").screen
local Theme = require("piclo/ui/theme")
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

--- From the title screen to the Packs screen.
local function openPacks()
    tapRect(host.screen.packs_row.rect)
    assert.are.equal("packs", top())
end

describe("launching", function()
    it("registers one menu entry and a dispatcher action", function()
        launch()
        assert.is_not_nil(Dispatcher.actions.piclo_open)
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
        tapRect(host.screen.help_row.rect)
        assert.are.equal("help", top())
        assert.is_not_nil(host.screen.header.back)
        assert.is_nil(host.screen.done_btn)
        tapRect(host.screen.header.back.rect)
        assert.are.equal("Start", host.screen.primary.text)
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
        assert.is_not_nil(host.screen.logo)
        openPacks()
        local rows = host.screen.rows
        assert.are.equal(3, #rows)
        assert.is_true(rows[1].info.unlocked)
        assert.is_false(rows[2].info.unlocked)
        assert.are.equal("0 of 23 solved", host.screen.summary.widget.text)
        shot("packs")
        clean()
        tapRect(rows[2].rect)
        assert.are.equal("packs", top())
        tapRect(rows[1].rect)
        assert.are.equal("pack", top())
    end)
end)

describe("quitting", function()
    it("closes its window and saves when the file manager closes", function()
        local _, screen, game = play(2, 1)
        tapCell(screen, 1, 1)
        local id = game.puzzle.id
        H.plugin:handleEvent(Event:new("CloseWidget"))
        assert.are.equal(0, #UIManager.stack)
        assert.is_nil(app.host)
        assert.is_true(app:progress():inProgress(id))
        local saved = LuaSettings.files["/settings/piclo.lua"]
        assert.truthy(saved and saved.puzzles[id])
    end)

    it("comes back on top when opened while another window covers it", function()
        local _, screen, game = play(2, 1)
        tapCell(screen, 1, 1)
        local id = game.puzzle.id
        -- What a home-screen plugin does when the device wakes.
        local cover = { covers_fullscreen = true, paintTo = function() end, handleEvent = function() end }
        UIManager:show(cover)
        H.plugin:onPicloOpen()
        local hosts = 0
        for _, w in ipairs(UIManager.stack) do
            if w.name == "piclo" then hosts = hosts + 1 end
        end
        assert.are.equal(1, hosts)
        assert.are.equal(app.host, UIManager:getTopmostVisibleWidget())
        assert.are.equal("home", top())
        assert.are.equal(id, app.host.screen.spot.puzzle.id)
        assert.is_true(app:progress():inProgress(id))
    end)

    it("does nothing when its window isn't open", function()
        launch()
        app:close()
        H.plugin:handleEvent(Event:new("CloseWidget"))
        assert.are.equal(0, #UIManager.stack)
    end)
end)

describe("collection", function()
    it("shows a pack's tiles on one page and opens a puzzle", function()
        launch()
        app:back()
        openPacks()
        tapRect(host.screen.rows[1].rect)
        local screen = host.screen
        assert.are.equal(1, screen.grid.pages)
        assert.are.equal(4, #screen.tiles)
        -- Unplayed tiles: "???" in the box, the number underneath.
        assert.are.equal("3", screen.tiles[3].caption.widget.text)
        assert.are.equal("???", screen.tiles[3].unknown.widget.text)
        shot("pack_new")
        clean()
        tapRect(screen.tiles[3].rect)
        assert.are.equal("game", top())
        assert.are.equal(3, app.game.puzzle.number)
    end)

    it("saves a game when leaving and resumes it with Continue", function()
        launch()
        app:back()
        openPacks()
        tapRect(host.screen.rows[1].rect)
        tapRect(host.screen.tiles[2].rect)
        tapCell(host.screen, 1, 1)
        tapCell(host.screen, 2, 2)
        app:back()
        assert.are.equal("pack", top())
        assert.is_not_nil(host.screen.tiles[2].cells)
        shot("pack_in_progress")
        app:back()
        app:back()
        local home = host.screen
        assert.are.equal("Continue", home.primary.text)
        assert.are.equal(2, home.spot.puzzle.number)
        assert.are.equal("First Steps · 2", home.card_title.widget.text)
        assert.is_not_nil(home.spot.cells)
        shot("home_continue")
        clean()
        tapRect(home.primary.rect)
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
        assert.are.equal(4, host.screen.spot.puzzle.number)
        tapRect(host.screen.primary.rect)
        assert.are.equal(Cell.FILLED, app.game:cell(1, 1))
    end)

    it("debounces saves during play and flushes on suspend", function()
        local _, screen = play(1, 1)
        local before = LuaSettings.files["/settings/piclo.lua"]
        tapCell(screen, 1, 1)
        assert.are.equal(before, LuaSettings.files["/settings/piclo.lua"])
        assert.are.equal(1, #UIManager.tasks)
        host:handleEvent(Event:new("Suspend"))
        local saved = LuaSettings.files["/settings/piclo.lua"]
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
        assert.are.equal(1, #reveal.buttons)
        assert.are.equal(game.puzzle.title, reveal.title.widget.text)
        assert.truthy(reveal.summary.widget.text:find("Solved in"))
        assert.are.equal("Back to collection", reveal.primary.text)
        -- How far the pack is, under the time.
        assert.are.equal("1 of 4 in First Steps", reveal.progress.widget.text)
        local shown = false
        for _, pos in ipairs(reveal.text_pos) do
            if pos.item == reveal.progress then shown = true end
        end
        assert.is_true(shown)
        shot("reveal_portrait")
        clean()
        assert.is_true(app:progress():isSolved(game.puzzle.id))
        -- Back in the collection: the new picture framed, the next one a tile away.
        tapRect(reveal.primary.rect)
        assert.are.equal("pack", top())
        local pack = host.screen
        assert.are.equal(game.puzzle.id, pack.marked)
        assert.is_nil(pack.next_btn)
        shot("pack_after_solve")
        clean()
        tapRect(pack.tiles[2].rect)
        assert.are.equal("game", top())
        assert.are.equal(2, app.game.puzzle.number)
        -- Leaving the next puzzle unsolved: the collection is back to normal.
        app:back()
        assert.are.equal("pack", top())
        assert.is_nil(host.screen.marked)
    end)

    it("announces a newly unlocked pack", function()
        local _, screen, game = play(1, 3)
        local progress = app:progress()
        for k = 1, 2 do progress:markSolved(app:catalog().packs[1].puzzles[k].id, 10) end
        solveByTapping(screen, game)
        UIManager:runScheduled()
        assert.are.same({ "Around the House" }, host.screen.data.unlocked)
        shot("reveal_unlock")
        clean()
        tapRect(host.screen.primary.rect)
        assert.are.equal("pack", top())
        app:back()
        assert.is_true(host.screen.rows[2].info.unlocked)
    end)

    it("offers the next pack on the reveal that finishes a pack", function()
        local _, screen, game = play(1, 4)
        local puzzles = app:catalog().packs[1].puzzles
        for k = 1, 3 do app:progress():markSolved(puzzles[k].id, 10) end
        solveByTapping(screen, game)
        UIManager:runScheduled()
        local reveal = host.screen
        assert.are.equal("reveal", top())
        assert.are.equal("Next pack", reveal.primary.text)
        assert.are.equal("Back to collection", reveal.secondary.text)
        shot("reveal_next_pack")
        clean()
        tapRect(reveal.primary.rect)
        assert.are.equal("pack", top())
        assert.are.equal("house", host.screen.pack.id)
        app:back()
        assert.are.equal("packs", top())
        app:back()
        assert.are.equal("home", top())
    end)

    it("doesn't offer a next pack when everything is solved", function()
        local _, screen, game = play(3, 8)
        for __, pack in ipairs(app:catalog().packs) do
            for __, p in ipairs(pack.puzzles) do
                if p ~= game.puzzle then app:progress():markSolved(p.id, 10) end
            end
        end
        solveByTapping(screen, game)
        UIManager:runScheduled()
        assert.are.equal(1, #host.screen.buttons)
        assert.are.equal("Back to collection", host.screen.primary.text)
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
        openPacks()
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

    -- Sets up progress so solving puzzle k of pack `pi` unlocks the next pack
    -- (the rules: 5 in First Steps, then 8 in Around the House).
    local function oneShortOfUnlock(pi, k)
        local cat, pr = app:catalog(), app:progress()
        local function solveOthers(pack_index, n)
            local done = 0
            for i, p in ipairs(cat.packs[pack_index].puzzles) do
                if done < n and not (pack_index == pi and i == k) then
                    pr:markSolved(p.id, 10)
                    done = done + 1
                end
            end
        end
        if pi == 1 then
            solveOthers(1, 2)
        else
            solveOthers(1, 3)
            solveOthers(2, 7)
        end
    end

    for _, size in ipairs(sizes) do
        it("keeps a pack-unlocking solve on its grid at " .. size[1] .. "x" .. size[2], function()
            local misplaced = {}
            for pi = 1, 2 do
                for k = 1, #app:catalog().packs[pi].puzzles do
                    launch(size[1], size[2])
                    if top() == "help" then app:back() end
                    oneShortOfUnlock(pi, k)
                    local p = app:catalog().packs[pi].puzzles[k]
                    assert.is_true(app:collection():wouldUnlock(p), p.id .. " would unlock")
                    app:openPuzzle(p)
                    H.settle()
                    local screen, game = host.screen, app.game
                    local grid = gridBox(screen)
                    solveByTapping(screen, game)
                    UIManager:runScheduled()
                    local rv = host.screen
                    assert.are.equal(1, #rv.data.unlocked)
                    local box = rv.box
                    if box.x ~= grid.x or box.y ~= grid.y or box.w ~= grid.w or box.h ~= grid.h then
                        misplaced[#misplaced + 1] = p.id
                    end
                    clean()
                end
            end
            assert.are.same({}, misplaced)
        end)
    end

    it("keeps the picture on the grid when the solution is shown on an unlocking board", function()
        launch()
        app:back()
        oneShortOfUnlock(2, 4)
        local p = app:catalog().packs[2].puzzles[4]
        app:openPuzzle(p)
        H.settle()
        local grid = gridBox(host.screen)
        app:showSolution()
        assert.are.same(grid, host.screen.box)
        assert.are.same({}, host.screen.data.unlocked)
    end)

    it("puts a long unlock line's pack name on a line of its own", function()
        launch(1680, 1264)
        app:back()
        local p = app:catalog().packs[2].puzzles[4]
        local long = "A pack with a remarkably long title, far too long for one line"
        app:push{ name = "reveal", data = { mode = "solved", puzzle = p, elapsed = 10, unlocked = { long } } }
        local u = host.screen.unlocked
        assert.are.equal(2, #u)
        assert.are.equal("New pack unlocked:", u[1].widget.text)
        assert.is_false(u[1].truncated)
        assert.is_true(u[2].follows)
        assert.is_true(u[2].truncated)
        clean()
    end)

    it("keeps a short unlock line on one line", function()
        launch()
        app:back()
        local p = app:catalog().packs[2].puzzles[4]
        app:push{ name = "reveal", data = { mode = "solved", puzzle = p, elapsed = 10, unlocked = { "In the Woods" } } }
        local u = host.screen.unlocked
        assert.are.equal(1, #u)
        assert.are.equal("New pack unlocked: In the Woods", u[1].widget.text)
    end)

    for _, size in ipairs({ { 1680, 1264 }, { 1448, 1072 } }) do
        it("titles landscape reveals above the picture at " .. size[1] .. "x" .. size[2], function()
            local function overlap(a, b)
                return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
            end
            for pi, pack in ipairs({ 1, 2, 3 }) do
                for k = 1, #app:catalog().packs[pack].puzzles, 3 do
                    launch(size[1], size[2])
                    if top() == "help" then app:back() end
                    local p = app:catalog().packs[pack].puzzles[k]
                    app:push{ name = "reveal", data = { mode = "view", puzzle = p, best = 10 } }
                    local rv = host.screen
                    local box, t = rv.box, rv.title
                    local pos
                    for _, e in ipairs(rv.text_pos) do if e.item == t then pos = e end end
                    assert.truthy(pos, p.id .. " title placed")
                    assert.is_true(pos.y + t.h + rv.summary.h <= box.y, p.id .. " title above the picture")
                    local center = pos.x + t.w / 2
                    assert.is_true(math.abs(center - (box.x + box.w / 2)) <= 1
                        or pos.x == Theme.space.xl or pos.x + t.w == size[1] - Theme.space.xl, p.id .. " centered on it")
                    for _, b in ipairs(rv.buttons) do
                        assert.is_false(overlap(b.rect, box), p.id .. " button clear of the picture")
                    end
                    clean()
                end
            end
        end)
    end

    it("centers portrait reveal text on the screen, not the picture", function()
        launch()
        app:back()
        -- the 10x10 whose picture sits furthest right of center (wide row clues)
        local Placement = require("piclo/ui/board_placement")
        local mid, p, off = Screen.w / 2, nil, 0
        for _, q in ipairs(app:catalog().packs[2].puzzles) do
            local b = Placement.pictureBox(Placement.compute(q, Screen.w, Screen.h).geom)
            if b.x + b.w / 2 - mid > off then p, off = q, b.x + b.w / 2 - mid end
        end
        assert.is_true(off > 5, "some 10x10 picture sits right of center")
        -- Viewing a solved picture has two buttons, a pill and a quiet one.
        app:push{ name = "reveal", data = { mode = "view", puzzle = p, best = 10, unlocked = { "In the Woods" } } }
        assert.are.equal(2, #host.screen.buttons)
        local rv = host.screen
        for _, e in ipairs(rv.text_pos) do
            assert.is_true(math.abs(e.x + e.item.w / 2 - mid) <= 1, e.item.widget.text .. " centered on the screen")
        end
        -- the visible row: from the quiet button's text to the pill's right edge
        local quiet, pill = rv.buttons[#rv.buttons], rv.buttons[1]
        local left = quiet.rect.x + quiet:blankSide(quiet.rect.w)
        local right = pill.rect.x + pill.rect.w
        assert.is_true(math.abs((left + right) / 2 - mid) <= 1, "visible button row centered on the screen")
        clean()
    end)

    it("leaves boards alone when no unlock is coming", function()
        launch()
        app:back()
        local Placement = require("piclo/ui/board_placement")
        for _, p in ipairs(app:catalog().packs[2].puzzles) do
            local a = Placement.compute(p, Screen.w, Screen.h).geom
            app:openPuzzle(p)
            H.settle()
            local g = host.screen.board.geom
            assert.are.same({ a.grid_x, a.grid_y, a.cell }, { g.grid_x, g.grid_y, g.cell })
            app:back()
        end
    end)

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
            assert.is_true(last.y + last.h <= size[2])
            assert.is_true(home.primary.rect.y >= home.logo.y + home.logo.h)
            if size[1] == 1680 then shot("home_landscape_game") end
            clean()
            app:showPacks()
            clean()
            app:back()
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
        tapRect(host.screen.close_row.rect)
        assert.are.equal(0, #UIManager.stack)
        assert.is_nil(app.host)
    end)
end)

describe("icons", function()
    it("has a file for every icon the UI names", function()
        local files = { "piclo/ui/screens/game.lua", "piclo/ui/screens/home.lua", "piclo/ui/screens/packs.lua",
            "piclo/ui/components/list_row.lua", "piclo/ui/components/header_bar.lua" }
        for _, file in ipairs(files) do
            local src = io.open(file):read("*a")
            for name in src:gmatch('icon = "([%w_]+)"') do
                assert(io.open("piclo/icons/" .. name .. ".svg"), "missing icon " .. name)
            end
            for name in src:gmatch('Icons%.path%("([%w_]+)"') do
                assert(io.open("piclo/icons/" .. name .. ".svg"), "missing icon " .. name)
            end
            for name in src:gmatch('Icons%.paint%(bb, "([%w_]+)"') do
                assert(io.open("piclo/icons/" .. name .. ".svg"), "missing icon " .. name)
            end
        end
    end)
end)
