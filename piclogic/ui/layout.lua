--[[
Pure layout math for pictures and tile grids (no KOReader requires).
]]

local Layout = {}

--[[
Largest whole-pixel scale at which a w x h picture fits in a box, plus the
offsets that center it. Every puzzle pixel becomes scale x scale screen
pixels, so thumbnails stay crisp. Scale is 0 if not even 1px fits.
]]
function Layout.fitPicture(w, h, box_w, box_h)
    local scale = math.max(0, math.floor(math.min(box_w / w, box_h / h)))
    return scale, math.floor((box_w - w * scale) / 2), math.floor((box_h - h * scale) / 2)
end

--[[
Tile grid for n tiles in an area, each tile a square plus a caption line.
Prefers the arrangement with the largest tiles that shows everything on one
page; if no arrangement keeps tiles at least min_tile, it pages instead.
Returns { cols, rows, tile, per_page, pages }.
]]
function Layout.tileGrid(n, area_w, area_h, caption_h, gutter, min_tile, max_cols)
    max_cols = max_cols or 5
    local best
    for cols = 2, max_cols do
        local rows = math.ceil(n / cols)
        local by_w = math.floor((area_w - (cols - 1) * gutter) / cols)
        local by_h = math.floor((area_h - rows * caption_h - (rows - 1) * gutter) / rows)
        local tile = math.min(by_w, by_h)
        if not best or tile > best.tile then
            best = { cols = cols, rows = rows, tile = tile }
        end
    end
    if best.tile >= min_tile then
        best.per_page, best.pages = n, 1
        return best
    end

    -- Paged: as many columns as fit at min_tile, rows by the height left.
    local cols = math.max(1, math.min(max_cols, math.floor((area_w + gutter) / (min_tile + gutter))))
    local tile = math.floor((area_w - (cols - 1) * gutter) / cols)
    local rows = math.max(1, math.floor((area_h + gutter) / (tile + caption_h + gutter)))
    tile = math.min(tile, math.floor((area_h - rows * caption_h - (rows - 1) * gutter) / rows))
    local per_page = cols * rows
    return { cols = cols, rows = rows, tile = tile, per_page = per_page, pages = math.ceil(n / per_page) }
end

return Layout
