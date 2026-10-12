-- Draws a hollow square with the icon's initial-sized notch, standing in for the SVG.
local IconWidget = {}
IconWidget.__index = IconWidget
IconWidget.created = 0
function IconWidget:new(o)
    IconWidget.created = IconWidget.created + 1
    return setmetatable(o, IconWidget)
end
function IconWidget:paintTo(bb, x, y)
    local s = self.width
    local t = math.max(2, math.floor(s / 10))
    bb:paintBorder(x + t, y + t, s - 2 * t, s - 2 * t, t, { a = 0 })
    bb:paintRect(x + math.floor(s / 3), y + math.floor(s / 3), math.floor(s / 3), math.floor(s / 3), { a = 0 })
end
function IconWidget:free() end
return IconWidget
