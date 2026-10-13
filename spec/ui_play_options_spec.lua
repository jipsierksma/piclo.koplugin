--[[
Headless UI specs for settings and the play helpers (see spec/ui_harness.lua):
the settings screen, the more menu and its sheets, hints, mistake checking,
the header timer, the hold action and the landscape rail side.
]]

local H = require("ui_harness")
local Cell = require("piclo/model/cell")
local Event = require("ui/event")
local Game = require("piclo/game")
local Theme = require("piclo/ui/theme")
local UIManager = require("ui/uimanager")

local gesture, tapRect, tapCell, cellPoint = H.gesture, H.tapRect, H.tapCell, H.cellPoint
local shot, clean, top = H.shot, H.clean, H.top

--- Opens settings from the home menu.
local function openSettings(w, h)
    H.launch(w, h)
    if top() == "help" then H.app:back() end
    tapRect(H.host.screen.settings_row.rect)
    assert.are.equal("settings", top())
    return H.host.screen
end

--- The settings entry for a key on the current page.
local function entry(screen, key)
    for __, e in ipairs(screen.pages[screen.page]) do
        if e.row and (e.row.key == key or e.row.action == key) then return e end
    end
end

--- Taps the segment showing `text` in a settings row.
local function choose(screen, key, text)
    local seg = entry(screen, key).control
    for k, item in ipairs(seg.items) do
        if item.text == text then return tapRect(seg.segs[k]) end
    end
    error("no segment " .. text)
end

--- Plays a puzzle with some settings already saved.
local function playWith(settings, pack, n, w, h)
    H.launch(w, h)
    for k, v in pairs(settings) do H.app:setSetting(k, v) end
    if top() == "help" then H.app:back() end
    H.app:openPuzzle(H.app:catalog().packs[pack or 2].puzzles[n or 1])
    H.settle()
    return H.host.screen, H.app.game
end

-- A cell that is empty in the solution.
local function wrongCell(game)
    local p = game.puzzle
    for r = 1, p.h do
        for c = 1, p.w do
            if not p:isFilled(r, c) then return r, c end
        end
    end
end

describe("settings screen", function()
    for __, size in ipairs({ { 1264, 1680 }, { 1680, 1264 }, { 1072, 1448 }, { 758, 1024 }, { 800, 600 } }) do
        it("draws in bounds at " .. size[1] .. "x" .. size[2], function()
            local screen = openSettings(size[1], size[2])
            assert.is_true(#screen.pages >= 1)
            for p = 1, #screen.pages do
                screen.page = p
                screen:layout(screen.dimen)
                for __, e in ipairs(screen.pages[p]) do
                    if e.rect then
                        assert.is_true(e.rect.y + e.rect.h <= size[2])
                        if e.control then assert.is_true(e.control.rect.x + e.control.rect.w <= size[1]) end
                    end
                end
            end
            if size[1] == 1264 then shot("settings_portrait") end
            clean()
        end)
    end

    it("saves a switch and a choice at once", function()
        local screen = openSettings()
        tapRect(entry(screen, "show_timer").rect)
        assert.is_true(H.app:setting("show_timer"))
        assert.is_true(entry(screen, "show_timer").control.on)
        choose(screen, "mistakes", "Instant")
        assert.are.equal("instant", H.app:setting("mistakes"))
        assert.are.equal("Wrong fills are turned into crosses", entry(screen, "mistakes").note.widget.text)
        choose(screen, "deghost_every", "Never")
        assert.are.equal(0, H.app:setting("deghost_every"))
        H.host:handleEvent(Event:new("FlushSettings"))
        clean()
    end)

    it("resets all progress after confirming", function()
        local screen = openSettings()
        local first = H.app:catalog().packs[1].puzzles[1]
        H.app:progress():markSolved(first.id, 30)
        tapRect(entry(screen, "reset").rect)
        local sheet = H.host.sheet
        assert.are.equal("confirm", sheet.kind)
        shot("settings_reset_confirm")
        tapRect(sheet.ok_btn.rect)
        assert.is_nil(H.host.sheet)
        assert.is_false(H.app:progress():isSolved(first.id))
        assert.are.equal("settings", top())
        assert.are.equal("All progress cleared", entry(H.host.screen, "reset").note.widget.text)
        H.app:back()
        assert.are.equal("home", top())
    end)

    it("keeps progress when the reset is cancelled", function()
        local screen = openSettings()
        local first = H.app:catalog().packs[1].puzzles[1]
        H.app:progress():markSolved(first.id, 30)
        tapRect(entry(screen, "reset").rect)
        tapRect(H.host.sheet.cancel_btn.rect)
        assert.is_nil(H.host.sheet)
        assert.is_true(H.app:progress():isSolved(first.id))
    end)
end)

describe("more menu", function()
    local function openMenu()
        local screen, game = playWith({})
        tapRect(screen.header.right.rect)
        local sheet = H.host.sheet
        assert.are.equal("menu", sheet.kind)
        return screen, game, sheet
    end

    local function item(sheet, text)
        for __, row in ipairs(sheet.rows) do
            if row.item.text == text then return row end
        end
    end

    it("lets the panel show the pressed button before the menu paints", function()
        local screen = playWith({})
        UIManager:takeRefreshes()
        local before = UIManager.yields
        tapRect(screen.header.right.rect)
        assert.are.equal(before + 1, UIManager.yields)
        local modes = {}
        for _, r in ipairs(UIManager:takeRefreshes()) do modes[#modes + 1] = r.mode end
        assert.are.equal("fast", modes[1])
        assert.is_not_nil(H.host.sheet)
    end)

    it("shows the time played and closes on a tap outside or the back key", function()
        local _, _, sheet = openMenu()
        assert.truthy(sheet.subtitle.widget.text:find("^Played for "))
        shot("game_more_menu")
        clean()
        H.gesture("tap", 5, Theme.header_h + 5)
        assert.is_nil(H.host.sheet)
        assert.are.equal("game", top())
        tapRect(H.host.screen.header.right.rect)
        H.host:handleEvent(Event:new("Close"))
        assert.is_nil(H.host.sheet)
        assert.are.equal("game", top())
    end)

    it("ignores the board while open", function()
        local screen, game = openMenu()
        tapCell(screen, 1, 1)
        assert.is_true(game.board:isEmpty())
    end)

    it("restarts a started puzzle after confirming", function()
        local screen, game = playWith({})
        tapCell(screen, 1, 1)
        tapRect(screen.header.right.rect)
        tapRect(item(H.host.sheet, "Restart puzzle").rect)
        assert.are.equal("confirm", H.host.sheet.kind)
        tapRect(H.host.sheet.ok_btn.rect)
        assert.is_nil(H.host.sheet)
        assert.is_true(H.app.game.board:isEmpty())
        assert.are.equal(game, H.app.game)
        assert.are.equal("game", top())
    end)

    it("shows the solution as revealed, not solved", function()
        local _, game, sheet = openMenu()
        local p = game.puzzle
        tapRect(item(sheet, "Show solution").rect)
        tapRect(H.host.sheet.ok_btn.rect)
        assert.are.equal("reveal", top())
        assert.are.equal("Revealed", H.host.screen.summary.widget.text)
        assert.is_true(H.app:progress():isRevealed(p.id))
        assert.is_false(H.app:progress():isSolved(p.id))
        assert.is_nil(H.app:collection():continueTarget())
        clean()
        -- The collection shows the picture, with the title in gray.
        tapRect(H.host.screen.secondary.rect)
        assert.are.equal("pack", top())
        local tile = H.host.screen.tiles[p.number]
        assert.is_true(tile.shown)
        assert.is_false(tile.solved)
        shot("pack_revealed")
        tapRect(tile.rect)
        assert.are.equal("reveal", top())
        assert.are.equal("Revealed", H.host.screen.summary.widget.text)
    end)

    it("opens settings and returns to the game with them applied", function()
        local _, _, sheet = openMenu()
        tapRect(item(sheet, "Settings").rect)
        assert.are.equal("settings", top())
        assert.is_nil(H.app.game.running_since)
        choose(H.host.screen, "mistakes", "On request")
        H.host:handleEvent(Event:new("Suspend"))
        H.host:handleEvent(Event:new("Resume"))
        assert.is_nil(H.app.game.running_since)
        H.app:back()
        assert.are.equal("game", top())
        assert.is_not_nil(H.app.game.running_since)
        assert.truthy(H.host.screen.toolbar.check_btn)
        assert.are.equal("request", H.app.game.mistakes)
    end)
end)

describe("hints", function()
    it("fills one line as one undo step and highlights its clues", function()
        local screen, game = playWith({})
        tapRect(screen.toolbar.hint_btn.rect)
        assert.is_false(game.board:isEmpty())
        assert.truthy(game.focus)
        shot("game_hint")
        clean()
        tapRect(screen.toolbar.undo_btn.rect)
        assert.is_true(game.board:isEmpty())
        assert.is_nil(game.focus)
    end)

    it("can finish a puzzle", function()
        local screen, game = playWith({}, 1, 1)
        for __ = 1, 25 do
            if game.solved then break end
            tapRect(screen.toolbar.hint_btn.rect)
        end
        assert.is_true(game.solved)
        UIManager:runScheduled()
        assert.are.equal("reveal", top())
    end)
end)

describe("mistake checking", function()
    it("has no check button unless checking is on request", function()
        local screen = playWith({ mistakes = "off" })
        assert.is_nil(screen.toolbar.check_btn)
        screen = playWith({ mistakes = "instant" })
        assert.is_nil(screen.toolbar.check_btn)
    end)

    it("marks wrong squares on request and says how many", function()
        local screen, game = playWith({ mistakes = "request" })
        local r, c = wrongCell(game)
        tapCell(screen, r, c)
        assert.are.equal(Cell.FILLED, game:cell(r, c))
        tapRect(screen.toolbar.check_btn.rect)
        assert.are.equal("wrong", game:mark((r - 1) * game.puzzle.w + c))
        assert.are.equal("1 square is wrong", screen.header.title)
        shot("game_check")
        clean()
        -- the next move brings the title back
        tapCell(screen, r, c)
        assert.are.equal(screen.title, screen.header.title)
    end)

    it("says so when there are no mistakes", function()
        local screen = playWith({ mistakes = "request" })
        tapRect(screen.toolbar.check_btn.rect)
        assert.are.equal("No mistakes so far", screen.header.title)
    end)

    it("turns a wrong fill into a marked cross at once when instant", function()
        local screen, game = playWith({ mistakes = "instant" })
        local r, c = wrongCell(game)
        tapCell(screen, r, c)
        assert.are.equal(Cell.CROSSED, game:cell(r, c))
        assert.are.equal("rejected", game:mark((r - 1) * game.puzzle.w + c))
        clean()
    end)
end)

describe("other settings", function()
    it("shows minutes played in the header and moves on with the clock", function()
        local screen, game = playWith({ show_timer = true })
        assert.are.equal("0 min", screen.header.aside)
        game.elapsed_before = 125
        UIManager:runScheduled()
        assert.are.equal("2 min", screen.header.aside)
        assert.are.equal(1, #UIManager.tasks)
        shot("game_timer")
        clean()
        H.app:back()
        assert.are.equal(0, #UIManager.tasks)
    end)

    it("has no header timer by default", function()
        local screen = playWith({})
        assert.is_nil(screen.header.aside)
        assert.are.equal(0, #UIManager.tasks)
    end)

    it("crosses with a hold whatever the tool when set to", function()
        local screen, game = playWith({ hold_action = "cross" })
        game:setTool(Game.TOOL_CROSS)
        gesture("hold", cellPoint(screen, 1, 1))
        gesture("hold_release", cellPoint(screen, 1, 1))
        assert.are.equal(Cell.CROSSED, game:cell(1, 1))
    end)

    it("leaves gray clues black when highlighting is off", function()
        local screen = playWith({ highlight_done = false })
        assert.is_false(screen.board.highlight_done)
    end)

    it("puts the landscape rail on the left, and the reveal follows the board", function()
        local screen, game = playWith({ rail_side = "left" }, 2, 1, 1680, 1264)
        assert.are.equal(0, screen.toolbar.rect.x)
        assert.is_true(screen.board.geom.board.x > screen.toolbar.rect.w)
        local grid = H.gridBox(screen)
        shot("game_rail_left")
        H.solveByTapping(screen, game)
        UIManager:runScheduled()
        assert.are.same(grid, H.host.screen.box)
        clean()
    end)
end)
