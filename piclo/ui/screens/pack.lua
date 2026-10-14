--[[
Pack screen, the collection: a grid of square tiles.
  solved       the finished picture, crisp at a whole-pixel scale, and its title
  revealed     the same, with the title in gray: seen with "Show solution", not earned
  in progress  the board so far plus a small corner mark, its number underneath
  new          a hairline square with "???" inside, its number underneath
Pages with swipes and the page-turn keys when the tiles don't fit one screen.

Right after a solve (opts.marked) the new picture gets a heavy frame and the
screen opens on its page, with a "Next puzzle" pill at the bottom (opts.next).
]]

local T = require("ffi/util").template
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local HeaderBar = require("piclo/ui/components/header_bar")
local Label = require("piclo/ui/components/label")
local Layout = require("piclo/ui/layout")
local Picture = require("piclo/ui/picture")
local Refresh = require("piclo/ui/refresh")
local TextButton = require("piclo/ui/components/text_button")
local Theme = require("piclo/ui/theme")

local PackScreen = {}
PackScreen.__index = PackScreen

--- opts: app, pack, page (1-based, optional), marked (puzzle id), next (puzzle)
function PackScreen.new(opts)
    local app = opts.app
    local self = setmetatable({ app = app, pack = opts.pack, page = opts.page, marked = opts.marked, labels = {} },
        PackScreen)
    self.header = HeaderBar.new{ title = opts.pack.title, on_back = function() app:back() end }
    if opts.next then
        local p = opts.next
        self.next_btn = TextButton.new{ text = _("Next puzzle"), primary = true,
            on_tap = function() app:openPuzzle(p) end }
    end
    return self
end

function PackScreen:free()
    if self.next_btn then self.next_btn:free() end
    self.header:freeText()
    Label.freeAll(self.labels)
    self.labels = {}
end

function PackScreen:label(opts)
    local l = Label.new(opts)
    self.labels[#self.labels + 1] = l
    return l
end

function PackScreen:layout(dimen)
    self.dimen = dimen
    Label.freeAll(self.labels)
    self.labels = {}
    local W, H = dimen.w, dimen.h
    self.header:layout(0, 0, W)

    local m, gutter = Theme.space.xl, Theme.space.l
    local caption_h = self:label{ text = "?", size = "caption" }.h + Theme.space.xs
    local area = { x = m, y = Theme.header_h + Theme.space.l, w = W - 2 * m, h = H - Theme.header_h - 2 * Theme.space.l }
    local bottom = H - Theme.space.s
    local t = Theme.touch
    if self.next_btn then
        local b = self.next_btn
        local bw = b:standardWidth(area.w)
        b:setRect(math.floor((W - bw) / 2), H - Theme.space.l - t, bw, t)
        area.h = area.h - t - Theme.space.l
        bottom = b.rect.y - Theme.space.s
    end
    local n = #self.pack.puzzles
    local grid = Layout.tileGrid(n, area.w, area.h, caption_h, gutter, Theme.min_tile)
    if grid.pages > 1 then
        area.h = area.h - t
        grid = Layout.tileGrid(n, area.w, area.h, caption_h, gutter, Theme.min_tile)
    end
    self.grid = grid
    if not self.page then self.page = self:pageOf(self.marked, grid.per_page) end
    self.page = math.max(1, math.min(self.page, grid.pages))

    local used_w = grid.cols * grid.tile + (grid.cols - 1) * gutter
    local x0 = area.x + math.floor((area.w - used_w) / 2)
    local first = (self.page - 1) * grid.per_page + 1
    local last = math.min(n, first + grid.per_page - 1)
    local progress = self.app:progress()
    self.tiles = {}
    for k = first, last do
        local p = self.pack.puzzles[k]
        local slot = k - first
        local col, row = slot % grid.cols, math.floor(slot / grid.cols)
        local rect = {
            x = x0 + col * (grid.tile + gutter),
            y = area.y + row * (grid.tile + caption_h + gutter),
            w = grid.tile,
            h = grid.tile,
        }
        local solved = progress:isSolved(p.id)
        local shown = solved or progress:isRevealed(p.id)
        local tile = {
            puzzle = p,
            rect = rect,
            caption_rect = { x = rect.x, y = rect.y + rect.h + Theme.space.xs, w = rect.w, h = caption_h },
            solved = solved,
            shown = shown,
            cells = (not shown) and progress:board(p) or nil,
            caption = self:label{
                text = shown and p.title or tostring(p.number),
                size = "caption",
                color = solved and Theme.BLACK or Theme.SECONDARY,
                max_width = rect.w,
            },
        }
        if not shown and not tile.cells then
            tile.unknown = self:label{ text = _("???"), role = "title", color = Theme.SECONDARY }
        end
        self.tiles[#self.tiles + 1] = tile
    end
    self.pager = nil
    if grid.pages > 1 then
        self.pager = self:label{ text = T(_("%1 / %2"), self.page, grid.pages), size = "caption",
            color = Theme.SECONDARY }
        self.pager_rect = { x = 0, y = bottom - t, w = W, h = t }
    end
end

--- The page showing a puzzle id (1 when nil or not in this pack).
function PackScreen:pageOf(id, per_page)
    for k, p in ipairs(self.pack.puzzles) do
        if p.id == id then return math.ceil(k / per_page) end
    end
    return 1
end

function PackScreen:paintTile(bb, tile)
    local r, g = tile.rect, Theme.space.s
    local inner = { x = r.x + g, y = r.y + g, w = r.w - 2 * g, h = r.h - 2 * g }
    -- Every tile gets the same hairline frame, so the grid reads as one set;
    -- the picture just solved gets a heavy one.
    local frame = tile.puzzle.id == self.marked and Theme.line.strong or Theme.line.hair
    bb:paintBorder(r.x, r.y, r.w, r.h, frame, Theme.BLACK)
    if tile.shown then
        Picture.paint(bb, tile.puzzle, inner)
    else
        if tile.cells then
            Picture.paint(bb, tile.puzzle, inner, { cells = tile.cells })
            local mk = Theme.mark
            bb:paintRect(r.x + r.w - mk - Theme.space.xs, r.y + Theme.space.xs, mk, mk, Theme.BLACK)
        else
            tile.unknown:paintIn(bb, r, "center")
        end
    end
    tile.caption:paintIn(bb, tile.caption_rect, "center")
end

function PackScreen:paint(bb)
    self.header:paint(bb)
    for __, tile in ipairs(self.tiles) do self:paintTile(bb, tile) end
    if self.pager then self.pager:paintIn(bb, self.pager_rect, "center") end
    if self.next_btn then self.next_btn:paint(bb) end
end

function PackScreen:changePage(delta)
    local page = self.page + delta
    if page < 1 or page > self.grid.pages then return end
    self.page = page
    self.app:rememberPage(page)
    self:layout(self.dimen)
    UIManager:setDirty(self.window, "ui")
end

function PackScreen:onTap(ges)
    local x, y = ges.pos.x, ges.pos.y
    local btn = self.header:buttonAt(x, y)
    if not btn and self.next_btn and self.next_btn:contains(x, y) then btn = self.next_btn end
    if btn then
        Refresh.press(self.window, btn.rect, function(b) btn:paint(b, true) end)
        return btn.on_tap()
    end
    for __, tile in ipairs(self.tiles) do
        local r = tile.rect
        if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h + tile.caption_rect.h then
            Refresh.press(self.window, r, function(b) b:invertRect(r.x, r.y, r.w, r.h) end)
            return self.app:openPuzzle(tile.puzzle)
        end
    end
end

function PackScreen:onSwipe(ges)
    if ges.direction == "west" then
        self:changePage(1)
    elseif ges.direction == "east" then
        self:changePage(-1)
    end
end

function PackScreen:onPageKey(forward)
    self:changePage(forward and 1 or -1)
end

return PackScreen
