--[[
"How to play": short headed paragraphs, a drawn example line and the
toolbar's icons next to their names (under the text that mentions them), laid out
into pages that turn with swipes and the page-turn keys. On the first run it
is an introduction rather than a submenu: no back button, and a "Got it"
button to move on. "Try a practice puzzle" opens a guided practice board
(quiet beside "Got it" on the first run, a pill on its own otherwise).
]]

local TextBoxWidget = require("ui/widget/textboxwidget")
local T = require("ffi/util").template
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local C_ = require("piclo/l10n").pgettext
local Cell = require("piclo/model/cell")
local Glyphs = require("piclo/ui/glyphs")
local HeaderBar = require("piclo/ui/components/header_bar")
local Icons = require("piclo/ui/icons")
local Label = require("piclo/ui/components/label")
local Refresh = require("piclo/ui/refresh")
local TextButton = require("piclo/ui/components/text_button")
local Theme = require("piclo/ui/theme")

local HelpScreen = {}
HelpScreen.__index = HelpScreen

-- The example row: clue "3 1" over seven cells.
local EXAMPLE_CLUE = "3 1"
local EXAMPLE = { Cell.FILLED, Cell.FILLED, Cell.FILLED, Cell.CROSSED, Cell.FILLED, Cell.CROSSED, Cell.CROSSED }

local function content()
    return {
        { kind = "para", text = _("Fill in squares to reveal a hidden picture. The numbers next to each row and above each column tell you which squares to fill.") },
        { kind = "heading", text = _("Reading the numbers") },
        { kind = "para", text = _("Each number is a run of filled squares, in order from left to right or top to bottom. Runs are separated by at least one empty square. The row below reads 3 1: a run of three, a gap, then one more.") },
        { kind = "example" },
        { kind = "heading", text = _("Marking squares") },
        { kind = "para", text = _("Choose Fill or Cross in the toolbar, then tap a square. Tap it again to clear it. Hold a square to use the other tool. Drag along a row or column to mark several squares at once. The page-turn buttons switch tools.") },
        { kind = "icons", items = { { "fill", _("Fill") }, { "cross", _("Cross") } } },
        -- Where the second page starts when it all doesn't fit on one.
        { kind = "break" },
        { kind = "heading", text = _("Getting stuck") },
        { kind = "para", text = _("The bulb in the toolbar fills in the next line that can be worked out and highlights its numbers. Undo takes the step back. In Settings you can also have mistakes checked, on request (with the magnifier) or as you play.") },
        { kind = "icons", items = { { "hint", _("Hint") }, { "undo", _("Undo") }, { "inspect", _("Check") } } },
        { kind = "heading", text = _("Finishing") },
        { kind = "para", text = _("A number turns gray once its run is complete. Gray means the count fits, not that the run is in the right place. When every filled square is right, the picture appears and joins your collection. Solving puzzles in a pack unlocks the next one.") },
    }
end

--- opts: app, first_run (bool)
function HelpScreen.new(opts)
    local app = opts.app
    local self = setmetatable({ app = app, page = 1, widgets = {} }, HelpScreen)
    local back = function() app:back() end
    self.header = HeaderBar.new{ title = _("How to play"), on_back = (not opts.first_run) and back or nil }
    if #app:lessons() > 0 then
        self.practice_btn = TextButton.new{ text = _("Try a practice puzzle"), primary = not opts.first_run,
            on_tap = function() app:startPractice(1) end }
    end
    if opts.first_run then
        self.done_btn = TextButton.new{ text = C_("Piclo", "Got it"), primary = true, on_tap = back }
    end
    -- Left to right, the main one last.
    self.buttons = {}
    for __, b in ipairs({ self.practice_btn or false, self.done_btn or false }) do
        if b then self.buttons[#self.buttons + 1] = b end
    end
    return self
end

function HelpScreen:freeWidgets()
    for __, w in ipairs(self.widgets) do w:free() end
    self.widgets = {}
    if self.glyphs then
        self.glyphs:free()
        self.glyphs = nil
    end
end

function HelpScreen:free()
    for __, b in ipairs(self.buttons) do b:free() end
    self.header:freeText()
    self:freeWidgets()
end

-- Builds one block: { h = height, paint = function(bb, x, y) }.
function HelpScreen:block(item, width)
    if item.kind == "heading" then
        local l = Label.new{ text = item.text, role = "title", size = "body", max_width = width }
        self.widgets[#self.widgets + 1] = l
        return { h = l.h, gap = Theme.space.xl, paint = function(bb, x, y) l:paint(bb, x, y) end }
    elseif item.kind == "icons" then
        return self:iconsBlock(item.items, width)
    elseif item.kind == "para" then
        local tb = TextBoxWidget:new{ text = item.text, face = Theme.face("body"), width = width }
        self.widgets[#self.widgets + 1] = tb
        return { h = tb:getSize().h, gap = Theme.space.s, paint = function(bb, x, y) tb:paintTo(bb, x, y) end }
    end
    return self:exampleBlock()
end

--- A row of toolbar icons, each with its name beside it.
function HelpScreen:iconsBlock(items, width)
    local size, gap = Theme.icon, Theme.space.s
    local entries = {}
    for __, it in ipairs(items) do
        local l = Label.new{ text = it[2], max_width = width }
        self.widgets[#self.widgets + 1] = l
        entries[#entries + 1] = { icon = it[1], label = l }
    end
    local h = math.max(size, entries[1].label.h)
    local function paint(bb, x, y)
        for __, e in ipairs(entries) do
            Icons.paint(bb, e.icon, size, "normal", { x = x, y = y, w = size, h = h })
            e.label:paintIn(bb, { x = x + size + gap, y = y, w = e.label.w, h = h }, "left")
            x = x + size + gap + e.label.w + Theme.space.xl
        end
    end
    return { h = h, gap = Theme.space.m, paint = paint }
end

function HelpScreen:exampleBlock()
    local cell = Theme.min_cell + Theme.space.s
    local n = #EXAMPLE
    local clue = Label.new{ text = EXAMPLE_CLUE, role = "numeric" }
    self.widgets[#self.widgets + 1] = clue
    local reg, hair = Theme.line.regular, Theme.line.hair
    self.glyphs = Glyphs.new(cell - hair - reg, cell - 2 * reg)
    local function paint(bb, x, y)
        clue:paintIn(bb, { x = x, y = y, w = clue.w, h = cell }, "left")
        local x0 = x + clue.w + Theme.space.m
        local gap = Theme.fill_gap
        for k = 1, n do
            local left = (k == 1) and reg or hair
            local right = (k == n) and reg or 0
            local ix, iy = x0 + (k - 1) * cell + left, y + reg
            local iw, ih = cell - left - right, cell - 2 * reg
            if EXAMPLE[k] == Cell.FILLED then
                bb:paintRect(ix + gap, iy + gap, iw - 2 * gap, ih - 2 * gap, Theme.BLACK)
            else
                local gl = self.glyphs
                bb:blitFrom(gl.cross, ix + math.floor((iw - gl.w) / 2), iy + math.floor((ih - gl.h) / 2),
                    0, 0, gl.w, gl.h)
            end
            if k > 1 then bb:paintRect(x0 + (k - 1) * cell, y, hair, cell, Theme.BLACK) end
        end
        bb:paintBorder(x0, y, n * cell, cell, reg, Theme.BLACK)
    end
    return { h = cell, gap = Theme.space.m, paint = paint }
end

function HelpScreen:layout(dimen)
    self.dimen = dimen
    self:freeWidgets()
    local W, H = dimen.w, dimen.h
    self.header:layout(0, 0, W)
    local m = Theme.space.xl
    local width = math.min(W - 2 * m, Theme.touch * 12)
    self.x = math.floor((W - width) / 2)
    local top = Theme.header_h + Theme.space.l
    local bottom = H - Theme.touch - Theme.space.s
    if #self.buttons > 0 then bottom = self:layoutButtons(W, H, m) - Theme.touch end
    local items, blocks = {}, {}
    for __, item in ipairs(content()) do
        if item.kind ~= "break" then blocks[#blocks + 1] = self:block(item, width) end
        items[#items + 1] = item
    end
    -- Page breaks only count when the text doesn't fit on one page anyway.
    if self:paginate(items, blocks, top, bottom, false) then
        self:paginate(items, blocks, top, bottom, true)
    end
    self.page = math.max(1, math.min(self.page, #self.pages))
    self.pager = nil
    if #self.pages > 1 then
        self.pager = Label.new{ text = T(_("%1 / %2"), self.page, #self.pages), size = "caption",
            color = Theme.SECONDARY }
        self.widgets[#self.widgets + 1] = self.pager
        self.pager_rect = { x = 0, y = bottom, w = W, h = Theme.touch }
    end
end

--[[
Lays the blocks out into self.pages; with use_breaks, a "break" item starts
a new page. Returns whether more than one page was needed.
]]
function HelpScreen:paginate(items, blocks, top, bottom, use_breaks)
    self.pages = { {} }
    local y, k = top, 0
    for idx, item in ipairs(items) do
        if item.kind == "break" then
            if use_breaks and #self.pages[#self.pages] > 0 then
                self.pages[#self.pages + 1] = {}
                y = top
            end
        else
            k = k + 1
            local b = blocks[k]
            local gap = (#self.pages[#self.pages] == 0) and 0 or b.gap
            -- A heading only goes where the block after it fits too.
            local need = b.h
            local nxt = blocks[k + 1]
            if item.kind == "heading" and nxt and items[idx + 1].kind ~= "break" then
                need = need + nxt.gap + nxt.h
            end
            if y + gap + need > bottom and #self.pages[#self.pages] > 0 then
                self.pages[#self.pages + 1] = {}
                y, gap = top, 0
            end
            y = y + gap
            table.insert(self.pages[#self.pages], { block = b, y = y })
            y = y + b.h
        end
    end
    return #self.pages > 1
end

--[[
The buttons at the bottom: side by side (the main one on the right) when
they fit, else stacked with the main one lowest. Returns the top of the
topmost.
]]
function HelpScreen:layoutButtons(W, H, m)
    local btns, gap = self.buttons, Theme.space.l
    local widths, total = {}, (#self.buttons - 1) * gap
    for k, b in ipairs(btns) do
        widths[k] = b:standardWidth(W - 2 * m)
        total = total + widths[k]
    end
    local y = H - Theme.touch - Theme.space.l
    if total <= W - 2 * m then
        local x = math.floor((W - total) / 2)
        for k, b in ipairs(btns) do
            b:setRect(x, y, widths[k], Theme.touch)
            x = x + widths[k] + gap
        end
        return y
    end
    for k = #btns, 1, -1 do
        btns[k]:setRect(math.floor((W - widths[k]) / 2), y, widths[k], Theme.touch)
        if k > 1 then y = y - Theme.touch - Theme.space.s end
    end
    return y
end

function HelpScreen:paint(bb)
    self.header:paint(bb)
    for __, e in ipairs(self.pages[self.page]) do e.block.paint(bb, self.x, e.y) end
    if self.pager then self.pager:paintIn(bb, self.pager_rect, "center") end
    for __, b in ipairs(self.buttons) do b:paint(bb) end
end

function HelpScreen:changePage(delta)
    local page = self.page + delta
    if page < 1 or page > #self.pages then return end
    self.page = page
    self:layout(self.dimen)
    UIManager:setDirty(self.window, "ui")
end

function HelpScreen:onTap(ges)
    local btn = self.header:buttonAt(ges.pos.x, ges.pos.y)
    for __, b in ipairs(self.buttons) do
        if not btn and b:contains(ges.pos.x, ges.pos.y) then btn = b end
    end
    if btn then
        Refresh.press(self.window, btn.rect, function(bb) btn:paint(bb, true) end)
        return btn.on_tap()
    end
    -- Tapping the right or left half also turns pages, as in the reader.
    if #self.pages > 1 and ges.pos.y > Theme.header_h then
        self:changePage(ges.pos.x > self.dimen.w / 2 and 1 or -1)
    end
end

function HelpScreen:onSwipe(ges)
    if ges.direction == "west" then
        self:changePage(1)
    elseif ges.direction == "east" then
        self:changePage(-1)
    end
end

function HelpScreen:onPageKey(forward)
    self:changePage(forward and 1 or -1)
end

return HelpScreen
