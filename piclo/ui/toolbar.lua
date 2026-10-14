--[[
The game toolbar: the Fill/Cross segmented control, Undo and Redo side by
side, Hint and, when mistake checking is "on request", Check. A bar along
the bottom in portrait, a rail beside the board in landscape, with a
hairline on the side facing the board.

Four fixed slots, spaced evenly: tools, undo/redo, hint, check. The check
slot stays empty when checking is off, so nothing moves when it's turned
on and buttons are always where the player learned them.
]]

local Game = require("piclo/game")
local IconButton = require("piclo/ui/components/icon_button")
local Segmented = require("piclo/ui/components/segmented")
local Theme = require("piclo/ui/theme")

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
        -- A magnifier, "look over my work": a check mark would read as "done".
        self.check_btn = IconButton.new{ icon = "inspect", on_tap = on.check }
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
    -- Each slot holds its items end to end; a slot may be empty (no check).
    local slots = {
        { self.tools, len = math.floor(t * 1.25) * 2 },
        { self.undo_btn, self.redo_btn, len = 2 * t },
        { self.hint_btn, len = t },
        { self.check_btn, len = t },
    }
    local along = landscape and rect.h or rect.w
    local used = 0
    for __, slot in ipairs(slots) do used = used + slot.len end
    local gap = math.floor((along - used) / (#slots + 1))
    local pos = gap
    for __, slot in ipairs(slots) do
        local at = pos
        for _, item in ipairs(slot) do
            local len = item == self.tools and slot.len or t
            if landscape then
                item:setRect(rect.x + math.floor((rect.w - t) / 2), rect.y + at, t, len)
            else
                item:setRect(rect.x + at, rect.y + math.floor((rect.h - t) / 2), len, t)
            end
            at = at + len
        end
        pos = pos + slot.len + gap
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
