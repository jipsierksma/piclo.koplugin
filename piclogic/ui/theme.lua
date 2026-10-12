--[[
All design tokens: tones, line weights, spacing, sizes and type roles.
Screen code uses these names only, never raw numbers or colors.

Sizes are in KOReader's scaled units (Screen:scaleBySize). Call
Theme.update() after a screen size change to recompute them.
]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")

local Screen = Device.screen

local Theme = {}

-- Tones. Two grays only in the UI: a light tint for bands and pressed
-- states, and a secondary text gray that is still easy to read.
Theme.WHITE = Blitbuffer.COLOR_WHITE
Theme.BLACK = Blitbuffer.COLOR_BLACK
Theme.TINT = Blitbuffer.COLOR_GRAY_E
Theme.SECONDARY = Blitbuffer.COLOR_GRAY_6

-- Reveal tones 0..4: e-ink native gray levels, so no dithering is needed.
Theme.REVEAL = {
    [0] = Blitbuffer.Color8(0x00),
    Blitbuffer.Color8(0x44),
    Blitbuffer.Color8(0x77),
    Blitbuffer.Color8(0xAA),
    Blitbuffer.Color8(0xDD),
}

-- Type roles: the only fonts screen code may ask for. Faces are KOReader
-- fontmap keys (frontend/ui/font.lua): tfont is Noto Sans Bold, cfont Noto
-- Sans Regular, whose default figures are tabular, so clue digits align.
local ROLES = {
    title = { font = "tfont", size = 20 },
    body = { font = "cfont", size = 17 },
    numeric = { font = "cfont", size = 16 },
}

local SPACING = { xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32, xxxl = 48 }

function Theme.update()
    local s = function(v) return Screen:scaleBySize(v) end
    Theme.line = { hair = 1, regular = s(2), strong = s(3) }
    Theme.space = {}
    for k, v in pairs(SPACING) do Theme.space[k] = s(v) end
    Theme.header_h = s(56)
    Theme.touch = s(48)
    Theme.icon = s(26)
    Theme.toolbar_h = s(64)
    Theme.min_cell = s(28)
    Theme.max_cell = s(72)
    -- scaleBySize is a ceil'd multiply; this ratio lets faceForPx undo it.
    Theme.scale = Screen:scaleBySize(1000) / 1000
    -- White gap between a filled square and its grid lines, so neighbouring
    -- fills read as a picture rather than one black blob.
    Theme.fill_gap = math.max(1, math.floor(Theme.scale))
end

--- Face for a type role at its standard size.
function Theme.face(role)
    local r = ROLES[role]
    return Font:getFace(r.font, r.size)
end

--[[
Face for a type role at an exact pixel size. Font:getFace scales the size it
is given, so convert back to unscaled units first; the 0.5 keeps the ceil
inside getFace from rounding up a pixel.
]]
function Theme.faceForPx(role, px)
    return Font:getFace(ROLES[role].font, math.max(1, (px - 0.5) / Theme.scale))
end

Theme.update()

return Theme
