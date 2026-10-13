--[[
Small text formatting helpers with no KOReader dependencies.
]]

local Format = {}

--- Seconds as "4:12", or "1:02:03" past an hour.
function Format.duration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end

return Format
