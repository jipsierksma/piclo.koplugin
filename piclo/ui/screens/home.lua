--[[
Title screen: the logo, a card for the puzzle to go on with, and rows for
Packs, How to play and Settings.

The card shows a large thumbnail beside the puzzle's name and a black pill
(see Collection:spotlight):
  continue   the board so far, "In the Woods · 5", "15×15 · 4:12", Continue
  play       an empty numbered tile, "First Steps · 1", "5×5 · New", Play
  done       the latest solved picture, a closing line, Packs

Portrait stacks logo, card and rows; landscape puts logo and card on the
left and the rows on the right.
]]

local IconWidget = require("ui/widget/iconwidget")
local T = require("ffi/util").template
local _ = require("gettext")
local Format = require("piclo/util/format")
local HeaderBar = require("piclo/ui/components/header_bar")
local Icons = require("piclo/ui/icons")
local Label = require("piclo/ui/components/label")
local ListRow = require("piclo/ui/components/list_row")
local Picture = require("piclo/ui/picture")
local Refresh = require("piclo/ui/refresh")
local TextButton = require("piclo/ui/components/text_button")
local Theme = require("piclo/ui/theme")

local HomeScreen = {}
HomeScreen.__index = HomeScreen

-- Logo height as a share of the screen height, and thumbnail width as a
-- share of the column it sits in.
local LOGO_SHARE = 0.1
local THUMB_SHARE = 0.42

function HomeScreen.new(opts)
    local app = opts.app
    local self = setmetatable({ app = app, labels = {}, rows = {} }, HomeScreen)
    -- The logo carries the name, so the header shows only the back button.
    self.header = HeaderBar.new{ title = "", on_back = function() app:back() end }
    self.spot = app:collection():spotlight()
    local spot = self.spot
    local pill = { continue = _("Continue"), play = _("Play"), done = _("Packs") }
    self.primary = TextButton.new{ text = pill[spot.kind], primary = true, on_tap = function()
        if spot.kind == "done" then return app:showPacks() end
        app:openPuzzle(spot.puzzle)
    end }
    self.menu = {
        { key = "packs_row", title = _("Packs"), on_tap = function() app:showPacks() end },
        { key = "help_row", title = _("How to play"), on_tap = function() app:showHelp() end },
        { key = "settings_row", title = _("Settings"), on_tap = function() app:showSettings() end },
    }
    return self
end

function HomeScreen:freeLayout()
    if self.logo then
        self.logo.widget:free()
        self.logo = nil
    end
    Label.freeAll(self.labels)
    self.labels = {}
    for __, row in ipairs(self.rows) do row:free() end
    self.rows = {}
end

function HomeScreen:free()
    self:freeLayout()
    self.header:freeText()
    self.primary:free()
end

function HomeScreen:label(opts)
    local l = Label.new(opts)
    self.labels[#self.labels + 1] = l
    return l
end

local function sizeText(puzzle)
    return T(_("%1×%2"), puzzle.w, puzzle.h)
end

-- The card's two lines of text for the spotlight.
function HomeScreen:cardText()
    local spot = self.spot
    if spot.kind == "done" then
        return _("Every picture found"), _("Play them again from Packs")
    end
    local p = spot.puzzle
    -- e.g. "In the Woods · 5"
    local title = T(_("%1 · %2"), self.app:catalog():pack(p.pack_id).title, p.number)
    if spot.kind == "continue" then
        return title, T(_("%1 · %2"), sizeText(p), Format.duration(spot.elapsed))
    end
    return title, T(_("%1 · New"), sizeText(p))
end

--- The logo scaled to fit max_w x max_h, or nil when that leaves it too small.
function HomeScreen:makeLogo(max_w, max_h)
    local aspect = Icons.aspect("logo")
    if not aspect then return nil end
    local h = math.min(math.floor(max_w / aspect), max_h)
    if h < Theme.touch then return nil end
    local w = math.floor(h * aspect)
    self.logo = { w = w, h = h, widget = IconWidget:new{ file = Icons.path("logo"), width = w, height = h } }
    return self.logo
end

--[[
Lays the card out at (x, y) in a column w wide with a thumb x thumb
thumbnail; the text and pill sit beside it, centered on it.
]]
function HomeScreen:layoutCard(x, y, w, thumb)
    self.thumb = { x = x, y = y, w = thumb, h = thumb }
    local text_x = x + thumb + Theme.space.xl
    local text_w = x + w - text_x
    local title, sub = self:cardText()
    self.card_title = self:label{ text = title, role = "title", max_width = text_w }
    self.card_sub = self:label{ text = sub, color = Theme.SECONDARY, max_width = text_w }
    if self.spot.kind == "play" then
        self.number = self:label{ text = tostring(self.spot.puzzle.number), role = "title", size = "display",
            color = Theme.SECONDARY }
    end
    local t = Theme.touch
    local block = self.card_title.h + self.card_sub.h + Theme.space.l + t
    local ty = y + math.floor((thumb - block) / 2)
    self.card_text = { x = text_x, y = ty }
    local pw = math.min(text_w, math.max(self.primary:preferredWidth(), t * 4))
    self.primary:setRect(text_x, ty + self.card_title.h + self.card_sub.h + Theme.space.l, pw, t)
end

--- One row per menu entry, from y down, across [x, x + w); also self.packs_row etc.
function HomeScreen:layoutRows(x, y, w)
    local solved, total = self.app:collection():totals()
    for k, item in ipairs(self.menu) do
        local row = ListRow.new{
            rect = { x = x, y = y + (k - 1) * Theme.row_h, w = w, h = Theme.row_h },
            title = item.title,
            sub = k == 1 and T(_("%1 of %2 solved"), solved, total) or nil,
        }
        row.on_tap = item.on_tap
        self.rows[k] = row
        self[item.key] = row
    end
    self.rows_top = { x = x, y = y, w = w }
end

-- Thumbnail size for a column w wide, given the height left for it.
local function thumbSize(w, room)
    return math.min(math.floor(w * THUMB_SHARE), room)
end

--[[
Places the logo (if any) and returns the card's y: the free height between
the header and the screen's bottom edge is split evenly above the logo,
between logo and card, and below `below` (the height from the card's top
down that the rest takes).
]]
local function stack(logo, x, H, below)
    local top = Theme.header_h
    local free = H - top - below - (logo and logo.h or 0)
    if not logo then return top + math.floor(free / 2) end
    local space = math.floor(free / 3)
    logo.x, logo.y = x, top + space
    return logo.y + logo.h + space
end

function HomeScreen:layoutPortrait(top, bottom, W, H)
    local m, gap = Theme.space.xl, Theme.space.xxl
    local w = W - 2 * m
    local rows_h = #self.menu * Theme.row_h
    local logo = self:makeLogo(w, math.floor((bottom - top) * LOGO_SHARE))
    local logo_h = logo and logo.h + gap or 0
    local thumb = thumbSize(w, bottom - top - rows_h - gap - logo_h)
    if thumb < 2 * Theme.touch and logo then
        -- Too low for everything: the card matters more than the logo.
        self:freeLayout()
        logo = nil
        thumb = thumbSize(w, bottom - top - rows_h - gap)
    end
    local y = stack(logo, logo and math.floor((W - logo.w) / 2), H, thumb + gap + rows_h)
    self:layoutCard(m, y, w, thumb)
    self:layoutRows(0, y + thumb + gap, W)
end

function HomeScreen:layoutLandscape(top, bottom, W, H)
    local m, gap = Theme.space.xl, Theme.space.xxl
    local half = math.floor(W / 2)
    local w = half - 2 * m
    local logo = self:makeLogo(w, math.floor((bottom - top) * LOGO_SHARE * 1.4))
    local logo_h = logo and logo.h + gap or 0
    local thumb = thumbSize(w, bottom - top - logo_h)
    local y = stack(logo, logo and m + math.floor((w - logo.w) / 2), H, thumb)
    self:layoutCard(m, y, w, thumb)
    local rows_h = #self.menu * Theme.row_h
    self:layoutRows(half, top + math.floor((bottom - top - rows_h) / 2), W - half)
end

function HomeScreen:layout(dimen)
    self:freeLayout()
    local W, H = dimen.w, dimen.h
    self.header:layout(0, 0, W)
    local top, bottom = Theme.header_h + Theme.space.l, H - Theme.space.l
    if W > H then
        self:layoutLandscape(top, bottom, W, H)
    else
        self:layoutPortrait(top, bottom, W, H)
    end
end

function HomeScreen:paintThumb(bb)
    local th, spot = self.thumb, self.spot
    bb:paintBorder(th.x, th.y, th.w, th.h, Theme.line.regular, Theme.BLACK)
    local g = Theme.space.m
    local inner = { x = th.x + g, y = th.y + g, w = th.w - 2 * g, h = th.h - 2 * g }
    if spot.kind == "continue" then
        Picture.paint(bb, spot.puzzle, inner, { cells = spot.cells })
    elseif spot.kind == "play" then
        self.number:paintIn(bb, th, "center")
    elseif spot.puzzle then
        Picture.paint(bb, spot.puzzle, inner)
    end
end

function HomeScreen:paint(bb)
    self.header:paint(bb)
    if self.logo then self.logo.widget:paintTo(bb, self.logo.x, self.logo.y) end
    self:paintThumb(bb)
    local ct = self.card_text
    self.card_title:paint(bb, ct.x, ct.y)
    self.card_sub:paint(bb, ct.x, ct.y + self.card_title.h)
    self.primary:paint(bb)
    local rt, m = self.rows_top, Theme.space.xl
    bb:paintRect(rt.x + m, rt.y, rt.w - 2 * m, Theme.line.hair, Theme.BLACK)
    for __, row in ipairs(self.rows) do row:paint(bb) end
end

local function inside(rect, x, y)
    return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

function HomeScreen:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    local btn = self.header:buttonAt(x, y)
    if not btn and (self.primary:contains(x, y) or inside(self.thumb, x, y)) then btn = self.primary end
    if btn then
        Refresh.press(self.window, btn.rect, function(bb) btn:paint(bb, true) end)
        return btn.on_tap()
    end
    for __, row in ipairs(self.rows) do
        if row:contains(x, y) then
            Refresh.press(self.window, row.rect, function(bb) row:paintPressed(bb) end)
            return row.on_tap()
        end
    end
end

return HomeScreen
