--[[
Game screen: header (with the more menu), the board, and the toolbar
(bottom in portrait, a rail beside the board in landscape). Turns gestures
into controller calls and repaints only what each change report names.

Input:
  tap             active tool on one cell (or a toolbar/header button)
  hold + release  the hold action (other tool, or always cross), from the
                  held cell to the release cell
  drag / flick    active tool along a straight run, as one move
  page keys       switch between Fill and Cross

Short messages ("No mistakes so far") replace the header title until the
next move, rather than popping up. The optional timer in the header moves
on once a minute.
]]

local T = require("ffi/util").template
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local BoardPlacement = require("piclo/ui/board_placement")
local BoardWidget = require("piclo/ui/board_widget")
local Game = require("piclo/game")
local GameMenu = require("piclo/ui/screens/game_menu")
local HeaderBar = require("piclo/ui/components/header_bar")
local IconButton = require("piclo/ui/components/icon_button")
local Refresh = require("piclo/ui/refresh")
local Toolbar = require("piclo/ui/toolbar")

local N_ = _.ngettext

local GameScreen = {}
GameScreen.__index = GameScreen

--[[
opts: app, game, title (header text), deghost_every (edits between
ghost-clearing flashes, nil = never), highlight_done, hold_action
("opposite" | "cross"), show_timer, rail_side, unlock_room (solving will
unlock a pack: leave room for the reveal's extra line)
]]
function GameScreen.new(opts)
    local self = setmetatable({
        app = opts.app,
        game = opts.game,
        title = opts.title,
        deghost_every = opts.deghost_every,
        hold_action = opts.hold_action,
        show_timer = opts.show_timer and not opts.game.solved,
        rail_side = opts.rail_side,
        unlock_room = opts.unlock_room,
        edits = 0,
    }, GameScreen)
    self.header = HeaderBar.new{
        title = opts.title,
        on_back = function() self.app:back() end,
        right = IconButton.new{ icon = "more", on_tap = function() GameMenu.open(self) end },
        aside = self:timerText(),
    }
    self.board = BoardWidget.new{ game = self.game, show_crosses = not self.game.solved,
        highlight_done = opts.highlight_done }
    self.toolbar = Toolbar.new{
        game = self.game,
        with_check = self.game.mistakes == "request",
        on = {
            undo = function() self:apply(self.game:undo()) end,
            redo = function() self:apply(self.game:redo()) end,
            hint = function() self:hint() end,
            check = function() self:check() end,
        },
    }
    self:scheduleTick()
    return self
end

function GameScreen:free()
    if self.tick then UIManager:unschedule(self.tick) end
    self.board:free()
    self.header:freeText()
    self.toolbar:free()
end

-- Layout ----------------------------------------------------------------

function GameScreen:layout(dimen)
    self.dimen = dimen
    local placement = BoardPlacement.compute(self.game.puzzle, dimen.w, dimen.h,
        { rail_side = self.rail_side, unlock_room = self.unlock_room })
    self.landscape = placement.landscape
    self.header:layout(0, 0, dimen.w)
    self.board:setGeometry(placement.geom)
    self.toolbar:layout(placement.toolbar, placement.landscape, placement.rail_side)
end

function GameScreen:paint(bb)
    self.header:paint(bb)
    self.board:paint(bb)
    self.toolbar:paint(bb)
end

-- Changes ---------------------------------------------------------------

--[[
Repaints what a change report touched, plus `extra` cells ({r, c} pairs, e.g.
a highlighted hold start that the stroke didn't change), the history buttons
when they changed, and the header when a message gives way to the title.
]]
function GameScreen:repaint(report, extra)
    local rects, cells = {}, extra or {}
    if report then rects = self.board:changeRects(report) end
    for __, rc in ipairs(cells) do rects[#rects + 1] = self.board:cellBox(rc[1], rc[2]) end
    local buttons = self.toolbar:sync()
    for __, b in ipairs(buttons) do rects[#rects + 1] = b.rect end
    local header = self.notice
    if header then
        self.notice = nil
        self.header:setAside(self:timerText())
        rects[#rects + 1] = self.header.rect
    end
    if #rects == 0 then return end
    Refresh.cells(self.window, rects, function(bb)
        if report then self.board:paintChanges(bb, report) end
        for __, rc in ipairs(cells) do self.board:paintCell(bb, rc[1], rc[2]) end
        for __, b in ipairs(buttons) do b:paint(bb) end
        if header then self.header:paint(bb) end
    end)
end

--- Repaints a move's changes, saves, and moves on to the reveal when solved.
function GameScreen:apply(report, extra)
    if not report and not extra then return end
    self:repaint(report, extra)
    if not report then return end
    self.app:onMove(self.game, report)
    self.edits = self.edits + 1
    if report.solved then
        self:onSolved()
    elseif self.deghost_every and self.edits % self.deghost_every == 0 then
        Refresh.deghost(self.window, self.board:boardRect())
    end
end

--[[
Shows a short message on the right of the header, in the timer's place and
style, until the next move; the title stays.
]]
function GameScreen:say(text)
    self.notice = true
    self.header:setAside(text)
    Refresh.regions(self.window, "ui", { self.header.rect }, function(bb) self.header:paint(bb) end)
end

function GameScreen:hint()
    local report = self.game:hint()
    if not report then return self:say(_("Nothing left to hint")) end
    self:apply(report)
    if report.hint == "mistake" then self:say(_("Fix the marked square first")) end
end

function GameScreen:check()
    local report = self.game:check()
    self:repaint(report)
    local n = report.mistakes
    if n == 0 then
        self:say(_("No mistakes so far"))
    else
        self:say(T(N_("1 square is wrong", "%1 squares are wrong", n), n))
    end
end

-- Solved: show the finished grid without crosses for a moment; the app then
-- moves on to the reveal screen, which puts the picture on this same grid.
function GameScreen:onSolved()
    self.board.show_crosses = false
    Refresh.regions(self.window, "ui", { self.board:boardRect(), self.toolbar.rect }, function(bb)
        self.board:paint(bb)
        self.toolbar:paint(bb)
    end)
    self.app:onSolved(self.game)
end

-- Timer -----------------------------------------------------------------

--- Whole minutes played, or nil when the header timer is off.
function GameScreen:timerText()
    if not self.show_timer then return nil end
    local m = math.floor(self.game:elapsed() / 60)
    if m < 60 then return T(_("%1 min"), m) end
    return T(_("%1 h %2 min"), math.floor(m / 60), m % 60)
end

-- Wakes up just after the next whole minute of play.
function GameScreen:scheduleTick()
    if not self.show_timer then return end
    self.tick = self.tick or function() self:onTick() end
    UIManager:scheduleIn(61 - math.floor(self.game:elapsed()) % 60, self.tick)
end

function GameScreen:onTick()
    if self.game.solved then return end
    -- A message is showing in the timer's place; the next move brings it back.
    if self.notice then return self:scheduleTick() end
    local text = self:timerText()
    if text ~= self.header.aside then
        local window = self.window
        local rect = self.header:setAside(text)
        -- Under another window (a dialog, the sleep screen) the next full
        -- repaint shows the new time instead.
        if window and not window.sheet and Refresh.canPaintDirect(window) then
            Refresh.regions(window, "ui", { rect }, function(bb) self.header:paint(bb) end)
        end
    end
    self:scheduleTick()
end

-- Buttons ---------------------------------------------------------------

function GameScreen:press(btn)
    if not btn.enabled then return end
    Refresh.press(self.window, btn.rect, function(bb) btn:paint(bb, true) end)
    Refresh.regions(self.window, "fast", { btn.rect }, function(bb) btn:paint(bb) end)
    btn.on_tap()
end

function GameScreen:selectTool(id)
    local tools = self.toolbar.tools
    if not tools:select(id) then return end
    self.game:setTool(id)
    Refresh.regions(self.window, "ui", { tools.rect }, function(bb) tools:paint(bb) end)
end

-- Gestures --------------------------------------------------------------

function GameScreen:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    local btn = self.header:buttonAt(x, y)
    if self.game.solved then
        if btn and btn == self.header.back then self:press(btn) end
        return
    end
    if btn then return self:press(btn) end
    local kind, what = self.toolbar:hit(x, y)
    if kind == "tool" then return self:selectTool(what) end
    if kind == "button" then return self:press(what) end
    local r, c = self.board:hit(x, y)
    if r then self:apply(self.game:tap(r, c)) end
end

function GameScreen:holdTool()
    if self.hold_action == "cross" then return Game.TOOL_CROSS end
    return self.game:otherTool()
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
    local report = self.game:stroke(self:holdTool(), start[1], start[2], r, c)
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
