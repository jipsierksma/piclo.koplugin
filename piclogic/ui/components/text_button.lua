--[[
Text button in two weights: primary is an inverted pill (white text on
black), quiet is plain text. Both keep a full touch-height target. Pressed
feedback inverts the target for one fast refresh.
]]

local Label = require("piclogic/ui/components/label")
local Theme = require("piclogic/ui/theme")

local TextButton = {}
TextButton.__index = TextButton

--- opts: text, primary (bool), on_tap
function TextButton.new(opts)
    local self = setmetatable({
        text = opts.text,
        primary = opts.primary,
        on_tap = opts.on_tap,
        enabled = true,
        rect = { x = 0, y = 0, w = 0, h = 0 },
    }, TextButton)
    self.label = Label.new{
        text = opts.text,
        role = "body",
        color = opts.primary and Theme.WHITE or Theme.BLACK,
    }
    return self
end

--- Natural width: the text plus generous side padding (wider for pills).
function TextButton:preferredWidth()
    local pad = self.primary and Theme.space.xxl or Theme.space.l
    return self.label.w + 2 * pad
end

function TextButton:setRect(x, y, w, h)
    self.rect = { x = x, y = y, w = w, h = h }
end

function TextButton:contains(x, y)
    local r = self.rect
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

function TextButton:paint(bb, pressed)
    local r = self.rect
    bb:paintRect(r.x, r.y, r.w, r.h, Theme.WHITE)
    if self.primary then
        bb:paintRoundedRect(r.x, r.y, r.w, r.h, Theme.BLACK, math.floor(r.h / 2))
    end
    self.label:paintIn(bb, r, "center")
    if pressed then bb:invertRect(r.x, r.y, r.w, r.h) end
end

function TextButton:free()
    self.label:free()
end

return TextButton
