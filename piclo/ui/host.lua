--[[
The plugin's single full-screen window. Screens swap inside it, so KOReader
sees one widget and lifecycle events land in one place:

  gestures          forwarded to the current screen, or to an open sheet;
                    taps right after a screen change are dropped (TAP_GUARD)
  Back key          closes an open sheet, else app:back(); page-turn keys
                    go to the screen
  Suspend/Resume    app pauses and resumes the timer
  rotation/resize   re-layout and a flashing repaint
  FlushSettings     app saves (KOReader sends it on close and periodically)
]]

local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local time = require("ui/time")
local Refresh = require("piclo/ui/refresh")
local Theme = require("piclo/ui/theme")

local Screen = Device.screen

local Host = InputContainer:extend{
    name = "piclo",
    covers_fullscreen = true,
    app = nil,
    screen = nil,
    sheet = nil,
}

--[[
Seconds after a screen or sheet change in which taps are dropped. E-ink is
slow to show the new screen, so people tap twice; without this the second
tap lands on whatever the first one opened.
]]
Host.TAP_GUARD = 0.35

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
    self:guard()
    self:closeSheet(false)
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
    if self.sheet then self.sheet:paint(bb) end
end

-- Repaints everything into the screen buffer, refreshing only `rects`.
function Host:repaintRegions(rects)
    Refresh.regions(self, "ui", rects, function(bb) self:paintTo(bb, 0, 0) end)
end

--- Opens a sheet over the screen, replacing any open one.
function Host:showSheet(sheet)
    self:guard()
    local old = self.sheet
    sheet.window = self
    sheet:layout(self.dimen)
    self.sheet = sheet
    local rects = { sheet.rect }
    if old then
        old:free()
        rects[2] = old.rect
    end
    self:repaintRegions(rects)
end

--- Closes the open sheet; repaint = false when the screen is about to change anyway.
function Host:closeSheet(repaint)
    local old = self.sheet
    if not old then return end
    self.sheet = nil
    old:free()
    if repaint ~= false then self:repaintRegions({ old.rect }) end
end

function Host:relayout()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    Theme.update()
    if self.screen then self.screen:layout(self.dimen) end
    if self.sheet then self.sheet:layout(self.dimen) end
    UIManager:setDirty(self, "full")
end

--- Starts the tap guard (see TAP_GUARD).
function Host:guard()
    self.guard_until = time.to_s(time.now()) + Host.TAP_GUARD
end

function Host:guarded()
    return self.guard_until ~= nil and time.to_s(time.now()) < self.guard_until
end

-- Gestures: the screen decides (or an open sheet, which only takes taps);
-- we always consume them so nothing leaks to the reader or file browser
-- underneath.
local function forwardGesture(method)
    return function(self, _, ges)
        if method == "onTap" and self:guarded() then return true end
        self.app:onInput()
        if self.sheet then
            if method == "onTap" then self.sheet:onTap(ges) end
            return true
        end
        local screen = self.screen
        if screen and screen[method] then screen[method](screen, ges) end
        return true
    end
end
Host.onTap = forwardGesture("onTap")
Host.onHold = forwardGesture("onHold")
Host.onHoldRelease = forwardGesture("onHoldRelease")
Host.onHoldPan = forwardGesture("onHoldPan")
Host.onPan = forwardGesture("onPan")
Host.onPanRelease = forwardGesture("onPanRelease")
Host.onSwipe = forwardGesture("onSwipe")

function Host:onClose()
    if self.sheet then
        self:closeSheet()
    else
        self.app:back()
    end
    return true
end

-- Page-turn keys: forward is true for PgFwd (key.key is e.g. "RPgFwd").
function Host:onPageKey(_, key)
    if self.sheet then return true end
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
    if self.sheet then
        self.sheet:free()
        self.sheet = nil
    end
    if self.screen and self.screen.free then self.screen:free() end
    self.screen = nil
    self.app:onClosed()
end

return Host
