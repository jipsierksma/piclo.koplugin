--[[
Cell states shared by the whole model. Plain integers keep boards as cheap
flat arrays. A puzzle solution uses the same values: FILLED for picture
pixels and CROSSED for background, so it can be compared to a board directly.
]]

return {
    UNKNOWN = 0,
    FILLED = 1,
    CROSSED = 2,
}
