-- luacheck configuration. KOReader runs LuaJIT (Lua 5.1 semantics).
std = "luajit"
max_line_length = 120
unused_args = false
-- `__` is the throwaway loop variable (`_` is gettext), so nested loops reuse it.
ignore = { "4../__" }

-- KOReader globals are allowed only in files that genuinely need them;
-- list them per file here rather than globally.
read_globals = {}

-- Puzzle data is loaded with gettext's _ in its environment
-- (piclo/data/catalog.lua, piclo/coach.lua).
files["piclo/data/"] = {
    read_globals = { "_" },
}

-- Translatable paragraphs stay on one line: xgettext reads _("...") whole.
for __, f in ipairs({ "piclo/data/practice.lua", "piclo/ui/screens/help.lua", "piclo/ui/screens/settings.lua" }) do
    files[f] = { max_string_line_length = false, max_line_length = false }
end

files["spec/"] = {
    globals = { "describe", "it", "before_each", "assert" },
}

-- Deliberately broken or minimal packs for the catalog specs.
exclude_files = { "../koreader-ref/", "tools/drafts/", "spec/fixtures/" }
