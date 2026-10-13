--[[
Header bar shared by all screens: back chevron on the left (omitted when no
on_back is given), the screen title left-aligned next to it, at most one
icon button on the right with an optional short secondary text (the timer)
before it, and a hairline divider underneath.
]]

local TextWidget = require("ui/widget/textwidget")
local IconButton = require("piclo/ui/components/icon_button")
local Label = require("piclo/ui/components/label")
local Theme = require("piclo/ui/theme")

local HeaderBar = {}
HeaderBar.__index = HeaderBar

--- opts: title, on_back, right = IconButton (optional), aside (text, optional)
function HeaderBar.new(opts)
    return setmetatable({
        title = opts.title or "",
        aside = opts.aside,
        back = opts.on_back and IconButton.new{ icon = "back", on_tap = opts.on_back },
        right = opts.right,
        rect = { x = 0, y = 0, w = 0, h = 0 },
    }, HeaderBar)
end

function HeaderBar:freeText()
    if self.text then
        self.text:free()
        self.text = nil
    end
    if self.aside_label then
        self.aside_label:free()
        self.aside_label = nil
    end
end

function HeaderBar:layout(x, y, w)
    local h = Theme.header_h
    self.rect = { x = x, y = y, w = w, h = h }
    local t = Theme.touch
    local by = y + math.floor((h - t) / 2)
    if self.back then self.back:setRect(x + Theme.space.xs, by, t, t) end
    local right_edge = x + w - Theme.space.l
    if self.right then
        self.right:setRect(x + w - Theme.space.xs - t, by, t, t)
        right_edge = self.right.rect.x - Theme.space.s
    end
    self:freeText()
    if self.aside then
        local l = Label.new{ text = self.aside, role = "numeric", color = Theme.SECONDARY }
        self.aside_label = l
        self.aside_rect = { x = right_edge - l.w, y = y, w = l.w, h = h }
        right_edge = right_edge - l.w - Theme.space.l
    end
    self.text_x = self.back and (self.back.rect.x + t + Theme.space.xs) or (x + Theme.space.xl)
    if self.title == "" then return end
    self.text = TextWidget:new{
        text = self.title,
        face = Theme.face("title"),
        max_width = math.max(1, right_edge - self.text_x),
    }
end

function HeaderBar:setTitle(title)
    self.title = title
    local r = self.rect
    self:layout(r.x, r.y, r.w)
end

--- Sets the secondary text on the right (nil for none); returns the header rect to refresh.
function HeaderBar:setAside(text)
    self.aside = text
    local r = self.rect
    self:layout(r.x, r.y, r.w)
    return r
end

function HeaderBar:paint(bb)
    local r = self.rect
    bb:paintRect(r.x, r.y, r.w, r.h, Theme.WHITE)
    if self.back then self.back:paint(bb) end
    if self.right then self.right:paint(bb) end
    if self.aside_label then self.aside_label:paintIn(bb, self.aside_rect, "right") end
    if self.text then
        local size = self.text:getSize()
        self.text:paintTo(bb, self.text_x, r.y + math.floor((r.h - size.h) / 2))
    end
    bb:paintRect(r.x, r.y + r.h - Theme.line.hair, r.w, Theme.line.hair, Theme.BLACK)
end

--- The button under a point, or nil.
function HeaderBar:buttonAt(x, y)
    if self.back and self.back:contains(x, y) then return self.back end
    if self.right and self.right:contains(x, y) then return self.right end
end

return HeaderBar
