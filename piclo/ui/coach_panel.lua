--[[
The guide under a practice board: the current step's text, centered, and
once the picture is solved a closing line with one button (the next
practice puzzle, or Done). Its height is fixed for the whole lesson, sized
to the longest text, so the board never moves while you play.
]]

local TextBoxWidget = require("ui/widget/textboxwidget")
local TextButton = require("piclo/ui/components/text_button")
local Theme = require("piclo/ui/theme")

local CoachPanel = {}
CoachPanel.__index = CoachPanel

--- opts: coach, button (text), on_button
function CoachPanel.new(opts)
    return setmetatable({
        coach = opts.coach,
        button = TextButton.new{ text = opts.button, primary = true, on_tap = opts.on_button },
        rect = { x = 0, y = 0, w = 0, h = 0 },
    }, CoachPanel)
end

function CoachPanel:freeText()
    if self.box then
        self.box:free()
        self.box = nil
    end
end

function CoachPanel:free()
    self:freeText()
    self.button:free()
end

local function textBox(text, w)
    return TextBoxWidget:new{ text = text, face = Theme.face("body"), width = w, alignment = "center" }
end

--- Width the text gets on a screen whose board area is area_w wide.
function CoachPanel.textWidth(area_w)
    return math.min(area_w, Theme.touch * 12)
end

--- Height needed at text width w: the longest text, with the button under the closing one.
function CoachPanel:measure(w)
    local tallest = 0
    for __, text in ipairs(self.coach:texts()) do
        local box = textBox(text, w)
        local h = box:getSize().h
        if text == self.coach:doneText() then h = h + Theme.space.l + Theme.touch end
        tallest = math.max(tallest, h)
        box:free()
    end
    self.text_w = w
    return tallest
end

--- Takes its rect (area-wide, from board placement); the text is centered in it.
function CoachPanel:setRect(rect)
    self.rect = rect
    self:setText(self.text)
end

--- Shows text (nil keeps the current one); with done, the button too.
function CoachPanel:setText(text, done)
    self.done = done or false
    self.text = text
    self:freeText()
    if not text then return end
    self.box = textBox(text, self.text_w)
    local r = self.rect
    if self.done then
        local b = self.button
        local bw = b:standardWidth(r.w)
        local y = r.y + self.box:getSize().h + Theme.space.l
        b:setRect(r.x + math.floor((r.w - bw) / 2), y, bw, Theme.touch)
    end
end

function CoachPanel:paint(bb)
    local r = self.rect
    bb:paintRect(r.x, r.y, r.w, r.h, Theme.WHITE)
    if self.box then self.box:paintTo(bb, r.x + math.floor((r.w - self.text_w) / 2), r.y) end
    if self.done then self.button:paint(bb) end
end

--- The button, when it shows and (x, y) is on it.
function CoachPanel:buttonAt(x, y)
    if self.done and self.button:contains(x, y) then return self.button end
end

return CoachPanel
