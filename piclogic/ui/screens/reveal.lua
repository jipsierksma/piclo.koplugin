--[[
Reveal screen, the payoff: the finished picture drawn large in its reveal
tones (no grid, no clues), the title in display size, one line about the
time, and two actions. Also used to look at a solved picture again from the
collection ("view" mode), where the main action is "Play again".
]]

local T = require("ffi/util").template
local _ = require("gettext")
local Format = require("piclogic/util/format")
local Label = require("piclogic/ui/components/label")
local Layout = require("piclogic/ui/layout")
local Picture = require("piclogic/ui/picture")
local Refresh = require("piclogic/ui/refresh")
local TextButton = require("piclogic/ui/components/text_button")
local Theme = require("piclogic/ui/theme")

local RevealScreen = {}
RevealScreen.__index = RevealScreen

--- The secondary line under the title.
function RevealScreen.summary(data)
    if data.revealed then return _("Revealed") end
    local best = data.best and Format.duration(data.best)
    if data.mode == "view" then
        return best and T(_("Best %1"), best) or ""
    end
    local line = T(_("Solved in %1"), Format.duration(data.elapsed))
    if data.result and data.result.new_best then
        return line .. " · " .. _("New best")
    elseif best and data.best < math.floor(data.elapsed) then
        return line .. " · " .. T(_("Best %1"), best)
    end
    return line
end

--[[
data: mode ("solved" | "view"), puzzle, elapsed, best, result
({first, new_best}), revealed, next (puzzle or nil), unlocked (pack titles)
]]
function RevealScreen.new(opts)
    local app, data = opts.app, opts.data
    local self = setmetatable({ app = app, data = data, labels = {} }, RevealScreen)
    local p = data.puzzle
    if data.mode == "view" then
        self.primary = TextButton.new{ text = _("Play again"), primary = true,
            on_tap = function() app:playAgain(p) end }
    elseif data.next then
        self.primary = TextButton.new{ text = _("Next puzzle"), primary = true,
            on_tap = function() app:playNext(data.next) end }
    end
    self.secondary = TextButton.new{ text = _("Back to collection"),
        on_tap = function() app:backToCollection(p.pack_id) end }
    self.buttons = {}
    if self.primary then self.buttons[1] = self.primary end
    self.buttons[#self.buttons + 1] = self.secondary
    return self
end

function RevealScreen:free()
    Label.freeAll(self.labels)
    self.labels = {}
    for __, b in ipairs(self.buttons) do b:free() end
end

function RevealScreen:label(opts)
    local l = Label.new(opts)
    self.labels[#self.labels + 1] = l
    return l
end

-- Lays the text column out centered on cx, starting at y; returns its height.
function RevealScreen:layoutText(cx, y, col_w, measure_only)
    local items = { self.title, self.summary }
    local h, pos = 0, {}
    for __, l in ipairs(items) do
        pos[#pos + 1] = { item = l, y = y + h }
        h = h + l.h
    end
    h = h + Theme.space.xxl
    for __, b in ipairs(self.buttons) do
        local w = math.min(col_w, math.max(b:preferredWidth(), Theme.touch * 4))
        if not measure_only then b:setRect(cx - math.floor(w / 2), y + h, w, Theme.touch) end
        h = h + Theme.touch + Theme.space.s
    end
    for __, l in ipairs(self.unlocked) do
        h = h + Theme.space.s
        pos[#pos + 1] = { item = l, y = y + h }
        h = h + l.h
    end
    if not measure_only then self.text_pos = pos end
    return h
end

function RevealScreen:layout(dimen)
    Label.freeAll(self.labels)
    self.labels = {}
    local W, H = dimen.w, dimen.h
    local p, m = self.data.puzzle, Theme.space.xxl
    local landscape = W > H
    local col_w = landscape and math.floor(W / 2) - 2 * m or W - 2 * m
    self.title = self:label{ text = p.title, role = "title", size = "display", max_width = col_w }
    self.summary = self:label{ text = RevealScreen.summary(self.data), color = Theme.SECONDARY, max_width = col_w }
    self.unlocked = {}
    for __, title in ipairs(self.data.unlocked or {}) do
        self.unlocked[#self.unlocked + 1] = self:label{ text = T(_("New pack unlocked: %1"), title),
            max_width = col_w }
    end

    local box
    if landscape then
        box = { x = m, y = m, w = math.floor(W / 2) - 2 * m, h = H - 2 * m }
        local text_h = self:layoutText(0, 0, col_w, true)
        self.text_cx = math.floor(W * 3 / 4)
        self:layoutText(self.text_cx, math.floor((H - text_h) / 2), col_w)
    else
        local text_h = self:layoutText(0, 0, col_w, true)
        -- At most ~70% of the width, so even a 5x5 picture keeps a calm margin.
        local bw = math.min(W - 2 * m, math.floor(W * 0.7))
        local scale = Layout.fitPicture(p.w, p.h, bw, H - text_h - 3 * m)
        local pic_h = p.h * scale
        -- Center picture plus text as one block.
        local top = math.floor((H - pic_h - m - text_h) / 2)
        box = { x = math.floor((W - bw) / 2), y = top, w = bw, h = pic_h }
        self.text_cx = math.floor(W / 2)
        self:layoutText(self.text_cx, top + pic_h + m, col_w)
    end
    self.box = box
end

function RevealScreen:paint(bb)
    Picture.paint(bb, self.data.puzzle, self.box)
    for __, pos in ipairs(self.text_pos) do
        local l = pos.item
        l:paint(bb, self.text_cx - math.floor(l.w / 2), pos.y)
    end
    for __, b in ipairs(self.buttons) do b:paint(bb) end
end

function RevealScreen:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    for __, b in ipairs(self.buttons) do
        if b:contains(x, y) then
            Refresh.press(self.window, b.rect, function(bb) b:paint(bb, true) end)
            return b.on_tap()
        end
    end
end

return RevealScreen
