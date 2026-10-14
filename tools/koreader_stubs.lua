--[[
Lets runtime modules load under plain LuaJIT, outside KOReader: puts the repo
root on package.path and stubs the few KOReader modules the pure layers use.
Shared by spec/run.lua and the tools/ scripts; run them from the repo root.
]]

package.path = "./?.lua;./spec/?.lua;" .. package.path

-- English as written; a spec may set .translate to try longer languages.
package.preload["gettext"] = function()
    return setmetatable({
        ngettext = function(one, many, n) return n == 1 and one or many end,
    }, { __call = function(g, s) return g.translate and g.translate(s) or s end })
end

package.preload["logger"] = function()
    local function noop() end
    return { dbg = noop, info = noop, warn = noop, err = noop }
end
