--[[
Text button in two weights: primary is an inverted pill (white text on
black), quiet is plain text. Both keep a full touch-height target.

Pressed states keep the pill shape and stay pure black and white, because
the "fast" waveform used for press feedback can't show grays: a primary
button turns into an outlined pill, a quiet one into a black pill.
]]

local Label = require("piclo/ui/components/label")
local Theme = require("piclo/ui/theme")

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
    self.dark = Label.new{ text = opts.text, role = "body", color = Theme.BLACK }
    self.light = Label.new{ text = opts.text, role = "body", color = Theme.WHITE }
    return self
end

--- Natural width: the text plus generous side padding (wider for pills).
function TextButton:preferredWidth()
    local pad = self.primary and Theme.space.xxl or Theme.space.l
    return self.dark.w + 2 * pad
end

--- Narrowest width that still keeps the text clear of the pill's ends.
function TextButton:minWidth()
    return self.dark.w + 2 * Theme.space.s
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
    local radius = math.floor(r.h / 2)
    bb:paintRect(r.x, r.y, r.w, r.h, Theme.WHITE)
    local filled = (self.primary and not pressed) or (not self.primary and pressed)
    if filled then
        bb:paintRoundedRect(r.x, r.y, r.w, r.h, Theme.BLACK, radius)
    elseif self.primary then
        bb:paintBorder(r.x, r.y, r.w, r.h, Theme.line.regular, Theme.BLACK, radius)
    end
    local label = filled and self.light or self.dark
    label:paintIn(bb, r, "center")
end

function TextButton:free()
    self.dark:free()
    self.light:free()
end

return TextButton
