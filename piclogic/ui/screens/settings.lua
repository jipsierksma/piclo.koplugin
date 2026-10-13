--[[
Settings: grouped rows, a group title in small secondary type, then rows
with the label (and a line of explanation) on the left and the control on
the right: a switch, or a segmented control for a few choices. When a
control doesn't fit beside its label it moves below it. Pages turn with
swipes and the page-turn keys when the rows don't fit one screen.

Changes are saved at once; screens read settings when they are built, so
returning to a game shows the new behaviour straight away.
]]

local T = require("ffi/util").template
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local HeaderBar = require("piclogic/ui/components/header_bar")
local Icons = require("piclogic/ui/icons")
local Label = require("piclogic/ui/components/label")
local Refresh = require("piclogic/ui/refresh")
local Segmented = require("piclogic/ui/components/segmented")
local Sheet = require("piclogic/ui/components/sheet")
local Switch = require("piclogic/ui/components/switch")
local Theme = require("piclogic/ui/theme")

local SettingsScreen = {}
SettingsScreen.__index = SettingsScreen

-- choices: { {value, text}, ... }; notes: per value, or one string.
local function groups()
    return {
        { title = _("Gameplay"), rows = {
            { key = "mistakes", label = _("Mistake checking"),
                choices = { { "off", _("Off") }, { "request", _("On request") }, { "instant", _("Instant") } },
                notes = {
                    off = _("No feedback while you play"),
                    request = _("A check button marks wrong squares"),
                    instant = _("Wrong fills are turned into crosses"),
                } },
            { key = "highlight_done", label = _("Highlight completed clues"), switch = true,
                notes = _("Finished numbers turn gray") },
            { key = "hold_action", label = _("Hold a square to"),
                choices = { { "opposite", _("Use other tool") }, { "cross", _("Cross") } } },
        } },
        { title = _("Display"), rows = {
            { key = "show_timer", label = _("Show timer in header"), switch = true,
                notes = _("Updates once a minute") },
            { key = "deghost_every", label = _("Clear ghosting every"),
                choices = { { 10, "10" }, { 20, "20" }, { 50, "50" }, { 0, _("Never") } },
                notes = _("Moves between flashes") },
            { key = "rail_side", label = _("Toolbar in landscape"),
                choices = { { "left", _("Left") }, { "right", _("Right") } } },
        } },
        { title = _("Data"), rows = {
            { action = "reset", label = _("Reset all progress"),
                notes = _("Clears every board, time and solved picture") },
        } },
    }
end

--- opts: app, cleared (progress was just reset)
function SettingsScreen.new(opts)
    local app = opts.app
    local self = setmetatable({ app = app, cleared = opts.cleared, page = 1, labels = {}, controls = {} },
        SettingsScreen)
    self.header = HeaderBar.new{ title = _("Settings"), on_back = function() app:back() end }
    return self
end

function SettingsScreen:freeLayout()
    Label.freeAll(self.labels)
    self.labels = {}
    for __, c in ipairs(self.controls) do
        if c.free then c:free() end
    end
    self.controls = {}
end

function SettingsScreen:free()
    self.header:freeText()
    self:freeLayout()
end

function SettingsScreen:label(opts)
    local l = Label.new(opts)
    self.labels[#self.labels + 1] = l
    return l
end

function SettingsScreen:noteFor(row)
    if row.action == "reset" and self.cleared then return _("All progress cleared") end
    local n = row.notes
    if type(n) == "table" then return n[self.app:setting(row.key)] end
    return n
end

-- Builds a row's control (or nil) and returns it with its natural size.
function SettingsScreen:control(row)
    if row.switch then
        local sw = Switch.new{ on = self.app:setting(row.key) }
        local w, h = Switch.size()
        return sw, w, h
    elseif row.choices then
        local items = {}
        for __, ch in ipairs(row.choices) do items[#items + 1] = { id = ch[1], text = ch[2] } end
        local seg = Segmented.new{ items = items, selected = self.app:setting(row.key) }
        self.controls[#self.controls + 1] = seg
        return seg, seg:preferredWidth(), Theme.touch
    end
end

-- Lays one row out at y within [x, x + w); returns its height. The control
-- sits beside the text when label and note fit uncut, else below it.
function SettingsScreen:layoutRow(row, x, y, w)
    local entry = { row = row }
    local ctrl, cw, ch = self:control(row)
    local note = self:noteFor(row)
    local title = self:label{ text = row.label }
    local note_l = note and self:label{ text = note, size = "caption", color = Theme.SECONDARY }
    local natural = math.max(title.w, note_l and note_l.w or 0)
    if row.action then cw = Theme.touch end
    local beside = not ctrl or natural + Theme.space.xl + cw <= w
    local text_w = beside and (w - ((ctrl or row.action) and cw + Theme.space.xl or 0)) or w
    entry.text_w = text_w
    entry.title = self:label{ text = row.label, max_width = text_w }
    entry.note = note and self:label{ text = note, size = "caption", color = Theme.SECONDARY, max_width = text_w }
    local text_h = entry.title.h + (entry.note and entry.note.h or 0)
    local pad = Theme.space.m
    local h
    if beside then
        h = math.max(Theme.touch, text_h, ch or 0) + 2 * pad
        entry.text_y = y + math.floor((h - text_h) / 2)
        if ctrl then ctrl:setRect(x + w - cw, y + math.floor((h - ch) / 2), cw, ch) end
    else
        entry.text_y = y + pad
        local cy = entry.text_y + text_h + Theme.space.s
        cw = math.min(cw, w)
        ctrl:setRect(x + w - cw, cy, cw, ch)
        h = cy + ch + pad - y
    end
    entry.control = ctrl
    entry.rect = { x = 0, y = y, w = self.dimen.w, h = h }
    entry.x, entry.w = x, w
    return entry, h
end

-- Flows the groups into pages between top and bottom.
function SettingsScreen:paginate(x, w, top, bottom)
    self:freeLayout()
    local pages = { {} }
    local y = top
    for __, group in ipairs(groups()) do
        local heading = self:label{ text = group.title, size = "caption", color = Theme.SECONDARY }
        local heading_h = Theme.space.l + heading.h + Theme.space.xs
        for k, row in ipairs(group.rows) do
            local entry, h = self:layoutRow(row, x, 0, w)
            local need = h + (k == 1 and heading_h or 0)
            if y + need > bottom and #pages[#pages] > 0 then
                pages[#pages + 1] = {}
                y = top
            end
            local page = pages[#pages]
            if k == 1 or #page == 0 then
                page[#page + 1] = { heading = heading, x = x, y = y + Theme.space.l }
                y = y + heading_h
            end
            self:place(entry, y)
            page[#page + 1] = entry
            y = y + h
        end
    end
    return pages
end

function SettingsScreen:layout(dimen)
    self.dimen = dimen
    local W, H = dimen.w, dimen.h
    self.header:layout(0, 0, W)
    local m = Theme.space.xl
    local w = math.min(W - 2 * m, Theme.touch * 16)
    local x = math.floor((W - w) / 2)
    local top = Theme.header_h + Theme.space.s
    -- Room for a page indicator only when one is needed.
    self.pages = self:paginate(x, w, top, H - Theme.space.l)
    local bottom = H - Theme.touch - Theme.space.s
    if #self.pages > 1 then self.pages = self:paginate(x, w, top, bottom) end
    self.page = math.max(1, math.min(self.page, #self.pages))
    self.pager = nil
    if #self.pages > 1 then
        self.pager = self:label{ text = T(_("%1 / %2"), self.page, #self.pages), size = "caption",
            color = Theme.SECONDARY }
        self.pager_rect = { x = 0, y = bottom, w = W, h = Theme.touch }
    end
end

-- Moves an entry laid out at y = 0 down to y.
function SettingsScreen:place(entry, y)
    entry.rect.y = entry.rect.y + y
    entry.text_y = entry.text_y + y
    local c = entry.control
    if c then
        local r = c.rect
        c:setRect(r.x, r.y + y, r.w, r.h)
    end
end

function SettingsScreen:paintEntry(bb, e)
    if e.heading then
        e.heading:paint(bb, e.x, e.y)
        return
    end
    bb:paintRect(e.rect.x, e.rect.y, e.rect.w, e.rect.h, Theme.WHITE)
    e.title:paint(bb, e.x, e.text_y)
    if e.note then e.note:paint(bb, e.x, e.text_y + e.title.h) end
    if e.control then e.control:paint(bb) end
    if e.row.action then
        Icons.paint(bb, "chevron", Theme.icon, "normal",
            { x = e.x + e.w - Theme.touch, y = e.rect.y, w = Theme.touch, h = e.rect.h })
    end
    bb:paintRect(e.x, e.rect.y + e.rect.h - 1, e.w, Theme.line.hair, Theme.BLACK)
end

function SettingsScreen:paint(bb)
    self.header:paint(bb)
    for __, e in ipairs(self.pages[self.page]) do self:paintEntry(bb, e) end
    if self.pager then self.pager:paintIn(bb, self.pager_rect, "center") end
end

-- Saves a new value and repaints the row (its note may depend on the value).
function SettingsScreen:change(e, value)
    self.app:setSetting(e.row.key, value)
    if type(e.row.notes) == "table" then
        e.note = self:label{ text = self:noteFor(e.row), size = "caption", color = Theme.SECONDARY,
            max_width = e.text_w }
    end
    Refresh.regions(self.window, "ui", { e.rect }, function(bb) self:paintEntry(bb, e) end)
end

function SettingsScreen:confirmReset()
    local app, window = self.app, self.window
    window:showSheet(Sheet.confirm{
        title = _("Reset all progress?"),
        text = _("Every board, time and solved picture will be cleared, and packs lock again. Settings stay. This can't be undone."),
        ok_text = _("Reset"),
        on_ok = function()
            window:closeSheet(false)
            app:resetProgress()
        end,
    })
end

local function inside(r, x, y)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

function SettingsScreen:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    local btn = self.header:buttonAt(x, y)
    if btn then
        Refresh.press(self.window, btn.rect, function(bb) btn:paint(bb, true) end)
        return btn.on_tap()
    end
    for __, e in ipairs(self.pages[self.page]) do
        if e.row and inside(e.rect, x, y) then
            local row, c = e.row, e.control
            if row.switch then
                c:set(not c.on)
                return self:change(e, c.on)
            elseif row.choices then
                local k = c:contains(x, y) and c:segmentAt(x, y)
                if k and c:select(c.items[k].id) then self:change(e, c.items[k].id) end
                return
            elseif row.action == "reset" then
                local r = e.rect
                Refresh.press(self.window, r, function(bb) bb:invertRect(r.x, r.y, r.w, r.h) end)
                Refresh.regions(self.window, "fast", { r }, function(bb) self:paintEntry(bb, e) end)
                return self:confirmReset()
            end
        end
    end
end

function SettingsScreen:changePage(delta)
    local page = self.page + delta
    if page < 1 or page > #self.pages then return end
    self.page = page
    self:layout(self.dimen)
    UIManager:setDirty(self.window, "ui")
end

function SettingsScreen:onSwipe(ges)
    if ges.direction == "west" then
        self:changePage(1)
    elseif ges.direction == "east" then
        self:changePage(-1)
    end
end

function SettingsScreen:onPageKey(forward)
    self:changePage(forward and 1 or -1)
end

return SettingsScreen
