--[[
One line of text in a theme type role, truncated with an ellipsis to a
maximum width. Wraps KOReader's TextWidget; build labels in layout(), paint
them in paint(), free them when the screen goes away.
]]

local TextWidget = require("ui/widget/textwidget")
local Theme = require("piclogic/ui/theme")

local Label = {}
Label.__index = Label

--- opts: text, role ("title"|"body"|"numeric"), size (type scale step), color, max_width
function Label.new(opts)
    local self = setmetatable({}, Label)
    self.widget = TextWidget:new{
        text = opts.text or "",
        face = Theme.face(opts.role or "body", opts.size),
        fgcolor = opts.color or Theme.BLACK,
        max_width = opts.max_width and math.max(1, opts.max_width) or nil,
    }
    local size = self.widget:getSize()
    self.w, self.h = size.w, size.h
    return self
end

function Label:paint(bb, x, y)
    self.widget:paintTo(bb, x, y)
end

--- Paints inside rect, aligned "left" | "center" | "right", vertically centered.
function Label:paintIn(bb, rect, align)
    local x = rect.x
    if align == "center" then
        x = rect.x + math.floor((rect.w - self.w) / 2)
    elseif align == "right" then
        x = rect.x + rect.w - self.w
    end
    self.widget:paintTo(bb, x, rect.y + math.floor((rect.h - self.h) / 2))
end

function Label:free()
    self.widget:free()
end

--- Frees every label in a list (nil entries allowed).
function Label.freeAll(list)
    for _, l in pairs(list) do
        if l then l:free() end
    end
end

return Label
