-- Draws a hollow square with the icon's initial-sized notch, standing in for the SVG.
local IconWidget = {}
IconWidget.__index = IconWidget
IconWidget.created = 0
function IconWidget:new(o)
    IconWidget.created = IconWidget.created + 1
    return setmetatable(o, IconWidget)
end
function IconWidget:paintTo(bb, x, y)
    local w, h = self.width, self.height or self.width
    local t = math.max(2, math.floor(math.min(w, h) / 10))
    local black = require("ffi/blitbuffer").COLOR_BLACK
    bb:paintBorder(x + t, y + t, w - 2 * t, h - 2 * t, t, black)
    bb:paintRect(x + math.floor(w / 3), y + math.floor(h / 3), math.floor(w / 3), math.floor(h / 3), black)
end
function IconWidget:free() end
return IconWidget
