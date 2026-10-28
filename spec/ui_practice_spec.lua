--[[
The guided practice from How to play (spec/ui_harness.lua): its steps,
highlighted clues, mistake marks, the closing button, and that nothing is
saved.
]]

local H = require("ui_harness")
local Grid = require("piclo/model/grid")

local top, tapRect, tapCell, shot, clean = H.top, H.tapRect, H.tapCell, H.shot, H.clean

local function screen() return H.host.screen end

local function fillRow(r, cols)
    for __, c in ipairs(cols) do tapCell(screen(), r, c) end
end

local function useTool(k)
    local seg = screen().toolbar.tools.segs[k]
    tapRect(seg)
end

local function stepText(lesson, s) return H.app:lessons()[lesson].steps[s].text end

describe("practice", function()
    it("walks through both practice puzzles from How to play, saving nothing", function()
        H.launch()
        assert.are.equal("help", top())
        local help = screen()
        assert.is_false(help.practice_btn.primary, "quiet beside Got it")
        assert.is_true(help.practice_btn.rect.x < help.done_btn.rect.x)
        tapRect(help.practice_btn.rect)
        assert.are.equal("game", top())
        local s = screen()
        assert.are.equal("Practice 1 of 2", s.header.title)
        assert.is_nil(s.header.right, "no menu: nothing to restart or reveal")
        assert.are.equal(stepText(1, 1), s.panel.text)
        assert.is_true(s.board:focused("row", 1))
        shot("practice_1")
        clean()

        fillRow(1, { 1, 2, 3, 4, 5 })
        assert.are.equal(stepText(1, 2), s.panel.text)
        assert.is_false(s.board:focused("row", 1))
        assert.is_true(s.board:focused("row", 3) and s.board:focused("row", 5))
        fillRow(3, { 1, 2, 3, 4, 5 })
        fillRow(5, { 1, 2, 3, 4, 5 })
        assert.are.equal(stepText(1, 3), s.panel.text)

        -- A square against the picture: marked, and the guide says so.
        tapCell(s, 2, 2)
        assert.are.equal("The marked square doesn't fit the numbers. Tap it to change it, or use Undo.",
            s.panel.text)
        assert.are.equal("wrong", H.app.game:mark(Grid.index(5, 2, 2)))
        shot("practice_mistake")
        tapCell(s, 2, 2)
        assert.are.equal(stepText(1, 3), s.panel.text)

        fillRow(2, { 1, 3, 5 })
        assert.are.equal(stepText(1, 4), s.panel.text)
        useTool(2)
        fillRow(2, { 2, 4 })
        assert.are.equal(stepText(1, 5), s.panel.text)
        useTool(1)
        fillRow(4, { 1, 3, 5 })
        assert.is_true(H.app.game.solved)
        assert.is_true(s.panel.done)
        assert.are.equal("Next practice", s.panel.button.text)
        shot("practice_1_done")
        clean()

        tapRect(s.panel.button.rect)
        assert.are.equal("game", top())
        s = screen()
        assert.are.equal("Practice 2 of 2", s.header.title)
        assert.are.equal(stepText(2, 1), s.panel.text)
        H.solveByTapping(s, H.app.game)
        assert.is_true(s.panel.done)
        assert.are.equal("Done", s.panel.button.text)
        tapRect(s.panel.button.rect)
        assert.are.equal("help", top())
        assert.is_not_nil(screen().done_btn, "still the first-run introduction")

        local progress = H.app:progress()
        assert.are.same({}, progress.puzzles)
        assert.is_nil(progress.last_puzzle)
        assert.are.equal(1, #H.app.stack - 1, "home under How to play, nothing else")
    end)

    it("goes back with Undo, and offers practice as a pill from the menu", function()
        H.launch()
        H.app:back()
        tapRect(screen().help_row.rect)
        local help = screen()
        assert.is_nil(help.done_btn)
        assert.is_true(help.practice_btn.primary)
        tapRect(help.practice_btn.rect)
        local s = screen()
        fillRow(1, { 1, 2, 3, 4, 5 })
        assert.are.equal(stepText(1, 2), s.panel.text)
        tapRect(s.toolbar.undo_btn.rect)
        assert.are.equal(stepText(1, 1), s.panel.text)
        tapRect(s.header.back.rect)
        assert.are.equal("help", top())
        assert.are.same({}, H.app:progress().puzzles)
    end)

    for __, size in ipairs({ { 1264, 1680 }, { 1680, 1264 }, { 600, 800 }, { 800, 600 } }) do
        it("fits the board and the longest guide text at " .. size[1] .. "x" .. size[2], function()
            H.launch(size[1], size[2])
            for k = 1, #H.app:lessons() do
                H.app:startPractice(k, k > 1)
                H.settle()
                local s = screen()
                local p, g = s.panel.rect, s.board.geom
                assert.is_true(p.y >= g.grid_y + g.rows * g.cell, "text under the grid")
                if not s.landscape then
                    assert.is_true(p.y + p.h <= s.toolbar.rect.y, "text above the toolbar")
                else
                    assert.is_true(p.y + p.h <= size[2])
                end
                clean()
            end
        end)
    end
end)
