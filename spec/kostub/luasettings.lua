-- LuaSettings over an in-memory "disk" (LuaSettings.files), so tests can
-- check what survives closing and reopening the plugin.
local LuaSettings = { files = {} }
LuaSettings.__index = LuaSettings

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

function LuaSettings:open(path)
    return setmetatable({ file = path, data = copy(LuaSettings.files[path] or {}) }, LuaSettings)
end
function LuaSettings:readSetting(k) return self.data[k] end
function LuaSettings:saveSetting(k, v) self.data[k] = v end
function LuaSettings:flush() LuaSettings.files[self.file] = copy(self.data) end
return LuaSettings
