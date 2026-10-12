local Event = {}
function Event:new(name, ...) return { name = name, args = { ... } } end
return Event
