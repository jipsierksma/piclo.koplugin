--[[
The game toolbar: the Fill/Cross segmented control, Undo, Redo, Hint and,
when mistake checking is "on request", Check. A bar along the bottom in
portrait, a rail beside the board in landscape, with its items spaced
evenly and a hairline on the side facing the board.
]]

local Game = require("piclogic/game")
local IconButton = require("piclogic/ui/components/icon_button")
local Segmented = require("piclogic/ui/components/segmented")
local Theme = require("piclogic/ui/theme")

local Toolbar = {}
Toolbar.__index = Toolbar

--[[
opts: game, with_check (bool), on = { undo, redo, hint, check } callbacks
]]
function Toolbar.new(opts)
    local on = opts.on
    local self = setmetatable({ game = opts.game, rect = { x = 0, y = 0, w = 0, h = 0 } }, Toolbar)
    self.tools = Segmented.new{
        items = {
            { id = Game.TOOL_FILL, icon = "fill" },
            { id = Game.TOOL_CROSS, icon = "cross" },
        },
        selected = opts.game.tool,
    }
    self.undo_btn = IconButton.new{ icon = "undo", on_tap = on.undo }
    self.redo_btn = IconButton.new{ icon = "redo", on_tap = on.redo }
    self.hint_btn = IconButton.new{ icon = "hint", on_tap = on.hint }
    self.buttons = { self.undo_btn, self.redo_btn, self.hint_btn }
    if opts.with_check then
        self.check_btn = IconButton.new{ icon = "check", on_tap = on.check }
        self.buttons[#self.buttons + 1] = self.check_btn
    end
    self:sync()
    return self
end

function Toolbar:free()
    self.tools:free()
end

--- Updates Undo/Redo availability; returns the buttons whose look changed.
function Toolbar:sync()
    local changed = {}
    if self.undo_btn:setEnabled(self.game:canUndo()) then changed[#changed + 1] = self.undo_btn end
    if self.redo_btn:setEnabled(self.game:canRedo()) then changed[#changed + 1] = self.redo_btn end
    return changed
end

--- rect: the bar; landscape: a vertical rail; rail_side: "right" or "left".
function Toolbar:layout(rect, landscape, rail_side)
    self.rect, self.landscape, self.rail_side = rect, landscape, rail_side
    local t = Theme.touch
    local items = { { item = self.tools, len = math.floor(t * 1.25) * 2 } }
    for __, b in ipairs(self.buttons) do items[#items + 1] = { item = b, len = t } end
    local along = landscape and rect.h or rect.w
    local used = 0
    for __, it in ipairs(items) do used = used + it.len end
    local gap = math.floor((along - used) / (#items + 1))
    local pos = gap
    for __, it in ipairs(items) do
        if landscape then
            it.item:setRect(rect.x + math.floor((rect.w - t) / 2), rect.y + pos, t, it.len)
        else
            it.item:setRect(rect.x + pos, rect.y + math.floor((rect.h - t) / 2), it.len, t)
        end
        pos = pos + it.len + gap
    end
end

--- Paints the bar; a solved game shows it empty.
function Toolbar:paint(bb)
    local r = self.rect
    bb:paintRect(r.x, r.y, r.w, r.h, Theme.WHITE)
    local hair = Theme.line.hair
    if not self.landscape then
        bb:paintRect(r.x, r.y, r.w, hair, Theme.BLACK)
    elseif self.rail_side == "left" then
        bb:paintRect(r.x + r.w - hair, r.y, hair, r.h, Theme.BLACK)
    else
        bb:paintRect(r.x, r.y, hair, r.h, Theme.BLACK)
    end
    if self.game.solved then return end
    self.tools:paint(bb)
    for __, b in ipairs(self.buttons) do b:paint(bb) end
end

--- The tool id or button under a point: returns "tool", id or "button", btn.
function Toolbar:hit(x, y)
    if self.tools:contains(x, y) then
        local k = self.tools:segmentAt(x, y)
        return k and "tool", k and self.tools.items[k].id
    end
    for __, b in ipairs(self.buttons) do
        if b:contains(x, y) then return "button", b end
    end
end

return Toolbar
