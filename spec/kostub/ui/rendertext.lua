--[[
Text as blocks: each character a box of its advance and the cap height.
Advances follow Noto Sans roughly (narrow i/l/t/space, wide m/w, capitals a
bit wider than lowercase) so layouts that fit here fit on a device too;
digits are tabular at 0.55 em, as in KOReader's cfont.
]]
local RenderText = {}

local NARROW = { i = 0.28, l = 0.28, j = 0.28, t = 0.34, f = 0.34, r = 0.41, [" "] = 0.26,
    ["."] = 0.27, [","] = 0.27, [":"] = 0.27, ["'"] = 0.22, I = 0.3 }
local WIDE = { m = 0.92, w = 0.8, M = 0.9, W = 0.95 }

local function em(ch)
    if NARROW[ch] then return NARROW[ch] end
    if WIDE[ch] then return WIDE[ch] end
    if ch:match("%d") then return 0.55 end
    if ch:match("%u") then return 0.65 end
    return 0.56
end

-- Advances of each character in px (a UTF-8 sequence counts as one).
function RenderText.advances(face, text)
    local out = {}
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        out[#out + 1] = math.ceil(face.size * em(ch))
    end
    return out
end

local function cap(face) return math.ceil(face.size * 0.72) end

function RenderText:sizeUtf8Text(_, _, face, text)
    local w = 0
    for __, a in ipairs(RenderText.advances(face, text)) do w = w + a end
    return { x = w, y_top = cap(face), y_bottom = math.ceil(face.size * 0.2) }
end

-- Paints at most max_w px of the text (all of it when nil).
function RenderText:renderUtf8Text(bb, x, baseline, face, text, _, _, color, max_w)
    local pen = 0
    for __, a in ipairs(RenderText.advances(face, text)) do
        if max_w and pen + a > max_w then break end
        bb:paintRect(x + pen + 1, baseline - cap(face), math.max(1, a - 2), cap(face), color or { a = 0 })
        pen = pen + a
    end
    return pen
end

return RenderText
