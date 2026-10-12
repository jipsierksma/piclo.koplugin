--[[
Home screen: the wordmark, a Continue card for the puzzle in progress, the
pack list with progress and lock state, and a footer with "How to play" and
the version.
]]

local IconWidget = require("ui/widget/iconwidget")
local T = require("ffi/util").template
local _ = require("gettext")
local Format = require("piclogic/util/format")
local HeaderBar = require("piclogic/ui/components/header_bar")
local Icons = require("piclogic/ui/icons")
local Label = require("piclogic/ui/components/label")
local Picture = require("piclogic/ui/picture")
local Refresh = require("piclogic/ui/refresh")
local TextButton = require("piclogic/ui/components/text_button")
local Theme = require("piclogic/ui/theme")

local HomeScreen = {}
HomeScreen.__index = HomeScreen

local function sizeText(puzzle)
    return T(_("%1×%2"), puzzle.w, puzzle.h)
end

function HomeScreen.new(opts)
    local app = opts.app
    local self = setmetatable({ app = app, labels = {} }, HomeScreen)
    -- The wordmark carries the name, so the header shows only the back button.
    self.header = HeaderBar.new{ title = "", on_back = function() app:back() end }
    self.help_btn = TextButton.new{ text = _("How to play"), on_tap = function() app:showHelp() end }
    return self
end

function HomeScreen:freeWordmark()
    if self.wordmark then
        self.wordmark.widget:free()
        self.wordmark = nil
    end
end

function HomeScreen:free()
    self:freeWordmark()
    self.header:freeText()
    self.help_btn:free()
    Label.freeAll(self.labels)
    self.labels = {}
end

function HomeScreen:label(opts)
    local l = Label.new(opts)
    self.labels[#self.labels + 1] = l
    return l
end

function HomeScreen:layoutCard(y, W)
    local cont = self.app:continueTarget()
    self.card = nil
    if not cont then return y end
    local m, h = Theme.space.xl, Theme.card_h
    local thumb = h - 2 * Theme.space.m
    local text_x = m + thumb + Theme.space.l
    local text_w = W - text_x - m - Theme.touch
    self.card = {
        rect = { x = 0, y = y, w = W, h = h },
        thumb = { x = m, y = y + Theme.space.m, w = thumb, h = thumb },
        cont = cont,
        text_x = text_x,
        kicker = self:label{ text = _("Continue"), size = "caption", color = Theme.SECONDARY, max_width = text_w },
        title = self:label{ text = T(_("%1 · %2"), cont.pack.title, cont.puzzle.number), role = "title",
            max_width = text_w },
        sub = self:label{ text = T(_("%1 · %2"), sizeText(cont.puzzle), Format.duration(cont.elapsed)),
            color = Theme.SECONDARY, max_width = text_w },
    }
    return y + h
end

function HomeScreen:layoutRows(y, W)
    local m = Theme.space.xl
    local text_w = W - 2 * m - Theme.touch
    self.rows = {}
    for __, pack in ipairs(self.app:catalog().packs) do
        local info = self.app:packInfo(pack)
        local sub
        if info.unlocked then
            sub = T(_("%1 · %2 of %3 solved"), sizeText(pack.puzzles[1]), info.solved, info.total)
        else
            sub = T(_("Solve %1 in %2 to unlock"), info.rule.count, info.rule.after_title)
        end
        self.rows[#self.rows + 1] = {
            rect = { x = 0, y = y, w = W, h = Theme.row_h },
            pack = pack,
            info = info,
            text_w = text_w,
            title = self:label{ text = pack.title, role = "title", max_width = text_w,
                color = info.unlocked and Theme.BLACK or Theme.SECONDARY },
            sub = self:label{ text = sub, color = Theme.SECONDARY, max_width = text_w },
        }
        y = y + Theme.row_h
    end
    return y
end

--[[
Sizes the wordmark to the room the rest of the screen leaves, up to the full
content width (or 60% of a landscape screen). Too little room: no wordmark.
]]
function HomeScreen:layoutWordmark(y, W, H)
    self:freeWordmark()
    local aspect = Icons.aspect("wordmark")
    if not aspect then return y end
    local m = Theme.space.xl
    local below = (self.app:continueTarget() and Theme.card_h or 0) + 2 * Theme.space.l
        + Theme.touch + #self.app:catalog().packs * Theme.row_h + Theme.touch + Theme.space.s
    local max_w = W > H and math.floor(W * 0.6) or W - 2 * m
    local h = math.min(math.floor(max_w / aspect), H - y - below - 2 * Theme.space.l)
    if h < Theme.touch then return y end
    local w = math.floor(h * aspect)
    self.wordmark = {
        x = math.floor((W - w) / 2),
        y = y + Theme.space.l,
        widget = IconWidget:new{ file = Icons.path("wordmark"), width = w, height = h },
    }
    return y + h + 2 * Theme.space.l
end

function HomeScreen:layout(dimen)
    Label.freeAll(self.labels)
    self.labels = {}
    local W, H = dimen.w, dimen.h
    local m = Theme.space.xl
    self.W = W
    self.header:layout(0, 0, W)
    local y = self:layoutWordmark(Theme.header_h, W, H)
    y = self:layoutCard(y + Theme.space.s, W)
    self.section = self:label{ text = _("Packs"), size = "caption", color = Theme.SECONDARY }
    self.section_y = y + Theme.space.l
    self:layoutRows(self.section_y + self.section.h + Theme.space.xs, W)

    local t = Theme.touch
    self.help_btn:setRect(m - Theme.space.l, H - t - Theme.space.s, self.help_btn:preferredWidth(), t)
    self.version = self:label{ text = self.app.version or "", size = "caption", color = Theme.SECONDARY }
end

function HomeScreen:paintCard(bb)
    local card = self.card
    if not card then return end
    local th, r = card.thumb, card.rect
    bb:paintBorder(th.x, th.y, th.w, th.h, Theme.line.hair, Theme.BLACK)
    local g = Theme.space.s
    Picture.paint(bb, card.cont.puzzle, { x = th.x + g, y = th.y + g, w = th.w - 2 * g, h = th.h - 2 * g },
        { cells = card.cont.cells })
    local block = card.kicker.h + card.title.h + card.sub.h
    local y = r.y + math.floor((r.h - block) / 2)
    card.kicker:paint(bb, card.text_x, y)
    card.title:paint(bb, card.text_x, y + card.kicker.h)
    card.sub:paint(bb, card.text_x, y + card.kicker.h + card.title.h)
    Icons.paint(bb, "chevron", Theme.icon, "normal",
        { x = r.w - Theme.space.xl - Theme.touch, y = r.y, w = Theme.touch, h = r.h })
    bb:paintRect(Theme.space.xl, r.y + r.h - 1, r.w - 2 * Theme.space.xl, Theme.line.hair, Theme.BLACK)
end

function HomeScreen:paintRow(bb, row)
    local r, m = row.rect, Theme.space.xl
    local bar_h = Theme.line.strong
    local block = row.title.h + row.sub.h + (row.info.unlocked and (Theme.space.s + bar_h) or 0)
    local y = r.y + math.floor((r.h - block) / 2)
    row.title:paint(bb, m, y)
    row.sub:paint(bb, m, y + row.title.h)
    if row.info.unlocked then
        local by = y + row.title.h + row.sub.h + Theme.space.s
        local bw = math.floor(row.text_w * 0.6)
        bb:paintRect(m, by, bw, bar_h, Theme.TINT)
        if row.info.total > 0 then
            bb:paintRect(m, by, math.floor(bw * row.info.solved / row.info.total), bar_h, Theme.BLACK)
        end
    end
    Icons.paint(bb, row.info.unlocked and "chevron" or "lock", Theme.icon,
        row.info.unlocked and "normal" or "disabled",
        { x = r.w - m - Theme.touch, y = r.y, w = Theme.touch, h = r.h })
    bb:paintRect(m, r.y + r.h - 1, r.w - 2 * m, Theme.line.hair, Theme.BLACK)
end

function HomeScreen:paint(bb)
    self.header:paint(bb)
    if self.wordmark then self.wordmark.widget:paintTo(bb, self.wordmark.x, self.wordmark.y) end
    self:paintCard(bb)
    self.section:paint(bb, Theme.space.xl, self.section_y)
    for __, row in ipairs(self.rows) do self:paintRow(bb, row) end
    self.help_btn:paint(bb)
    local hb = self.help_btn.rect
    self.version:paintIn(bb, { x = 0, y = hb.y, w = self.W - Theme.space.xl, h = hb.h }, "right")
end

local function inside(rect, x, y)
    return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

-- Inverts a tapped area for one fast refresh, then runs the action.
function HomeScreen:pressRect(rect, action)
    Refresh.press(self.window, rect, function(bb) bb:invertRect(rect.x, rect.y, rect.w, rect.h) end)
    action()
end

function HomeScreen:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    local btn = self.header:buttonAt(x, y)
    if btn then
        Refresh.press(self.window, btn.rect, function(bb) btn:paint(bb, true) end)
        return btn.on_tap()
    end
    if self.card and inside(self.card.rect, x, y) then
        local p = self.card.cont.puzzle
        return self:pressRect(self.card.rect, function() self.app:openPuzzle(p) end)
    end
    for __, row in ipairs(self.rows) do
        if inside(row.rect, x, y) then
            if not row.info.unlocked then return end
            return self:pressRect(row.rect, function() self.app:showPack(row.pack.id) end)
        end
    end
    if self.help_btn:contains(x, y) then
        Refresh.press(self.window, self.help_btn.rect, function(bb) self.help_btn:paint(bb, true) end)
        self.help_btn.on_tap()
    end
end

return HomeScreen
