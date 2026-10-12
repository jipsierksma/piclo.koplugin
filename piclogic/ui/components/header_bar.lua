--[[
Header bar shared by all screens: back chevron on the left, the screen title
left-aligned next to it, at most one icon button on the right, and a hairline
divider underneath.
]]

local TextWidget = require("ui/widget/textwidget")
local IconButton = require("piclogic/ui/components/icon_button")
local Theme = require("piclogic/ui/theme")

local HeaderBar = {}
HeaderBar.__index = HeaderBar

--- opts: title, on_back, right = IconButton (optional)
function HeaderBar.new(opts)
    return setmetatable({
        title = opts.title or "",
        back = IconButton.new{ icon = "back", on_tap = opts.on_back },
        right = opts.right,
        rect = { x = 0, y = 0, w = 0, h = 0 },
    }, HeaderBar)
end

function HeaderBar:freeText()
    if self.text then
        self.text:free()
        self.text = nil
    end
end

function HeaderBar:layout(x, y, w)
    local h = Theme.header_h
    self.rect = { x = x, y = y, w = w, h = h }
    local t = Theme.touch
    local by = y + math.floor((h - t) / 2)
    self.back:setRect(x + Theme.space.xs, by, t, t)
    local right_edge = x + w - Theme.space.l
    if self.right then
        self.right:setRect(x + w - Theme.space.xs - t, by, t, t)
        right_edge = self.right.rect.x - Theme.space.s
    end
    self.text_x = self.back.rect.x + t + Theme.space.xs
    self:freeText()
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

function HeaderBar:paint(bb)
    local r = self.rect
    bb:paintRect(r.x, r.y, r.w, r.h, Theme.WHITE)
    self.back:paint(bb)
    if self.right then self.right:paint(bb) end
    if self.text then
        local size = self.text:getSize()
        self.text:paintTo(bb, self.text_x, r.y + math.floor((r.h - size.h) / 2))
    end
    bb:paintRect(r.x, r.y + r.h - Theme.line.hair, r.w, Theme.line.hair, Theme.BLACK)
end

--- The button under a point, or nil.
function HeaderBar:buttonAt(x, y)
    if self.back:contains(x, y) then return self.back end
    if self.right and self.right:contains(x, y) then return self.right end
end

return HeaderBar
