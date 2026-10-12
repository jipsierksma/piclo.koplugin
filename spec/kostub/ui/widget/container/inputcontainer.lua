-- Widget:new semantics (extend, then _init, then init) and InputContainer's
-- gesture matching and event dispatch.
local Event = require("ui/event")

local InputContainer = {}
InputContainer.__index = InputContainer

function InputContainer:extend(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function InputContainer:new(o)
    o = self:extend(o)
    o.key_events = {}
    o.ges_events = {}
    if o.init then o:init() end
    return o
end

function InputContainer:handleEvent(ev)
    local handler = self["on" .. ev.name]
    if handler then return handler(self, unpack(ev.args)) end
end

function InputContainer:onGesture(ges)
    for name, seq in pairs(self.ges_events) do
        for _, range in ipairs(seq) do
            if range:match(ges) then
                if self:handleEvent(Event:new(name, nil, ges)) then return true end
            end
        end
    end
end

return InputContainer
