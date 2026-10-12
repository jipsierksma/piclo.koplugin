local RenderText = require("ui/rendertext")
local TextWidget = {}
TextWidget.__index = TextWidget
function TextWidget:new(o) return setmetatable(o, TextWidget) end
function TextWidget:getSize()
    local w = RenderText:sizeUtf8Text(0, nil, self.face, self.text).x
    return { w = math.min(w, self.max_width or w), h = math.ceil(self.face.size * 1.4) }
end
function TextWidget:paintTo(bb, x, y)
    local size = self:getSize()
    local text = self.text
    local adv = math.ceil(self.face.size * 0.55)
    if size.w < #text * adv then text = text:sub(1, math.floor(size.w / adv)) end
    RenderText:renderUtf8Text(bb, x, y + math.ceil(self.face.size * 1.0), self.face, text,
        false, false, self.fgcolor)
end
function TextWidget:free() end
return TextWidget
