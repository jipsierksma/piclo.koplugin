--[[
Title screen: the logo, a card for what to play, and a light menu (Packs,
How to play, Settings, Close; light rows between hairlines). No header bar:
Close and the back key leave.

The card is the same in every state; what's on it depends on
Collection:spotlight():
  start      nothing played yet: a faint empty grid of the first puzzle,
             "First Steps", "8 pictures to discover", Start (opens that puzzle)
  continue   a card: the board so far, "In the Woods · 5", "15×15 · 4:12 played", Continue
  play       a card: a faint empty grid of the puzzle's size, "First Steps · 2", "5×5 · New", Play
  done       a card: the latest solved picture and a closing line; no pill, as the
             Packs row right below is the way on

The free height is shared evenly around logo, card and menu, so neither end
of the screen gets heavy. Landscape puts logo and card on the left and the
menu on the right.
]]

local IconWidget = require("ui/widget/iconwidget")
local T = require("ffi/util").template
local _ = require("gettext")
local Format = require("piclo/util/format")
local N_ = _.ngettext
local C_ = require("piclo/l10n").pgettext
local Icons = require("piclo/ui/icons")
local Label = require("piclo/ui/components/label")
local ListRow = require("piclo/ui/components/list_row")
local Picture = require("piclo/ui/picture")
local Refresh = require("piclo/ui/refresh")
local TextButton = require("piclo/ui/components/text_button")
local Theme = require("piclo/ui/theme")

local HomeScreen = {}
HomeScreen.__index = HomeScreen

-- Logo height as a share of the screen height (landscape a bit more, as
-- its column is narrow), and thumbnail width as a share of its column.
local LOGO_SHARE = 0.115
local LOGO_SHARE_LANDSCAPE = 0.16
local THUMB_SHARE = 0.42

function HomeScreen.new(opts)
    local app = opts.app
    local self = setmetatable({ app = app, labels = {}, rows = {} }, HomeScreen)
    self.spot = app:collection():spotlight()
    local spot = self.spot
    local pill = { start = _("Start"), continue = C_("Piclo", "Continue"), play = _("Play") }
    if pill[spot.kind] then
        self.primary = TextButton.new{ text = pill[spot.kind], primary = true,
            on_tap = function() app:openPuzzle(spot.puzzle) end }
    end
    self.menu = {
        { key = "packs_row", title = _("Packs"), on_tap = function() app:showPacks() end },
        { key = "help_row", title = _("How to play"), on_tap = function() app:showHelp() end },
        { key = "settings_row", title = _("Settings"), on_tap = function() app:showSettings() end },
        -- Leaves rather than opens a screen, so no chevron.
        { key = "close_row", title = _("Close"), chevron = false, on_tap = function() app:back() end },
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
    if self.primary then self.primary:free() end
end

function HomeScreen:label(opts)
    local l = Label.new(opts)
    self.labels[#self.labels + 1] = l
    return l
end

local function sizeText(puzzle)
    return T(_("%1×%2"), puzzle.w, puzzle.h)
end

local function inside(rect, x, y)
    return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

-- Height of a menu row: one line of body text with room to tap.
local function rowHeight()
    return Theme.touch + Theme.space.m
end

--[[
Shares the free height of [top, bottom] evenly before, between and after the
blocks ({h, place = function(y)}), and places each. With max_gap the gaps
between blocks stay at most that, and the group is centered instead.
]]
local function spread(blocks, top, bottom, max_gap)
    local used = 0
    for __, b in ipairs(blocks) do used = used + b.h end
    local space = math.max(0, math.floor((bottom - top - used) / (#blocks + 1)))
    if max_gap and space > max_gap then space = max_gap end
    local y = top + math.floor((bottom - top - used - (#blocks - 1) * space) / 2)
    for __, b in ipairs(blocks) do
        b.place(y)
        y = y + b.h + space
    end
end

-- The card's two lines of text for the spotlight.
function HomeScreen:cardText()
    local spot = self.spot
    if spot.kind == "done" then
        return _("Every picture found"), _("Play them again from Packs")
    end
    local p = spot.puzzle
    if spot.kind == "start" then
        local pack = self.app:catalog():pack(p.pack_id)
        local n = #pack.puzzles
        return pack.title, T(N_("1 picture to discover", "%1 pictures to discover", n), n)
    end
    -- e.g. "In the Woods · 5"
    local title = T(_("%1 · %2"), self.app:catalog():pack(p.pack_id).title, p.number)
    if spot.kind == "continue" then
        -- e.g. "15×15 · 4:12 played": a bare 4:12 could read as the time of day
        return title, T(_("%1 · %2 played"), sizeText(p), Format.duration(spot.elapsed))
    end
    return title, T(_("%1 · New"), sizeText(p))
end

--- A block for the logo scaled to fit max_w x max_h, centered in [x, x + w); nil if too small.
function HomeScreen:logoBlock(x, w, max_h)
    local aspect = Icons.aspect("logo")
    if not aspect then return nil end
    local h = math.min(math.floor((w - 2 * Theme.space.xl) / aspect), max_h)
    if h < Theme.touch then return nil end
    local lw = math.floor(h * aspect)
    local logo = { w = lw, h = h, x = x + math.floor((w - lw) / 2),
        widget = IconWidget:new{ file = Icons.path("logo"), width = lw, height = h } }
    self.logo = logo
    return { h = h, place = function(y) logo.y = y end }
end

--[[
A block for the card in [x, x + w): a thumb x thumb thumbnail with the text
and pill beside it, centered on it.
]]
function HomeScreen:cardBlock(x, w, thumb)
    local m = Theme.space.xl
    local text_x = x + m + thumb + Theme.space.xl
    local text_w = x + w - m - text_x
    local title, sub = self:cardText()
    self.card_title = self:label{ text = title, role = "title", max_width = text_w }
    self.card_sub = self:label{ text = sub, color = Theme.SECONDARY, max_width = text_w }
    local t = Theme.touch
    local pill = self.primary and (Theme.space.l + t) or 0
    local block = self.card_title.h + self.card_sub.h + pill
    return { h = thumb, place = function(y)
        self.thumb = { x = x + m, y = y, w = thumb, h = thumb }
        local ty = y + math.floor((thumb - block) / 2)
        self.card_text = { x = text_x, y = ty }
        if self.primary then
            self.primary:setRect(text_x, ty + self.card_title.h + self.card_sub.h + Theme.space.l,
                self.primary:standardWidth(text_w), t)
        end
    end }
end

--- A block for the menu rows across [x, x + w); also sets self.packs_row etc.
function HomeScreen:menuBlock(x, w)
    local rh = rowHeight()
    local solved, total = self.app:collection():totals()
    return { h = #self.menu * rh, place = function(y)
        for k, item in ipairs(self.menu) do
            local row = ListRow.new{
                rect = { x = x, y = y + (k - 1) * rh, w = w, h = rh },
                title = item.title,
                aside = k == 1 and T(_("%1 of %2 solved"), solved, total) or nil,
                light = true,
                chevron = item.chevron,
            }
            row.on_tap = item.on_tap
            self.rows[k] = row
            self[item.key] = row
        end
    end }
end

--[[
The card under the logo, sized for the height left over (room); nil when it
wouldn't fit.
]]
function HomeScreen:heroBlock(x, w, room)
    local thumb = math.min(math.floor((w - 2 * Theme.space.xl) * THUMB_SHARE), room)
    if thumb < 2 * Theme.touch then return nil end
    return self:cardBlock(x, w, thumb)
end

function HomeScreen:layoutPortrait(W, H)
    local menu = self:menuBlock(0, W)
    local min_gap = Theme.space.xl
    local logo = self:logoBlock(0, W, math.floor(H * LOGO_SHARE))
    local hero = self:heroBlock(0, W, H - menu.h - (logo and logo.h or 0) - 4 * min_gap)
    if not hero then
        -- Too low for everything: the card matters more than the logo.
        self:freeLayout()
        menu, logo = self:menuBlock(0, W), nil
        hero = self:heroBlock(0, W, H - menu.h - 3 * min_gap)
    end
    local blocks = {}
    for __, b in ipairs({ logo, hero, menu }) do blocks[#blocks + 1] = b end
    spread(blocks, 0, H)
end

function HomeScreen:layoutLandscape(W, H)
    local half = math.floor(W / 2)
    local min_gap = Theme.space.xl
    local logo = self:logoBlock(0, half, math.floor(H * LOGO_SHARE_LANDSCAPE))
    local hero = self:heroBlock(0, half, H - (logo and logo.h or 0) - 3 * min_gap)
    local left = {}
    for __, b in ipairs({ logo, hero }) do left[#left + 1] = b end
    -- Logo and card stay together, centered like the menu beside them.
    spread(left, 0, H, Theme.space.xxl)
    spread({ self:menuBlock(half, W - half) }, 0, H)
end

function HomeScreen:layout(dimen)
    self:freeLayout()
    self.thumb = nil
    if dimen.w > dimen.h then
        self:layoutLandscape(dimen.w, dimen.h)
    else
        self:layoutPortrait(dimen.w, dimen.h)
    end
end

function HomeScreen:paintThumb(bb)
    local th, spot = self.thumb, self.spot
    -- A thin frame: the heavy one means "just solved" in the collection.
    bb:paintBorder(th.x, th.y, th.w, th.h, Theme.line.hair, Theme.BLACK)
    local g = Theme.space.m
    local inner = { x = th.x + g, y = th.y + g, w = th.w - 2 * g, h = th.h - 2 * g }
    if spot.kind == "continue" then
        -- The board as you left it.
        Picture.paint(bb, spot.puzzle, inner, { cells = spot.cells })
    elseif spot.kind == "play" or spot.kind == "start" then
        -- The board you're about to open, still empty.
        Picture.grid(bb, spot.puzzle, inner)
    elseif spot.puzzle then
        Picture.paint(bb, spot.puzzle, inner)
    end
end

function HomeScreen:paint(bb)
    if self.logo then self.logo.widget:paintTo(bb, self.logo.x, self.logo.y) end
    if self.thumb then
        self:paintThumb(bb)
        local ct = self.card_text
        self.card_title:paint(bb, ct.x, ct.y)
        self.card_sub:paint(bb, ct.x, ct.y + self.card_title.h)
    end
    if self.primary then self.primary:paint(bb) end
    -- A hairline above the menu too, so every row sits between two lines.
    local first = self.rows[1]
    if first then
        local r, m = first.rect, Theme.space.xl
        bb:paintRect(r.x + m, r.y, r.w - 2 * m, Theme.line.hair, Theme.BLACK)
    end
    for __, row in ipairs(self.rows) do row:paint(bb) end
end

function HomeScreen:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    local p = self.primary
    if p and (p:contains(x, y) or (self.thumb and inside(self.thumb, x, y))) then
        Refresh.press(self.window, p.rect, function(bb) p:paint(bb, true) end)
        return p.on_tap()
    end
    for __, row in ipairs(self.rows) do
        if row:contains(x, y) then
            Refresh.press(self.window, row.rect, function(bb) row:paintPressed(bb) end)
            return row.on_tap()
        end
    end
end

return HomeScreen
