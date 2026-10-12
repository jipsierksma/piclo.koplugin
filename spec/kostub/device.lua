-- A Kindle Oasis 3 sized screen by default; tests may resize or rotate it.
local BB = require("ffi/blitbuffer")

local Screen = { w = 1264, h = 1680, rotation = 0 }

function Screen:getWidth() return self.w end
function Screen:getHeight() return self.h end
function Screen:getRotationMode() return self.rotation end

-- Same formula as base/ffi/framebuffer.lua without a DPI override.
function Screen:scaleBySize(px)
    local s = math.min(self.w, self.h) / 600
    return math.ceil(px * s)
end

function Screen:setRotationMode(mode)
    if mode % 2 ~= self.rotation % 2 then self.w, self.h = self.h, self.w end
    self.rotation = mode
    self.bb = BB.new(self.w, self.h)
end

Screen.bb = BB.new(Screen.w, Screen.h)

local Device = {
    screen = Screen,
    input = { group = { Back = { "Back" }, PgFwd = { "RPgFwd" }, PgBack = { "RPgBack" } } },
}
function Device:isTouchDevice() return true end
function Device:hasKeys() return true end
return Device
