-- Text as blocks: each character a box of the face's digit width and cap height.
local RenderText = {}

local function metrics(face)
    return math.ceil(face.size * 0.55), math.ceil(face.size * 0.72)
end

function RenderText:sizeUtf8Text(_, _, face, text)
    local adv, cap = metrics(face)
    return { x = #text * adv, y_top = cap, y_bottom = math.ceil(face.size * 0.2) }
end

function RenderText:renderUtf8Text(bb, x, baseline, face, text, _, _, color)
    local adv, cap = metrics(face)
    for k = 0, #text - 1 do
        bb:paintRect(x + k * adv + 1, baseline - cap, adv - 2, cap, color or { a = 0 })
    end
    return #text * adv
end

return RenderText
