--[[
Bottom sheet over the current screen, in two kinds:
  menu     a title, an optional line of secondary text, and a list of rows
  confirm  a question, a short explanation, and Cancel plus an action button
It spans the screen width on small screens and sits centered at the bottom
on wide ones, with a strong line along its top. The window (ui/host) shows
and closes it, and sends it taps; it never paints outside its own rect.
]]

local TextBoxWidget = require("ui/widget/textboxwidget")
local _ = require("gettext")
local Label = require("piclo/ui/components/label")
local Refresh = require("piclo/ui/refresh")
local TextButton = require("piclo/ui/components/text_button")
local Theme = require("piclo/ui/theme")

local Sheet = {}
Sheet.__index = Sheet

--[[
opts: title, subtitle (optional), items = { {text, on_tap}, ... }
on_tap(sheet) runs after the row's press feedback; it decides whether to
close the sheet or replace it.
]]
function Sheet.menu(opts)
    return setmetatable({ kind = "menu", opts = opts, widgets = {} }, Sheet)
end

--[[
opts: title, text, ok_text, on_ok(sheet). Cancel closes the sheet.
]]
function Sheet.confirm(opts)
    local self = setmetatable({ kind = "confirm", opts = opts, widgets = {} }, Sheet)
    self.cancel_btn = TextButton.new{ text = _("Cancel"), on_tap = function() self.window:closeSheet() end }
    self.ok_btn = TextButton.new{ text = opts.ok_text, primary = true, on_tap = function() opts.on_ok(self) end }
    self.buttons = { self.cancel_btn, self.ok_btn }
    return self
end

function Sheet:freeWidgets()
    for __, w in ipairs(self.widgets) do w:free() end
    self.widgets = {}
end

function Sheet:free()
    self:freeWidgets()
    for __, b in ipairs(self.buttons or {}) do b:free() end
end

function Sheet:keep(widget)
    self.widgets[#self.widgets + 1] = widget
    return widget
end

-- Lays out the content top-down from y = 0; returns its height.
function Sheet:layoutMenu(w, pad)
    local opts, text_w = self.opts, w - 2 * pad
    local y = Theme.space.xl
    self.title = self:keep(Label.new{ text = opts.title, role = "title", max_width = text_w })
    self.title_y = y
    y = y + self.title.h
    if opts.subtitle then
        self.subtitle = self:keep(Label.new{ text = opts.subtitle, color = Theme.SECONDARY, max_width = text_w })
        self.subtitle_y = y
        y = y + self.subtitle.h
    end
    y = y + Theme.space.m
    self.rows = {}
    local row_h = Theme.touch + Theme.space.m
    for __, item in ipairs(opts.items) do
        self.rows[#self.rows + 1] = {
            item = item,
            y = y,
            h = row_h,
            label = self:keep(Label.new{ text = item.text, max_width = text_w }),
        }
        y = y + row_h
    end
    return y + Theme.space.s
end

function Sheet:layoutConfirm(w, pad)
    local opts, text_w = self.opts, w - 2 * pad
    local y = Theme.space.xl
    self.title = self:keep(Label.new{ text = opts.title, role = "title", max_width = text_w })
    self.title_y = y
    y = y + self.title.h + Theme.space.s
    self.body = self:keep(TextBoxWidget:new{ text = opts.text, face = Theme.face("body"), width = text_w,
        fgcolor = Theme.SECONDARY })
    self.body_y = y
    y = y + self.body:getSize().h + Theme.space.xl
    self.buttons_y = y
    return y + Theme.touch + Theme.space.xl
end

function Sheet:layout(dimen)
    self:freeWidgets()
    local W, H = dimen.w, dimen.h
    local max_w = Theme.touch * 12
    local w = (W - 2 * Theme.space.xl > max_w) and max_w or W
    local pad = Theme.space.xl
    local h = self.kind == "menu" and self:layoutMenu(w, pad) or self:layoutConfirm(w, pad)
    h = math.min(h, H)
    self.full_width = w == W
    self.pad = pad
    self.rect = { x = math.floor((W - w) / 2), y = H - h, w = w, h = h }
    local r = self.rect
    if self.kind == "menu" then
        for __, row in ipairs(self.rows) do
            row.rect = { x = r.x, y = r.y + row.y, w = r.w, h = row.h }
        end
    else
        -- Cancel on the left of the action, both on the right edge.
        local x = r.x + r.w - pad
        for k = #self.buttons, 1, -1 do
            local b = self.buttons[k]
            -- The action pill has the standard width; Cancel just its text.
            local bw = b.primary and b:standardWidth(math.floor(r.w / 2))
                or math.max(b:preferredWidth(), Theme.touch * 2)
            x = x - bw
            b:setRect(x, r.y + self.buttons_y, bw, Theme.touch)
            x = x - Theme.space.s
        end
    end
end

function Sheet:paint(bb)
    local r, pad = self.rect, self.pad
    bb:paintRect(r.x, r.y, r.w, r.h, Theme.WHITE)
    bb:paintRect(r.x, r.y, r.w, Theme.line.strong, Theme.BLACK)
    if not self.full_width then
        bb:paintRect(r.x, r.y, Theme.line.hair, r.h, Theme.BLACK)
        bb:paintRect(r.x + r.w - Theme.line.hair, r.y, Theme.line.hair, r.h, Theme.BLACK)
    end
    self.title:paint(bb, r.x + pad, r.y + self.title_y)
    if self.kind == "menu" then
        if self.subtitle then self.subtitle:paint(bb, r.x + pad, r.y + self.subtitle_y) end
        for __, row in ipairs(self.rows) do
            bb:paintRect(r.x + pad, row.rect.y, r.w - 2 * pad, Theme.line.hair, Theme.BLACK)
            row.label:paintIn(bb, { x = r.x + pad, y = row.rect.y, w = r.w - 2 * pad, h = row.h }, "left")
        end
    else
        self.body:paintTo(bb, r.x + pad, r.y + self.body_y)
        for __, b in ipairs(self.buttons) do b:paint(bb) end
    end
end

local function inside(rect, x, y)
    return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

--- Handles a tap inside the sheet; a tap outside closes it.
function Sheet:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    if not inside(self.rect, x, y) then return self.window:closeSheet() end
    if self.kind == "menu" then
        for __, row in ipairs(self.rows) do
            local rr = row.rect
            if inside(rr, x, y) then
                Refresh.press(self.window, rr, function(bb) bb:invertRect(rr.x, rr.y, rr.w, rr.h) end)
                return row.item.on_tap(self)
            end
        end
        return
    end
    for __, b in ipairs(self.buttons) do
        if b:contains(x, y) then
            Refresh.press(self.window, b.rect, function(bb) b:paint(bb, true) end)
            return b.on_tap()
        end
    end
end

return Sheet
