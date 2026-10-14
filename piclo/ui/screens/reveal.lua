--[[
Reveal screen, the payoff: the finished picture drawn large in its reveal
tones (no grid, no clues), the title in display size, one line about the
time, and two actions. Also used to look at a solved picture again from the
collection ("view" mode), where the main action is "Play again".

The picture sits exactly on the board's grid, from the same placement the
game screen uses (board_placement.lua), so the grid seems to turn into the
picture. The title and time go in the band above it (where the header and
column clues were); the actions go below it in portrait and beside it in
landscape. If the title doesn't fit above, landscape stacks it beside too. Only when the text can't fit around the
grid does a general layout take over.

After a solve there is one action, back to the collection, where the new
picture is marked and "Next puzzle" waits. Under the time a line says how
far the pack is ("4 of 10 in In the Woods"), when there is room for it.
]]

local T = require("ffi/util").template
local _ = require("gettext")
local logger = require("logger")
local BoardPlacement = require("piclo/ui/board_placement")
local Format = require("piclo/util/format")
local Label = require("piclo/ui/components/label")
local Layout = require("piclo/ui/layout")
local Picture = require("piclo/ui/picture")
local Refresh = require("piclo/ui/refresh")
local TextButton = require("piclo/ui/components/text_button")
local Theme = require("piclo/ui/theme")

local RevealScreen = {}
RevealScreen.__index = RevealScreen

--- The secondary line under the title.
function RevealScreen.summary(data)
    if data.revealed then return _("Revealed") end
    local best = data.best and Format.duration(data.best)
    if data.mode == "view" then
        return best and T(_("Best %1"), best) or ""
    end
    local line = T(_("Solved in %1"), Format.duration(data.elapsed))
    if data.result and data.result.new_best then
        return line .. " · " .. _("New best")
    elseif best and data.best < math.floor(data.elapsed) then
        return line .. " · " .. T(_("Best %1"), best)
    end
    return line
end

--[[
data: mode ("solved" | "view"), puzzle, elapsed, best, result
({first, new_best}), revealed, next (puzzle or nil), unlocked (pack titles),
unlock_room (the board left room for an unlock line; the picture must match)
]]
function RevealScreen.new(opts)
    local app, data = opts.app, opts.data
    local self = setmetatable({ app = app, data = data, rail_side = opts.rail_side, labels = {} }, RevealScreen)
    local p = data.puzzle
    if data.mode == "view" then
        self.primary = TextButton.new{ text = _("Play again"), primary = true,
            on_tap = function() app:playAgain(p) end }
        self.secondary = TextButton.new{ text = _("Back to collection"),
            on_tap = function() app:backToCollection(p.pack_id) end }
        self.buttons = { self.primary, self.secondary }
    else
        self.primary = TextButton.new{ text = _("Back to collection"), primary = true,
            on_tap = function() app:backToCollection(p.pack_id, { marked = p.id, next = data.next }) end }
        self.buttons = { self.primary }
    end
    return self
end

function RevealScreen:free()
    Label.freeAll(self.labels)
    self.labels = {}
    for __, b in ipairs(self.buttons) do b:free() end
end

--- "4 of 10 in In the Woods" after a solve (also a revealed one); nil when viewing.
function RevealScreen:progressText()
    if self.data.mode == "view" then return nil end
    local catalog = self.app:catalog()
    local pack = catalog:pack(self.data.puzzle.pack_id)
    local info = self.app:collection():packInfo(pack)
    return T(_("%1 of %2 in %3"), info.solved, info.total, pack.title)
end

function RevealScreen:label(opts)
    local l = Label.new(opts)
    self.labels[#self.labels + 1] = l
    return l
end

-- (Re)builds the labels: unlock lines for a column of at most col_w, title
-- and time for title_w (default col_w).
function RevealScreen:makeLabels(col_w, title_w)
    Label.freeAll(self.labels)
    self.labels = {}
    local p = self.data.puzzle
    title_w = title_w or col_w
    self.title = self:label{ text = p.title, role = "title", size = "display", max_width = title_w }
    self.summary = self:label{ text = RevealScreen.summary(self.data), color = Theme.SECONDARY, max_width = title_w }
    local progress = self:progressText()
    self.progress = progress and self:label{ text = progress, color = Theme.SECONDARY, max_width = title_w }
    self.unlocked = {}
    for __, title in ipairs(self.data.unlocked or {}) do self:addUnlockLines(title, col_w) end
end

--[[
"New pack unlocked: <title>" on one line when it fits, else the pack title on
a line of its own right under "New pack unlocked:" (cut short only if even
that is too long). A continuation line has follows = true: no gap above it.
]]
function RevealScreen:addUnlockLines(title, col_w)
    local function line(text)
        return self:label{ text = text, size = BoardPlacement.UNLOCK_SIZE, color = Theme.SECONDARY,
            max_width = col_w }
    end
    local one = line(T(_("New pack unlocked: %1"), title))
    if not one.truncated then
        self.unlocked[#self.unlocked + 1] = one
        return
    end
    self.unlocked[#self.unlocked + 1] = line(_("New pack unlocked:"))
    local name = line(title)
    name.follows = true
    self.unlocked[#self.unlocked + 1] = name
end

-- Space above an unlock line: none under the line it continues.
local function gapAbove(l)
    return l.follows and 0 or Theme.space.s
end

-- Left edge for something w wide centered on cx, kept m inside the screen.
local function centerOn(cx, w, W, m)
    return math.max(m, math.min(W - m - w, cx - math.floor(w / 2)))
end

function RevealScreen:buttonWidth(b, max_w)
    return b:standardWidth(max_w)
end

--[[
The lines above the picture: title, time and, when it fits in max_h too,
the pack progress. Returns them and their height.
]]
function RevealScreen:aboveLines(max_h)
    local lines = { self.title, self.summary }
    local h = self.title.h + self.summary.h
    if self.progress and h + self.progress.h <= max_h then
        lines[3] = self.progress
        h = h + self.progress.h
    end
    return lines, h
end

--[[
Stacks title, time, pack progress, buttons and unlock lines centered on cx
from y; returns the height. measure_only just returns the height.
]]
function RevealScreen:layoutColumn(cx, y, col_w, measure_only)
    local h, pos = 0, {}
    local function text(l)
        pos[#pos + 1] = { item = l, x = cx - math.floor(l.w / 2), y = y + h }
        h = h + l.h
    end
    text(self.title)
    text(self.summary)
    if self.progress then text(self.progress) end
    h = h + Theme.space.xxl
    for __, b in ipairs(self.buttons) do
        local w = self:buttonWidth(b, col_w)
        if not measure_only then b:setRect(cx - math.floor(w / 2), y + h, w, Theme.touch) end
        h = h + Theme.touch + Theme.space.s
    end
    for __, l in ipairs(self.unlocked) do
        h = h + gapAbove(l)
        text(l)
    end
    if not measure_only then self.text_pos = pos end
    return h
end

--[[
Portrait, around the grid: title and time centered in the space above it,
the buttons side by side (main action on the right) and any unlock lines in
the space below. All centered on the screen, not the picture: the grid sits
right of center (the row clues needed room on its left), and text that
follows it reads as off-center. False when it doesn't fit.
]]
function RevealScreen:layoutAround(W, H, pic)
    local m = Theme.space.xl
    self:makeLabels(W - 2 * m)
    local above, above_h = self:aboveLines(pic.y - 2 * m)
    if above_h > pic.y - 2 * m then return false end

    local widths, row_w = {}, 0
    for k, b in ipairs(self.buttons) do
        widths[k] = self:buttonWidth(b, W - 2 * m)
        row_w = row_w + widths[k] + (k > 1 and Theme.space.l or 0)
    end
    if row_w > W - 2 * m then return false end
    local below_h = Theme.touch
    for __, l in ipairs(self.unlocked) do below_h = below_h + gapAbove(l) + l.h end
    local bottom = pic.y + pic.h
    if H - bottom < BoardPlacement.revealRoom(#self.unlocked) then return false end
    local y = bottom + math.floor((H - bottom - below_h) / 2)

    local cx = math.floor(W / 2)
    self.text_pos = {}
    local ty = math.floor((pic.y - above_h) / 2)
    for __, l in ipairs(above) do
        self.text_pos[#self.text_pos + 1] = { item = l, x = centerOn(cx, l.w, W, m), y = ty }
        ty = ty + l.h
    end
    -- Center what's visible: shift by the difference in blank space at the
    -- row's two ends (a quiet button's padding doesn't show).
    local n = #self.buttons
    local shift = math.floor((self.buttons[1]:blankSide(widths[1]) - self.buttons[n]:blankSide(widths[n])) / 2)
    local x = centerOn(cx + shift, row_w, W, m)
    for k = n, 1, -1 do
        self.buttons[k]:setRect(x, y, widths[k], Theme.touch)
        x = x + widths[k] + Theme.space.l
    end
    y = y + Theme.touch
    for __, l in ipairs(self.unlocked) do
        y = y + gapAbove(l)
        self.text_pos[#self.text_pos + 1] = { item = l, x = centerOn(cx, l.w, W, m), y = y }
        y = y + l.h
    end
    return true
end

--[[
Landscape, beside the grid: one column in the wider side (where the row
clues or the toolbar rail were), so it gets a slim margin and buttons may
give up some padding. False when the title or a button label would have to
be cut short.
]]
function RevealScreen:layoutBeside(W, H, pic)
    local zone_x, zone_w = 0, pic.x
    if W - (pic.x + pic.w) > zone_w then
        zone_x, zone_w = pic.x + pic.w, W - (pic.x + pic.w)
    end
    local col_w = zone_w - 2 * Theme.space.s
    for __, b in ipairs(self.buttons) do
        if b:minWidth() > col_w then return false end
    end
    if self:layoutTitleAbove(W, H, pic, zone_x, zone_w, col_w) then return true end
    self:makeLabels(col_w)
    if self.title.truncated then return false end
    local h = self:layoutColumn(0, 0, col_w, true)
    if h > H - 2 * Theme.space.xl then return false end
    self:layoutColumn(zone_x + math.floor(zone_w / 2), math.floor((H - h) / 2), col_w)
    return true
end

--[[
Landscape with the title and time in the band above the picture, centered
on it, and the buttons and unlock lines in the side column, centered on the
picture's middle. False when the title doesn't fit the band.
]]
function RevealScreen:layoutTitleAbove(W, H, pic, zone_x, zone_w, col_w)
    local m = Theme.space.xl
    self:makeLabels(col_w, W - 2 * m)
    local above, above_h = self:aboveLines(pic.y - 2 * m)
    if self.title.truncated or above_h > pic.y - 2 * m then return false end

    local cx = pic.x + math.floor(pic.w / 2)
    self.text_pos = {}
    local ty = math.floor((pic.y - above_h) / 2)
    for __, l in ipairs(above) do
        self.text_pos[#self.text_pos + 1] = { item = l, x = centerOn(cx, l.w, W, m), y = ty }
        ty = ty + l.h
    end

    local col_h = #self.buttons * Theme.touch + (#self.buttons - 1) * Theme.space.s
    for __, l in ipairs(self.unlocked) do col_h = col_h + gapAbove(l) + l.h end
    if col_h > H - 2 * m then return false end
    local y = pic.y + math.floor((pic.h - col_h) / 2)
    y = math.max(m, math.min(H - m - col_h, y))
    local zcx = zone_x + math.floor(zone_w / 2)
    for k, b in ipairs(self.buttons) do
        local w = self:buttonWidth(b, col_w)
        b:setRect(zcx - math.floor(w / 2), y, w, Theme.touch)
        y = y + Theme.touch + (k < #self.buttons and Theme.space.s or 0)
    end
    for __, l in ipairs(self.unlocked) do
        y = y + gapAbove(l)
        self.text_pos[#self.text_pos + 1] = { item = l, x = zcx - math.floor(l.w / 2), y = y }
        y = y + l.h
    end
    return true
end

-- Fallback when the text can't go around the grid: picture and text placed
-- on their own.
function RevealScreen:layoutGeneral(W, H)
    local p, m = self.data.puzzle, Theme.space.xxl
    if W > H then
        local col_w = math.floor(W / 2) - 2 * m
        self:makeLabels(col_w)
        self.box = { x = m, y = m, w = math.floor(W / 2) - 2 * m, h = H - 2 * m }
        local text_h = self:layoutColumn(0, 0, col_w, true)
        self:layoutColumn(math.floor(W * 3 / 4), math.floor((H - text_h) / 2), col_w)
        return
    end
    local col_w = W - 2 * m
    self:makeLabels(col_w)
    local text_h = self:layoutColumn(0, 0, col_w, true)
    -- At most ~70% of the width, so even a 5x5 picture keeps a calm margin.
    local bw = math.min(W - 2 * m, math.floor(W * 0.7))
    local scale = Layout.fitPicture(p.w, p.h, bw, H - text_h - 3 * m)
    local pic_h = p.h * scale
    -- Center picture plus text as one block.
    local top = math.floor((H - pic_h - m - text_h) / 2)
    self.box = { x = math.floor((W - bw) / 2), y = top, w = bw, h = pic_h }
    self:layoutColumn(math.floor(W / 2), top + pic_h + m, col_w)
end

function RevealScreen:layout(dimen)
    local W, H = dimen.w, dimen.h
    local p = self.data.puzzle
    local placement = BoardPlacement.compute(p, W, H,
        { rail_side = self.rail_side, unlock_room = self.data.unlock_room })
    if placement.geom then
        local pic = BoardPlacement.pictureBox(placement.geom)
        local fits
        if placement.landscape then
            fits = self:layoutBeside(W, H, pic)
        else
            fits = self:layoutAround(W, H, pic)
        end
        if fits then
            self.box = pic
            return
        end
        logger.info("piclo: reveal text does not fit around the board for", p.id)
    end
    self:layoutGeneral(W, H)
end

function RevealScreen:paint(bb)
    Picture.paint(bb, self.data.puzzle, self.box)
    for __, pos in ipairs(self.text_pos) do
        pos.item:paint(bb, pos.x, pos.y)
    end
    for __, b in ipairs(self.buttons) do b:paint(bb) end
end

function RevealScreen:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    for __, b in ipairs(self.buttons) do
        if b:contains(x, y) then
            Refresh.press(self.window, b.rect, function(bb) b:paint(bb, true) end)
            return b.on_tap()
        end
    end
end

return RevealScreen
