-- Window stack plus a log of refresh requests. repaint() paints dirty
-- windows into Screen.bb the way UIManager:_repaint does.
local Event = require("ui/event")
local Screen = require("device").screen

local UIManager = { stack = {}, dirty = {}, refreshes = {} }

function UIManager:reset()
    self.stack, self.dirty, self.refreshes = {}, {}, {}
end

function UIManager:show(w, mode)
    table.insert(self.stack, w)
    self.dirty[w] = true
    table.insert(self.refreshes, { mode = mode or "ui" })
end

function UIManager:close(w, mode)
    w:handleEvent(Event:new("FlushSettings"))
    w:handleEvent(Event:new("CloseWidget"))
    for i = #self.stack, 1, -1 do
        if self.stack[i] == w then table.remove(self.stack, i) end
    end
    self.dirty[w] = nil
    table.insert(self.refreshes, { mode = mode, closed = true })
end

function UIManager:setDirty(w, mode, region)
    if w then self.dirty[w] = true end
    table.insert(self.refreshes, { widget = w, mode = mode, region = region })
end

function UIManager:getTopmostVisibleWidget() return self.stack[#self.stack] end
function UIManager:forceRePaint() self:repaint() end

function UIManager:repaint()
    for _, w in ipairs(self.stack) do
        if self.dirty[w] then w:paintTo(Screen.bb, 0, 0) end
    end
    self.dirty = {}
end

function UIManager:takeRefreshes()
    local list = self.refreshes
    self.refreshes = {}
    return list
end

return UIManager
