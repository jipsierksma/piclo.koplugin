--[[
Game screen: header, the board, and the toolbar (bottom in portrait, a rail
on the right in landscape). Turns gestures into controller calls and
repaints only what each change report names.

Input:
  tap             active tool on one cell (or a toolbar/header button)
  hold + release  the other tool, from the held cell to the release cell
  drag / flick    active tool along a straight run, as one move
  page keys       switch between Fill and Cross
]]

local BoardWidget = require("piclogic/ui/board_widget")
local Game = require("piclogic/game")
local HeaderBar = require("piclogic/ui/components/header_bar")
local IconButton = require("piclogic/ui/components/icon_button")
local Refresh = require("piclogic/ui/refresh")
local Segmented = require("piclogic/ui/components/segmented")
local Theme = require("piclogic/ui/theme")

local GameScreen = {}
GameScreen.__index = GameScreen

--[[
opts: app, game, title (header text), deghost_every (edits between
ghost-clearing flashes, nil = never)
]]
function GameScreen.new(opts)
    local self = setmetatable({
        app = opts.app,
        game = opts.game,
        deghost_every = opts.deghost_every,
        edits = 0,
    }, GameScreen)
    self.header = HeaderBar.new{ title = opts.title, on_back = function() self.app:back() end }
    self.board = BoardWidget.new{ game = self.game, show_crosses = not self.game.solved }
    self.tools = Segmented.new{
        items = {
            { id = Game.TOOL_FILL, icon = "fill" },
            { id = Game.TOOL_CROSS, icon = "cross" },
        },
        selected = self.game.tool,
    }
    self.undo_btn = IconButton.new{ icon = "undo", on_tap = function() self:history("undo") end }
    self.redo_btn = IconButton.new{ icon = "redo", on_tap = function() self:history("redo") end }
    self:syncHistoryButtons()
    return self
end

function GameScreen:free()
    self.board:free()
    self.header:freeText()
end

-- Layout ----------------------------------------------------------------

function GameScreen:layout(dimen)
    local W, H = dimen.w, dimen.h
    self.landscape = W > H
    self.header:layout(0, 0, W)
    local top = Theme.header_h
    local pad = Theme.space.l
    local bar = Theme.toolbar_h
    local area
    if self.landscape then
        self.toolbar = { x = W - bar, y = top, w = bar, h = H - top }
        area = { x = pad, y = top + pad, w = W - bar - 2 * pad, h = H - top - 2 * pad }
    else
        self.toolbar = { x = 0, y = H - bar, w = W, h = bar }
        area = { x = pad, y = top + pad, w = W - 2 * pad, h = H - top - bar - 2 * pad }
    end
    self.board:layout(area)
    self:layoutToolbar()
end

-- Spaces the toolbar items evenly along the bar.
function GameScreen:layoutToolbar()
    local tb, t = self.toolbar, Theme.touch
    local seg_len = math.floor(t * 1.25) * 2
    local items = {
        { item = self.tools, len = seg_len },
        { item = self.undo_btn, len = t },
        { item = self.redo_btn, len = t },
    }
    local along = self.landscape and tb.h or tb.w
    local used = 0
    for _, it in ipairs(items) do used = used + it.len end
    local gap = math.floor((along - used) / (#items + 1))
    local pos = gap
    for _, it in ipairs(items) do
        if self.landscape then
            it.item:setRect(tb.x + math.floor((tb.w - t) / 2), tb.y + pos, t, it.len)
        else
            it.item:setRect(tb.x + pos, tb.y + math.floor((tb.h - t) / 2), it.len, t)
        end
        pos = pos + it.len + gap
    end
end

-- Painting --------------------------------------------------------------

function GameScreen:paintToolbar(bb)
    local tb = self.toolbar
    bb:paintRect(tb.x, tb.y, tb.w, tb.h, Theme.WHITE)
    if self.landscape then
        bb:paintRect(tb.x, tb.y, Theme.line.hair, tb.h, Theme.BLACK)
    else
        bb:paintRect(tb.x, tb.y, tb.w, Theme.line.hair, Theme.BLACK)
    end
    if self.game.solved then return end
    self.tools:paint(bb)
    self.undo_btn:paint(bb)
    self.redo_btn:paint(bb)
end

function GameScreen:paint(bb)
    self.header:paint(bb)
    self.board:paint(bb)
    self:paintToolbar(bb)
end

-- Changes ---------------------------------------------------------------

function GameScreen:syncHistoryButtons()
    local a = self.undo_btn:setEnabled(self.game:canUndo())
    local b = self.redo_btn:setEnabled(self.game:canRedo())
    return a or b
end

--[[
Repaints what a change report touched, plus `extra` cells ({r, c} pairs, e.g.
a highlighted hold start that the stroke didn't change).
]]
function GameScreen:apply(report, extra)
    local rects, cells = {}, extra or {}
    if report then rects = self.board:changeRects(report) end
    for _, rc in ipairs(cells) do rects[#rects + 1] = self.board:cellBox(rc[1], rc[2]) end
    if #rects == 0 then return end
    local buttons_changed = self:syncHistoryButtons()
    if buttons_changed then
        rects[#rects + 1] = self.undo_btn.rect
        rects[#rects + 1] = self.redo_btn.rect
    end
    Refresh.cells(self.window, rects, function(bb)
        if report then self.board:paintChanges(bb, report) end
        for _, rc in ipairs(cells) do self.board:paintCell(bb, rc[1], rc[2]) end
        if buttons_changed then
            self.undo_btn:paint(bb)
            self.redo_btn:paint(bb)
        end
    end)
    if not report then return end
    self.app:onMove(self.game, report)
    self.edits = self.edits + 1
    if report.solved then
        self:onSolved()
    elseif self.deghost_every and self.edits % self.deghost_every == 0 then
        Refresh.deghost(self.window, self.board:boardRect())
    end
end

function GameScreen:history(which)
    self:apply(self.game[which](self.game))
end

-- Solved: show the finished grid without crosses for a moment; the app then
-- moves on to the reveal screen.
function GameScreen:onSolved()
    self.board.show_crosses = false
    local tb = self.toolbar
    Refresh.regions(self.window, "ui", { self.board:boardRect(), tb }, function(bb)
        self.board:paint(bb)
        self:paintToolbar(bb)
    end)
    self.app:onSolved(self.game)
end

-- Buttons ---------------------------------------------------------------

function GameScreen:press(btn)
    if not btn.enabled then return end
    Refresh.press(self.window, btn.rect, function(bb) btn:paint(bb, true) end)
    Refresh.regions(self.window, "fast", { btn.rect }, function(bb) btn:paint(bb) end)
    btn.on_tap()
end

function GameScreen:selectTool(id)
    if not self.tools:select(id) then return end
    self.game:setTool(id)
    Refresh.regions(self.window, "ui", { self.tools.rect }, function(bb) self.tools:paint(bb) end)
end

-- Gestures --------------------------------------------------------------

function GameScreen:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    local btn = self.header:buttonAt(x, y)
    if btn then return self:press(btn) end
    if self.game.solved then return end
    if self.tools:contains(x, y) then
        local k = self.tools:segmentAt(x, y)
        if k then self:selectTool(self.tools.items[k].id) end
        return
    end
    for _, b in ipairs({ self.undo_btn, self.redo_btn }) do
        if b:contains(x, y) then return self:press(b) end
    end
    local r, c = self.board:hit(x, y)
    if r then self:apply(self.game:tap(r, c)) end
end

function GameScreen:onHold(ges)
    if self.game.solved then return end
    local r, c = self.board:hit(ges.pos.x, ges.pos.y)
    if not r then return end
    self.hold_start = { r, c }
    Refresh.regions(self.window, "fast", { self.board:cellBox(r, c) }, function(bb)
        self.board:invertCell(bb, r, c)
    end)
end

function GameScreen:onHoldRelease(ges)
    local start = self.hold_start
    self.hold_start = nil
    if not start or self.game.solved then return end
    local r, c = self.board:hitClamped(ges.pos.x, ges.pos.y)
    local report = self.game:stroke(self.game:otherTool(), start[1], start[2], r, c)
    self:apply(report, { start })
end

function GameScreen:onPan(ges)
    if self.pan_start ~= nil or self.game.solved then return end
    local sp = ges.start_pos or ges.pos
    local r, c = self.board:hit(sp.x, sp.y)
    -- false marks "pan began off the board": ignore it until release
    self.pan_start = r and { r, c } or false
end

function GameScreen:onPanRelease(ges)
    local start = self.pan_start
    self.pan_start = nil
    if not start or self.game.solved then return end
    local r, c = self.board:hitClamped(ges.pos.x, ges.pos.y)
    self:apply(self.game:stroke(self.game.tool, start[1], start[2], r, c))
end

function GameScreen:onSwipe(ges)
    if self.game.solved then return end
    local r1, c1 = self.board:hit(ges.pos.x, ges.pos.y)
    if not r1 then return end
    local ep = ges.end_pos or ges.pos
    local r2, c2 = self.board:hitClamped(ep.x, ep.y)
    self:apply(self.game:stroke(self.game.tool, r1, c1, r2, c2))
end

function GameScreen:onPageKey()
    if self.game.solved then return end
    self:selectTool(self.game:otherTool())
end

return GameScreen
