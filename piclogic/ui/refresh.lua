--[[
The one place that asks the e-ink panel to refresh, so the waveform policy
stays consistent:

  cells       board edits: smallest rect, "ui" (keeps clue text crisp)
  press       button feedback: "fast", just the button
  transition  screen changes: full screen "flashui" (clears ghosting)
  reveal      the solve reveal: full screen "full"
  deghost     every N edits: board rect "flashpartial"

Partial updates are drawn straight into Screen.bb and then refreshed with no
widget (the way KOReader's Button does it), so a tap never repaints the whole
screen. That is only safe while our window is on top; otherwise we fall back
to marking the window dirty.
]]

local Device = require("device")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")

local Screen = Device.screen

local Refresh = {}

local function geom(x, y, w, h)
    return Geom:new{ x = x, y = y, w = w, h = h }
end

--- True when painting directly into Screen.bb won't draw over another window.
function Refresh.canPaintDirect(window)
    return UIManager:getTopmostVisibleWidget() == window
end

--[[
Runs paint(bb) on the screen buffer if `window` is on top, then refreshes
rect {x, y, w, h} with `mode`. Otherwise repaints the whole window.
]]
function Refresh.region(window, mode, rect, paint)
    local region = geom(rect.x, rect.y, rect.w, rect.h)
    if Refresh.canPaintDirect(window) then
        paint(Screen.bb)
        UIManager:setDirty(nil, mode, region)
    else
        UIManager:setDirty(window, mode, region)
    end
end

--[[
Like region, for several rects painted in one pass. Board edits use this so
a tap refreshes the changed cells plus its row and column clue strips, not
the whole bounding box between them.
]]
function Refresh.regions(window, mode, rects, paint)
    -- No widget means "refresh only": we painted the pixels ourselves.
    local target = window
    if Refresh.canPaintDirect(window) then
        paint(Screen.bb)
        target = nil
    end
    for _, r in ipairs(rects) do
        UIManager:setDirty(target, mode, geom(r.x, r.y, r.w, r.h))
    end
end

function Refresh.cells(window, rects, paint)
    Refresh.regions(window, "ui", rects, paint)
end

--- Press feedback; forces the repaint now so it shows before the action runs.
function Refresh.press(window, rect, paint)
    Refresh.region(window, "fast", rect, paint)
    UIManager:forceRePaint()
end

function Refresh.deghost(window, rect)
    UIManager:setDirty(window, "flashpartial", geom(rect.x, rect.y, rect.w, rect.h))
end

function Refresh.transition(window)
    UIManager:setDirty(window, "flashui")
end

function Refresh.reveal(window)
    UIManager:setDirty(window, "full")
end

--- Union of rects given as {x, y, w, h} tables; nil for an empty list.
function Refresh.union(rects)
    local u
    for _, r in ipairs(rects) do
        if not u then
            u = { x = r.x, y = r.y, w = r.w, h = r.h }
        else
            local x2 = math.max(u.x + u.w, r.x + r.w)
            local y2 = math.max(u.y + u.h, r.y + r.h)
            u.x = math.min(u.x, r.x)
            u.y = math.min(u.y, r.y)
            u.w = x2 - u.x
            u.h = y2 - u.y
        end
    end
    return u
end

return Refresh
