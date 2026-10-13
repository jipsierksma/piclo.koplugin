-- Wraps text at word boundaries by measured width, in block glyphs.
local RenderText = require("ui/rendertext")
local TextBoxWidget = {}
TextBoxWidget.__index = TextBoxWidget
local function width(face, text) return RenderText:sizeUtf8Text(0, nil, face, text).x end
function TextBoxWidget:new(o)
    o.lines = {}
    local line = ""
    for word in o.text:gmatch("%S+") do
        local next_line = line == "" and word or (line .. " " .. word)
        if width(o.face, next_line) > o.width and line ~= "" then
            o.lines[#o.lines + 1] = line
            line = word
        else
            line = next_line
        end
    end
    if line ~= "" then o.lines[#o.lines + 1] = line end
    o.line_h = math.ceil(o.face.size * 1.3)
    return setmetatable(o, TextBoxWidget)
end
function TextBoxWidget:getSize() return { w = self.width, h = #self.lines * self.line_h } end
function TextBoxWidget:paintTo(bb, x, y)
    for k, line in ipairs(self.lines) do
        RenderText:renderUtf8Text(bb, x, y + k * self.line_h - math.ceil(self.face.size * 0.3), self.face, line,
            false, false, self.fgcolor, self.width)
    end
end
function TextBoxWidget:free() end
return TextBoxWidget
