--[[
The plugin's single full-screen window. Screens swap inside it, so KOReader
sees one widget and lifecycle events land in one place:

  gestures          forwarded to the current screen
  Back key          app:back(); page-turn keys go to the screen
  Suspend/Resume    app pauses and resumes the timer
  rotation/resize   re-layout and a flashing repaint
  FlushSettings     app saves (KOReader sends it on close and periodically)
]]

local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Refresh = require("piclogic/ui/refresh")
local Theme = require("piclogic/ui/theme")

local Screen = Device.screen

local Host = InputContainer:extend{
    name = "piclogic",
    covers_fullscreen = true,
    app = nil,
    screen = nil,
}

local GESTURES = {
    Tap = "tap",
    Hold = "hold",
    HoldRelease = "hold_release",
    HoldPan = "hold_pan",
    Pan = "pan",
    PanRelease = "pan_release",
    Swipe = "swipe",
}

function Host:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    if Device:isTouchDevice() then
        local range = function() return self.dimen end
        for event, ges in pairs(GESTURES) do
            self.ges_events[event] = { GestureRange:new{ ges = ges, range = range } }
        end
    end
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
        self.key_events.PageKey = { { Device.input.group.PgFwd }, { Device.input.group.PgBack } }
    end
end

--[[
Shows `screen` in the window with a flashing transition; refresh = "full"
asks for the stronger full flash (used by the reveal).
]]
function Host:setScreen(screen, refresh)
    if self.screen and self.screen ~= screen and self.screen.free then
        self.screen:free()
    end
    self.screen = screen
    screen.window = self
    screen:layout(self.dimen)
    if refresh == "full" then
        Refresh.reveal(self)
    else
        Refresh.transition(self)
    end
end

function Host:paintTo(bb, x, y)
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Theme.WHITE)
    if self.screen then self.screen:paint(bb) end
end

function Host:relayout()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    Theme.update()
    if self.screen then self.screen:layout(self.dimen) end
    UIManager:setDirty(self, "full")
end

-- Gestures: the screen decides; we always consume them so nothing leaks to
-- the reader or file browser underneath.
local function forward(method)
    return function(self, _, ges)
        local screen = self.screen
        if screen and screen[method] then screen[method](screen, ges) end
        return true
    end
end
Host.onTap = forward("onTap")
Host.onHold = forward("onHold")
Host.onHoldRelease = forward("onHoldRelease")
Host.onHoldPan = forward("onHoldPan")
Host.onPan = forward("onPan")
Host.onPanRelease = forward("onPanRelease")
Host.onSwipe = forward("onSwipe")

function Host:onClose()
    self.app:back()
    return true
end

-- Page-turn keys: forward is true for PgFwd (key.key is e.g. "RPgFwd").
function Host:onPageKey(_, key)
    local forward = not (key and key.key and tostring(key.key):find("Back"))
    if self.screen and self.screen.onPageKey then self.screen:onPageKey(forward) end
    return true
end

-- Rotation arrives here because we're on top. Let the reader or file browser
-- below rotate itself (as KOReader's own Menu widget does), then re-layout.
function Host:onSetRotationMode(mode)
    if mode == nil or mode == Screen:getRotationMode() then return true end
    local ui = self.app.ui
    if ui and ui.view then
        ui.view:onSetRotationMode(mode)
    elseif ui and ui.onSetRotationMode then
        ui:onSetRotationMode(mode)
    else
        Screen:setRotationMode(mode)
    end
    self:relayout()
    return true
end

function Host:onScreenResize()
    self:relayout()
end

function Host:onSetDimensions()
    self:relayout()
end

function Host:onSuspend()
    self.app:onSuspend()
end

function Host:onResume()
    self.app:onResume()
end

function Host:onFlushSettings()
    self.app:flush()
end

function Host:onCloseWidget()
    if self.screen and self.screen.free then self.screen:free() end
    self.screen = nil
    self.app:onClosed()
end

return Host
