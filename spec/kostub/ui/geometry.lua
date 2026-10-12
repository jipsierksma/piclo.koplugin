local Geom = {}
Geom.__index = Geom
function Geom:new(o)
    o = o or {}
    o.x, o.y, o.w, o.h = o.x or 0, o.y or 0, o.w or 0, o.h or 0
    return setmetatable(o, Geom)
end
function Geom:copy() return Geom:new{ x = self.x, y = self.y, w = self.w, h = self.h } end
function Geom:contains(g)
    return g ~= nil and self.x <= g.x and self.y <= g.y
        and self.x + self.w >= g.x + (g.w or 0) and self.y + self.h >= g.y + (g.h or 0)
end
return Geom
