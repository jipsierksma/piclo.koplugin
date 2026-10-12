local GestureRange = {}
GestureRange.__index = GestureRange
function GestureRange:new(o) return setmetatable(o, GestureRange) end
function GestureRange:match(ev)
    if ev.ges ~= self.ges then return false end
    local range = type(self.range) == "function" and self.range() or self.range
    return range == nil or range:contains(ev.pos)
end
return GestureRange
