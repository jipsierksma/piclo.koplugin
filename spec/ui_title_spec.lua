--[[
Headless specs for the title screen and the Packs screen (see
spec/ui_harness.lua): Continue or Play, the pack list, paging and the way
back out.
]]

local H = require("ui_harness")
local Theme = require("piclo/ui/theme")
local UIManager = require("ui/uimanager")

local host, app
local function launch(...)
    host, app = H.launch(...)
    return host, app
end
local top, gesture, tapRect, shot, clean = H.top, H.gesture, H.tapRect, H.shot, H.clean

--- From the title screen to the Packs screen.
local function openPacks()
    tapRect(host.screen.packs_row.rect)
    assert.are.equal("packs", top())
end

describe("title screen", function()
    it("starts with just a Play button and a light menu", function()
        launch()
        app:back()
        local home = host.screen
        assert.are.equal("start", home.spot.kind)
        assert.are.equal("Play", home.primary.text)
        assert.is_nil(home.thumb)
        assert.is_nil(home.header)
        assert.are.equal("0 of 30 solved", home.packs_row.aside.widget.text)
        assert.are.equal(4, #home.rows)
        assert.is_false(home.close_row.chevron)
        shot("home_start")
        clean()
        tapRect(home.primary.rect)
        assert.are.equal("game", top())
        assert.are.equal(app:catalog().packs[1].puzzles[1], app.game.puzzle)
    end)

    it("offers the next puzzle in a card once one was played", function()
        launch()
        app:back()
        app:progress():markSolved(app:catalog().packs[1].puzzles[1].id, 30)
        app:render()
        local home = host.screen
        assert.are.equal("Play", home.primary.text)
        assert.are.equal("First Steps · 2", home.card_title.widget.text)
        assert.are.equal("5×5 · New", home.card_sub.widget.text)
        assert.are.equal("2", home.number.widget.text)
        shot("home_play")
        clean()
        tapRect(home.thumb)
        assert.are.equal("game", top())
        assert.are.equal(app:catalog().packs[1].puzzles[2], app.game.puzzle)
    end)

    it("shows the latest picture and opens Packs when everything is solved", function()
        launch()
        app:back()
        local clock = 0
        app:progress().clock = function() clock = clock + 1 return clock end
        for __, pack in ipairs(app:catalog().packs) do
            for _, p in ipairs(pack.puzzles) do app:progress():markSolved(p.id, 10) end
        end
        local starter = app:catalog().packs[1].puzzles[3]
        app:progress().puzzles[starter.id].solved_at = clock + 1
        app:render()
        local home = host.screen
        assert.are.equal("done", home.spot.kind)
        assert.are.equal(starter, home.spot.puzzle)
        assert.are.equal("Packs", home.primary.text)
        shot("home_done")
        clean()
        tapRect(home.primary.rect)
        assert.are.equal("packs", top())
        for __, row in ipairs(host.screen.rows) do assert.is_true(row.done) end
        assert.are.equal("30 of 30 solved", host.screen.summary.widget.text)
        shot("packs_complete")
        clean()
    end)

    for _, size in ipairs({ { 1264, 1680 }, { 1680, 1264 }, { 758, 1024 }, { 600, 800 }, { 800, 600 } }) do
        it("spaces logo, card and menu evenly at " .. size[1] .. "x" .. size[2], function()
            launch(size[1], size[2])
            app:back()
            app:progress():markSolved(app:catalog().packs[1].puzzles[1].id, 30)
            app:render()
            local home = host.screen
            local logo, thumb = home.logo, home.thumb
            assert.is_not_nil(logo)
            assert.is_not_nil(thumb)
            local first, last = home.rows[1].rect, home.rows[#home.rows].rect
            assert.is_true(last.y + last.h <= size[2])
            assert.is_true(home.primary.rect.x + home.primary.rect.w <= size[1])
            local gaps = { logo.y, thumb.y - (logo.y + logo.h) }
            if size[1] > size[2] then
                -- Landscape: logo and card stay together, centered.
                assert.is_true(thumb.x + thumb.w <= first.x)
                assert.is_true(gaps[2] <= Theme.space.xxl)
                gaps = { logo.y, size[2] - (thumb.y + thumb.h) }
            else
                gaps[3] = first.y - (thumb.y + thumb.h)
                gaps[4] = size[2] - (last.y + last.h)
            end
            for k = 2, #gaps do assert.is_true(math.abs(gaps[k] - gaps[1]) <= #gaps, "even gaps") end
            clean()
        end)
    end

    it("shows the version in the settings header", function()
        launch()
        app:back()
        tapRect(host.screen.settings_row.rect)
        assert.are.equal("Piclo 0.4.0", host.screen.header.aside)
        clean()
    end)

    it("goes back from a collection to the packs, the title and out", function()
        launch()
        app:back()
        openPacks()
        tapRect(host.screen.rows[1].rect)
        assert.are.equal("pack", top())
        tapRect(host.screen.header.back.rect)
        assert.are.equal("packs", top())
        tapRect(host.screen.header.back.rect)
        assert.are.equal("home", top())
        tapRect(host.screen.close_row.rect)
        assert.are.equal(0, #UIManager.stack)
    end)

    it("pages through many packs and remembers the page", function()
        launch(600, 800)
        app:back()
        local catalog = app:catalog()
        local packs = catalog.packs
        for k = 1, 9 do
            local copy = {}
            for key, v in pairs(packs[1]) do copy[key] = v end
            copy.id, copy.title, copy.unlock = "extra" .. k, "Extra " .. k, nil
            packs[#packs + 1] = copy
            catalog.by_pack[copy.id] = copy
        end
        openPacks()
        local screen = host.screen
        assert.is_true(screen.pages > 1)
        assert.is_not_nil(screen.pager)
        clean()
        local first = screen.rows[1].pack
        gesture("swipe", 300, 400, { direction = "west" })
        assert.are.equal(2, screen.page)
        assert.is_true(first ~= screen.rows[1].pack)
        clean()
        local row = screen.rows[1]
        tapRect(row.rect)
        assert.are.equal("pack", top())
        app:back()
        assert.are.equal(2, host.screen.page)
        assert.are.equal(row.pack, host.screen.rows[1].pack)
        for k = 1, 9 do
            catalog.by_pack["extra" .. k] = nil
            packs[#packs] = nil
        end
    end)
end)
