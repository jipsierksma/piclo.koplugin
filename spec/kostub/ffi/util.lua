return {
    template = function(s, ...)
        local args = { ... }
        return (s:gsub("%%(%d)", function(k) return tostring(args[tonumber(k)]) end))
    end,
}
