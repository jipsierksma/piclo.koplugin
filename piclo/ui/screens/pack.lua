--[[
Pack screen, the collection: a grid of square tiles.
  solved       the finished picture, crisp at a whole-pixel scale, and its title
  revealed     the same, with the title in gray: seen with "Show solution", not earned
  in progress  the board so far plus a small corner mark, "???" underneath
  new          a hairline square with the puzzle number, "???" underneath
Pages with swipes and the page-turn keys when the tiles don't fit one screen.
]]

local T = require("ffi/util").template
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local HeaderBar = require("piclo/ui/components/header_bar")
local Label = require("piclo/ui/components/label")
local Layout = require("piclo/ui/layout")
local Picture = require("piclo/ui/picture")
local Refresh = require("piclo/ui/refresh")
local Theme = require("piclo/ui/theme")

local PackScreen = {}
PackScreen.__index = PackScreen

--- opts: app, pack, page (1-based, optional)
function PackScreen.new(opts)
    local self = setmetatable({ app = opts.app, pack = opts.pack, page = opts.page or 1, labels = {} }, PackScreen)
    self.header = HeaderBar.new{ title = opts.pack.title, on_back = function() opts.app:back() end }
    return self
end

function PackScreen:free()
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
    local n = #self.pack.puzzles
    local grid = Layout.tileGrid(n, area.w, area.h, caption_h, gutter, Theme.min_tile)
    if grid.pages > 1 then
        area.h = area.h - Theme.touch
        grid = Layout.tileGrid(n, area.w, area.h, caption_h, gutter, Theme.min_tile)
    end
    self.grid = grid
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
                text = shown and p.title or _("???"),
                size = "caption",
                color = solved and Theme.BLACK or Theme.SECONDARY,
                max_width = rect.w,
            },
        }
        if not shown and not tile.cells then
            tile.number = self:label{ text = tostring(p.number), role = "title", color = Theme.SECONDARY }
        end
        self.tiles[#self.tiles + 1] = tile
    end
    self.pager = nil
    if grid.pages > 1 then
        self.pager = self:label{ text = T(_("%1 / %2"), self.page, grid.pages), size = "caption",
            color = Theme.SECONDARY }
        self.pager_rect = { x = 0, y = H - Theme.touch - Theme.space.s, w = W, h = Theme.touch }
    end
end

function PackScreen:paintTile(bb, tile)
    local r, g = tile.rect, Theme.space.s
    local inner = { x = r.x + g, y = r.y + g, w = r.w - 2 * g, h = r.h - 2 * g }
    -- Every tile gets the same hairline frame, so the grid reads as one set.
    bb:paintBorder(r.x, r.y, r.w, r.h, Theme.line.hair, Theme.BLACK)
    if tile.shown then
        Picture.paint(bb, tile.puzzle, inner)
    else
        if tile.cells then
            Picture.paint(bb, tile.puzzle, inner, { cells = tile.cells })
            local mk = Theme.mark
            bb:paintRect(r.x + r.w - mk - Theme.space.xs, r.y + Theme.space.xs, mk, mk, Theme.BLACK)
        else
            tile.number:paintIn(bb, r, "center")
        end
    end
    tile.caption:paintIn(bb, tile.caption_rect, "center")
end

function PackScreen:paint(bb)
    self.header:paint(bb)
    for __, tile in ipairs(self.tiles) do self:paintTile(bb, tile) end
    if self.pager then self.pager:paintIn(bb, self.pager_rect, "center") end
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
