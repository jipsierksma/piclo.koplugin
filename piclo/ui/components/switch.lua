--[[
On/off switch for settings rows. Pure black and white so a toggle can use
the fast refresh: off is an outlined track with a black knob on the left,
on is a black track with a white knob on the right and a check mark in the
knob. Knob side and check mark still read right in night mode, when
inverting the screen swaps black and white.
]]

local Icons = require("piclo/ui/icons")
local Theme = require("piclo/ui/theme")

local Switch = {}
Switch.__index = Switch

--- opts: on (bool)
function Switch.new(opts)
    return setmetatable({ on = opts.on and true or false, rect = { x = 0, y = 0, w = 0, h = 0 } }, Switch)
end

--- Track size: about half a touch target tall, a little under twice as wide.
function Switch.size()
    local h = math.floor(Theme.touch * 0.6)
    return math.floor(h * 1.8), h
end

function Switch:setRect(x, y, w, h)
    self.rect = { x = x, y = y, w = w, h = h }
end

function Switch:set(on)
    self.on = on and true or false
end

function Switch:paint(bb)
    local r = self.rect
    local radius = math.floor(r.h / 2)
    bb:paintRect(r.x, r.y, r.w, r.h, Theme.WHITE)
    local inset = Theme.line.strong
    local knob = r.h - 2 * inset
    local ky = r.y + inset
    if self.on then
        bb:paintRoundedRect(r.x, r.y, r.w, r.h, Theme.BLACK, radius)
        local kx = r.x + r.w - inset - knob
        bb:paintRoundedRect(kx, ky, knob, knob, Theme.WHITE, math.floor(knob / 2))
        -- Small enough to stay inside the round knob.
        local mark = math.floor(knob * 0.68)
        Icons.paint(bb, "check", mark, "normal", { x = kx, y = ky, w = knob, h = knob })
    else
        bb:paintBorder(r.x, r.y, r.w, r.h, Theme.line.regular, Theme.BLACK, radius)
        bb:paintRoundedRect(r.x + inset, ky, knob, knob, Theme.BLACK, math.floor(knob / 2))
    end
end

return Switch
