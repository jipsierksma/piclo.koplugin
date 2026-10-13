--[[
Reveal screen, the payoff: the finished picture drawn large in its reveal
tones (no grid, no clues), the title in display size, one line about the
time, and two actions. Also used to look at a solved picture again from the
collection ("view" mode), where the main action is "Play again".

The picture sits exactly on the board's grid, from the same placement the
game screen uses (board_placement.lua), so the grid seems to turn into the
picture. In portrait the title goes above it and the actions below; in
landscape they stack beside it. Only when the text can't fit around the
grid does a general layout take over.
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
({first, new_best}), revealed, next (puzzle or nil), unlocked (pack titles)
]]
function RevealScreen.new(opts)
    local app, data = opts.app, opts.data
    local self = setmetatable({ app = app, data = data, rail_side = opts.rail_side, labels = {} }, RevealScreen)
    local p = data.puzzle
    if data.mode == "view" then
        self.primary = TextButton.new{ text = _("Play again"), primary = true,
            on_tap = function() app:playAgain(p) end }
    elseif data.next then
        self.primary = TextButton.new{ text = _("Next puzzle"), primary = true,
            on_tap = function() app:playNext(data.next) end }
    end
    self.secondary = TextButton.new{ text = _("Back to collection"),
        on_tap = function() app:backToCollection(p.pack_id) end }
    self.buttons = {}
    if self.primary then self.buttons[1] = self.primary end
    self.buttons[#self.buttons + 1] = self.secondary
    return self
end

function RevealScreen:free()
    Label.freeAll(self.labels)
    self.labels = {}
    for __, b in ipairs(self.buttons) do b:free() end
end

function RevealScreen:label(opts)
    local l = Label.new(opts)
    self.labels[#self.labels + 1] = l
    return l
end

-- (Re)builds the labels for a text column of at most col_w.
function RevealScreen:makeLabels(col_w)
    Label.freeAll(self.labels)
    self.labels = {}
    local p = self.data.puzzle
    self.title = self:label{ text = p.title, role = "title", size = "display", max_width = col_w }
    self.summary = self:label{ text = RevealScreen.summary(self.data), color = Theme.SECONDARY, max_width = col_w }
    self.unlocked = {}
    for __, title in ipairs(self.data.unlocked or {}) do
        self.unlocked[#self.unlocked + 1] = self:label{ text = T(_("New pack unlocked: %1"), title),
            max_width = col_w }
    end
end

-- Left edge for something w wide centered on cx, kept m inside the screen.
local function centerOn(cx, w, W, m)
    return math.max(m, math.min(W - m - w, cx - math.floor(w / 2)))
end

function RevealScreen:buttonWidth(b, max_w)
    return math.min(max_w, math.max(b:preferredWidth(), Theme.touch * 4))
end

--[[
Stacks title, time, buttons and unlock lines centered on cx from y; returns
the height. measure_only just returns the height.
]]
function RevealScreen:layoutColumn(cx, y, col_w, measure_only)
    local h, pos = 0, {}
    local function text(l)
        pos[#pos + 1] = { item = l, x = cx - math.floor(l.w / 2), y = y + h }
        h = h + l.h
    end
    text(self.title)
    text(self.summary)
    h = h + Theme.space.xxl
    for __, b in ipairs(self.buttons) do
        local w = self:buttonWidth(b, col_w)
        if not measure_only then b:setRect(cx - math.floor(w / 2), y + h, w, Theme.touch) end
        h = h + Theme.touch + Theme.space.s
    end
    for __, l in ipairs(self.unlocked) do
        h = h + Theme.space.s
        text(l)
    end
    if not measure_only then self.text_pos = pos end
    return h
end

--[[
Portrait, around the grid: title and time centered in the space above it,
the buttons side by side (main action on the right) and any unlock lines in
the space below. All centered on the picture. False when it doesn't fit.
]]
function RevealScreen:layoutAround(W, H, pic)
    local m = Theme.space.xl
    self:makeLabels(W - 2 * m)
    local above_h = self.title.h + self.summary.h
    if above_h > pic.y - 2 * m then return false end

    local widths, row_w = {}, 0
    for k, b in ipairs(self.buttons) do
        widths[k] = self:buttonWidth(b, W - 2 * m)
        row_w = row_w + widths[k] + (k > 1 and Theme.space.l or 0)
    end
    if row_w > W - 2 * m then return false end
    local below_h = Theme.touch
    for __, l in ipairs(self.unlocked) do below_h = below_h + Theme.space.s + l.h end
    local bottom = pic.y + pic.h
    local y = bottom + math.floor((H - bottom - below_h) / 2)
    if y < bottom + m then return false end

    local cx = pic.x + math.floor(pic.w / 2)
    self.text_pos = {}
    local ty = math.floor((pic.y - above_h) / 2)
    for __, l in ipairs({ self.title, self.summary }) do
        self.text_pos[#self.text_pos + 1] = { item = l, x = centerOn(cx, l.w, W, m), y = ty }
        ty = ty + l.h
    end
    local x = centerOn(cx, row_w, W, m)
    for k = #self.buttons, 1, -1 do
        self.buttons[k]:setRect(x, y, widths[k], Theme.touch)
        x = x + widths[k] + Theme.space.l
    end
    y = y + Theme.touch
    for __, l in ipairs(self.unlocked) do
        y = y + Theme.space.s
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
    self:makeLabels(col_w)
    if self.title.truncated then return false end
    for __, b in ipairs(self.buttons) do
        if b:minWidth() > col_w then return false end
    end
    local h = self:layoutColumn(0, 0, col_w, true)
    if h > H - 2 * Theme.space.xl then return false end
    self:layoutColumn(zone_x + math.floor(zone_w / 2), math.floor((H - h) / 2), col_w)
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
    local placement = BoardPlacement.compute(p, W, H, self.rail_side)
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
