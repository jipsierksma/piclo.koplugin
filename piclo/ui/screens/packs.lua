--[[
Packs screen: how many puzzles are solved overall, then one row per pack.
  done         a check mark after the title, "All 8 solved"
  open         "3 of 12 solved" over a progress bar
  locked       gray title, the unlock rule, a lock instead of the chevron
Pages with swipes and the page-turn keys when the rows don't fit one screen.
]]

local T = require("ffi/util").template
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local HeaderBar = require("piclo/ui/components/header_bar")
local Label = require("piclo/ui/components/label")
local ListRow = require("piclo/ui/components/list_row")
local Refresh = require("piclo/ui/refresh")
local Theme = require("piclo/ui/theme")

local PacksScreen = {}
PacksScreen.__index = PacksScreen

local function sizeText(puzzle)
    return T(_("%1×%2"), puzzle.w, puzzle.h)
end

-- "10×10", or "5×5 to 8×8" for a pack whose grids grow.
local function packSize(pack)
    local small, large = pack.puzzles[1], pack.puzzles[1]
    for __, p in ipairs(pack.puzzles) do
        if p.w * p.h < small.w * small.h then small = p end
        if p.w * p.h > large.w * large.h then large = p end
    end
    if small == large or sizeText(small) == sizeText(large) then return sizeText(small) end
    return T(_("%1 to %2"), sizeText(small), sizeText(large))
end

--- opts: app, page (1-based, optional)
function PacksScreen.new(opts)
    local app = opts.app
    local self = setmetatable({ app = app, page = opts.page or 1, labels = {} }, PacksScreen)
    self.header = HeaderBar.new{ title = _("Packs"), on_back = function() app:back() end }
    return self
end

function PacksScreen:freeRows()
    Label.freeAll(self.labels)
    self.labels = {}
    for __, row in ipairs(self.rows or {}) do row:free() end
    self.rows = {}
end

function PacksScreen:free()
    self.header:freeText()
    self:freeRows()
end

function PacksScreen:label(opts)
    local l = Label.new(opts)
    self.labels[#self.labels + 1] = l
    return l
end

function PacksScreen:row(pack, y, W)
    local info = self.app:collection():packInfo(pack)
    local done = info.unlocked and info.solved == info.total
    local sub
    if not info.unlocked then
        sub = T(_("Solve %1 in %2 to unlock"), info.rule.count, info.rule.after_title)
    elseif done then
        sub = T(_("%1 · All %2 solved"), packSize(pack), info.total)
    else
        sub = T(_("%1 · %2 of %3 solved"), packSize(pack), info.solved, info.total)
    end
    local row = ListRow.new{
        rect = { x = 0, y = y, w = W, h = Theme.row_h },
        title = pack.title,
        sub = sub,
        dimmed = not info.unlocked,
        locked = not info.unlocked,
        done = done,
        progress = (info.unlocked and not done) and info.solved / info.total or nil,
    }
    row.pack, row.info = pack, info
    return row
end

function PacksScreen:layout(dimen)
    self.dimen = dimen
    self:freeRows()
    local W, H = dimen.w, dimen.h
    self.header:layout(0, 0, W)
    local collection = self.app:collection()
    local solved, total = collection:totals()
    -- Same size as the same count beside Packs on the title screen.
    self.summary = self:label{ text = T(_("%1 of %2 solved"), solved, total), color = Theme.SECONDARY }
    self.summary_y = Theme.header_h + Theme.space.l
    local top = self.summary_y + self.summary.h + Theme.space.xs
    local bottom = H - Theme.space.s

    local packs = self.app:catalog().packs
    local per_page = math.max(1, math.floor((bottom - top) / Theme.row_h))
    if per_page < #packs then
        per_page = math.max(1, math.floor((bottom - Theme.touch - top) / Theme.row_h))
    end
    self.pages = math.ceil(#packs / per_page)
    self.page = math.max(1, math.min(self.page, self.pages))

    local first = (self.page - 1) * per_page + 1
    for k = first, math.min(#packs, first + per_page - 1) do
        self.rows[#self.rows + 1] = self:row(packs[k], top + (k - first) * Theme.row_h, W)
    end
    self.pager = nil
    if self.pages > 1 then
        self.pager = self:label{ text = T(_("%1 / %2"), self.page, self.pages), size = "caption",
            color = Theme.SECONDARY }
        self.pager_rect = { x = 0, y = H - Theme.touch - Theme.space.s, w = W, h = Theme.touch }
    end
end

function PacksScreen:paint(bb)
    self.header:paint(bb)
    self.summary:paint(bb, Theme.space.xl, self.summary_y)
    for __, row in ipairs(self.rows) do row:paint(bb) end
    if self.pager then self.pager:paintIn(bb, self.pager_rect, "center") end
end

function PacksScreen:changePage(delta)
    local page = self.page + delta
    if page < 1 or page > self.pages then return end
    self.page = page
    self.app:rememberPage(page)
    self:layout(self.dimen)
    UIManager:setDirty(self.window, "ui")
end

function PacksScreen:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    local btn = self.header:buttonAt(x, y)
    if btn then
        Refresh.press(self.window, btn.rect, function(bb) btn:paint(bb, true) end)
        return btn.on_tap()
    end
    for __, row in ipairs(self.rows) do
        if row:contains(x, y) then
            if row.locked then return end
            Refresh.press(self.window, row.rect, function(bb) row:paintPressed(bb) end)
            return self.app:showPack(row.pack.id)
        end
    end
end

function PacksScreen:onSwipe(ges)
    if ges.direction == "west" then
        self:changePage(1)
    elseif ges.direction == "east" then
        self:changePage(-1)
    end
end

function PacksScreen:onPageKey(forward)
    self:changePage(forward and 1 or -1)
end

return PacksScreen
