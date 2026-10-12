local RenderText = require("ui/rendertext")
local TextWidget = {}
TextWidget.__index = TextWidget
function TextWidget:new(o) return setmetatable(o, TextWidget) end
function TextWidget:getSize()
    local w = RenderText:sizeUtf8Text(0, nil, self.face, self.text).x
    return { w = math.min(w, self.max_width or w), h = math.ceil(self.face.size * 1.4) }
end
function TextWidget:isTruncated()
    return self.max_width ~= nil and RenderText:sizeUtf8Text(0, nil, self.face, self.text).x > self.max_width
end
function TextWidget:paintTo(bb, x, y)
    local size = self:getSize()
    RenderText:renderUtf8Text(bb, x, y + math.ceil(self.face.size * 1.0), self.face, self.text,
        false, false, self.fgcolor, size.w)
end
function TextWidget:free() end
return TextWidget
