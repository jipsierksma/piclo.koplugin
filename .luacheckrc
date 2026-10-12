-- luacheck configuration. KOReader runs LuaJIT (Lua 5.1 semantics).
std = "luajit"
max_line_length = 120
unused_args = false

-- KOReader globals are allowed only in files that genuinely need them;
-- list them per file here rather than globally.
read_globals = {}

files["spec/"] = {
    globals = { "describe", "it", "before_each", "assert" },
}

exclude_files = { "../koreader-ref/" }
