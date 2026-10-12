--[[
Icon-only button: a touch target of at least Theme.touch square with the
icon centered in it. Disabled buttons draw in secondary gray and ignore
taps. Pressed shows a black rounded square behind a white icon (pure black
and white, for the fast refresh).
]]

local Icons = require("piclogic/ui/icons")
local Theme = require("piclogic/ui/theme")

local IconButton = {}
IconButton.__index = IconButton

--- opts: icon (name), on_tap (function), enabled (default true)
function IconButton.new(opts)
    return setmetatable({
        icon = opts.icon,
        on_tap = opts.on_tap,
        enabled = opts.enabled ~= false,
        rect = { x = 0, y = 0, w = 0, h = 0 },
    }, IconButton)
end

function IconButton:setRect(x, y, w, h)
    self.rect = { x = x, y = y, w = w, h = h }
end

function IconButton:setEnabled(enabled)
    local changed = self.enabled ~= enabled
    self.enabled = enabled
    return changed
end

function IconButton:contains(x, y)
    local r = self.rect
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

function IconButton:paint(bb, pressed)
    local r = self.rect
    bb:paintRect(r.x, r.y, r.w, r.h, Theme.WHITE)
    if pressed then
        bb:paintRoundedRect(r.x, r.y, r.w, r.h, Theme.BLACK, Theme.space.s)
    end
    local variant = pressed and "inverted" or (self.enabled and "normal" or "disabled")
    Icons.paint(bb, self.icon, Theme.icon, variant, r)
end

return IconButton
