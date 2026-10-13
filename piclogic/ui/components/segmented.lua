--[[
Segmented control: a row (or column, in the landscape rail) of icon or
text segments with one selected. The selected segment is inverted: black
with a white glyph or label. One regular-weight outline holds the segments,
with hairline dividers between them.
]]

local Icons = require("piclogic/ui/icons")
local Label = require("piclogic/ui/components/label")
local Theme = require("piclogic/ui/theme")

local Segmented = {}
Segmented.__index = Segmented

--- opts: items = { {id, icon} or {id, text}, ... }, selected = id, on_change(id)
function Segmented.new(opts)
    local self = setmetatable({
        items = opts.items,
        selected = opts.selected,
        on_change = opts.on_change,
        rect = { x = 0, y = 0, w = 0, h = 0 },
        segs = {},
    }, Segmented)
    for __, item in ipairs(self.items) do
        if item.text then
            item.dark = Label.new{ text = item.text, color = Theme.BLACK }
            item.light = Label.new{ text = item.text, color = Theme.WHITE }
        end
    end
    return self
end

function Segmented:free()
    for __, item in ipairs(self.items) do
        if item.dark then
            item.dark:free()
            item.light:free()
            item.dark, item.light = nil, nil
        end
    end
end

--- Width for text segments: equal segments, each fitting the widest label.
function Segmented:preferredWidth()
    local widest = 0
    for __, item in ipairs(self.items) do
        widest = math.max(widest, item.dark and item.dark.w or Theme.icon)
    end
    return #self.items * (widest + 2 * Theme.space.l)
end

--- Lays segments out along the long side of the rect.
function Segmented:setRect(x, y, w, h)
    self.rect = { x = x, y = y, w = w, h = h }
    local n = #self.items
    local vertical = h > w
    self.segs = {}
    for k = 1, n do
        if vertical then
            local y0 = y + math.floor((k - 1) * h / n)
            local y1 = y + math.floor(k * h / n)
            self.segs[k] = { x = x, y = y0, w = w, h = y1 - y0 }
        else
            local x0 = x + math.floor((k - 1) * w / n)
            local x1 = x + math.floor(k * w / n)
            self.segs[k] = { x = x0, y = y, w = x1 - x0, h = h }
        end
    end
    self.vertical = vertical
end

function Segmented:contains(x, y)
    local r = self.rect
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

--- Index of the segment under a point, or nil.
function Segmented:segmentAt(x, y)
    for k, s in ipairs(self.segs) do
        if x >= s.x and x < s.x + s.w and y >= s.y and y < s.y + s.h then
            return k
        end
    end
end

function Segmented:select(id)
    local changed = self.selected ~= id
    self.selected = id
    return changed
end

function Segmented:paint(bb)
    local r = self.rect
    local lw = Theme.line.regular
    for k, item in ipairs(self.items) do
        local s = self.segs[k]
        local on = item.id == self.selected
        bb:paintRect(s.x, s.y, s.w, s.h, on and Theme.BLACK or Theme.WHITE)
        if item.dark then
            (on and item.light or item.dark):paintIn(bb, s, "center")
        else
            Icons.paint(bb, item.icon, Theme.icon, on and "inverted" or "normal", s)
        end
        if k > 1 then
            if self.vertical then
                bb:paintRect(s.x, s.y, s.w, Theme.line.hair, Theme.BLACK)
            else
                bb:paintRect(s.x, s.y, Theme.line.hair, s.h, Theme.BLACK)
            end
        end
    end
    bb:paintBorder(r.x, r.y, r.w, r.h, lw, Theme.BLACK)
end

return Segmented
