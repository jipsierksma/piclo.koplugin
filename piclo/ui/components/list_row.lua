--[[
A tappable list row, as on the title screen and the Packs screen: a bold
title (gray when dimmed, with a check mark after it when done), an optional
gray line under it, an optional progress bar, a chevron or a lock on the
right, and a hairline divider underneath.
]]

local Icons = require("piclo/ui/icons")
local Label = require("piclo/ui/components/label")
local Theme = require("piclo/ui/theme")

local ListRow = {}
ListRow.__index = ListRow

--[[
opts: rect {x, y, w, h}, title, sub (optional), dimmed, done, locked,
progress (0..1, optional: draws the bar)
]]
function ListRow.new(opts)
    local self = setmetatable({
        rect = opts.rect,
        done = opts.done,
        locked = opts.locked,
        progress = opts.progress,
    }, ListRow)
    local m = Theme.space.xl
    self.text_w = opts.rect.w - 2 * m - Theme.touch
    -- A done row keeps room for the check mark after its title.
    local title_w = opts.done and (self.text_w - Theme.space.xs - Theme.icon) or self.text_w
    self.title = Label.new{ text = opts.title, role = "title", max_width = title_w,
        color = opts.dimmed and Theme.SECONDARY or Theme.BLACK }
    if opts.sub then
        self.sub = Label.new{ text = opts.sub, color = Theme.SECONDARY, max_width = self.text_w }
    end
    return self
end

function ListRow:free()
    self.title:free()
    if self.sub then self.sub:free() end
end

function ListRow:contains(x, y)
    local r = self.rect
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

function ListRow:paint(bb)
    local r, m = self.rect, Theme.space.xl
    local x = r.x + m
    local bar_h = Theme.line.strong
    local block = self.title.h + (self.sub and self.sub.h or 0)
        + (self.progress and (Theme.space.s + bar_h) or 0)
    local y = r.y + math.floor((r.h - block) / 2)
    self.title:paint(bb, x, y)
    if self.done then
        Icons.paint(bb, "check", Theme.icon, "normal",
            { x = x + self.title.w + Theme.space.xs, y = y, w = Theme.icon, h = self.title.h })
    end
    y = y + self.title.h
    if self.sub then
        self.sub:paint(bb, x, y)
        y = y + self.sub.h
    end
    if self.progress then
        local bw = math.floor(self.text_w * 0.6)
        y = y + Theme.space.s
        bb:paintRect(x, y, bw, bar_h, Theme.TINT)
        bb:paintRect(x, y, math.floor(bw * self.progress), bar_h, Theme.BLACK)
    end
    Icons.paint(bb, self.locked and "lock" or "chevron", Theme.icon, self.locked and "disabled" or "normal",
        { x = r.x + r.w - m - Theme.touch, y = r.y, w = Theme.touch, h = r.h })
    bb:paintRect(x, r.y + r.h - 1, r.w - 2 * m, Theme.line.hair, Theme.BLACK)
end

--- Inverts the row for press feedback.
function ListRow:paintPressed(bb)
    local r = self.rect
    bb:invertRect(r.x, r.y, r.w, r.h)
end

return ListRow
