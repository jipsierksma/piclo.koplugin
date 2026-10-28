--[[
Piclo's own translations. KOReader only loads its own catalog, so when the
app starts this reads l10n/<language>/piclo.po from the plugin folder (the
exact language first, e.g. nl_NL, then the base language, nl) and adds its
entries to KOReader's gettext table, which every _() call reads.

Strings KOReader already translates are left alone, so Piclo never changes
KOReader's own wording (and shared words like "Cancel" stay consistent).
Where Piclo needs its own wording for a word KOReader also has ("Restart" a
puzzle, not the device), the code uses C_("Piclo", ...): those entries have
msgctxt "Piclo" and go into gettext's context table, which KOReader leaves
empty for that context.
Fails soft: a missing or broken file just leaves the English text.
]]

local logger = require("logger")

local L10n = {}

local ESCAPES = { n = "\n", t = "\t", ['"'] = '"', ["\\"] = "\\" }

local function unquote(s)
    return (s:gsub("\\(.)", function(c) return ESCAPES[c] or c end))
end

--[[
Parses .po text into { [msgid] = msgstr } with plural entries as
{ [0] = singular, [1] = plural, ... } (KOReader's gettext layout), and as a
second result the entries with a msgctxt: { [msgctxt] = { [msgid] = msgstr } }.
Skips the header, fuzzy and untranslated entries.
]]
function L10n.parse(text)
    local out, contexts, entry, field = {}, {}, {}, nil
    local function add(id, str)
        local ctx = entry.msgctxt
        if ctx then
            contexts[ctx] = contexts[ctx] or {}
            contexts[ctx][id] = str
        else
            out[id] = str
        end
    end
    local function finish()
        local id = entry.msgid
        if id and id ~= "" and not entry.fuzzy then
            if entry.plural then
                if entry.plural[0] and entry.plural[0] ~= "" then add(id, entry.plural) end
            elseif entry.msgstr and entry.msgstr ~= "" then
                add(id, entry.msgstr)
            end
        end
        entry, field = {}, nil
    end
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = line:match("^%s*(.-)%s*$")
        if line == "" then
            finish()
        elseif line:sub(1, 2) == "#," then
            if line:find("fuzzy", 1, true) then entry.fuzzy = true end
        elseif line:sub(1, 1) ~= "#" then
            local key, idx, str = line:match('^(msg%a+)%[?(%d*)%]?%s+"(.*)"$')
            local more = line:match('^"(.*)"$')
            if key then
                -- A context starts the next entry, even without a blank line.
                if (entry[key] and key ~= "msgstr") or (key == "msgctxt" and entry.msgid) then finish() end
                if key == "msgstr" and idx ~= "" then
                    entry.plural = entry.plural or {}
                    field = { plural = tonumber(idx) }
                    entry.plural[field.plural] = unquote(str)
                else
                    field = { key = key }
                    entry[key] = unquote(str)
                end
            elseif more and field then
                if field.plural then
                    entry.plural[field.plural] = entry.plural[field.plural] .. unquote(more)
                else
                    entry[field.key] = entry[field.key] .. unquote(more)
                end
            end
        end
    end
    finish()
    return out, contexts
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

-- The language last loaded into each gettext table: the plugin loads its
-- translations whenever the file manager or a book opens, but reads the
-- file only once per language.
local loaded = setmetatable({}, { __mode = "k" })

--[[
Adds the translations for gettext's current language from <dir>/l10n.
Returns the number of entries added (0 for English, no file, or when this
language was loaded already).
]]
function L10n.load(dir, gettext)
    local lang = gettext.current_lang or "C"
    if lang == "C" or not gettext.translation then return 0 end
    if loaded[gettext] == lang then return 0 end
    loaded[gettext] = lang
    local base = lang:match("^(%a+)[_%-]")
    local text
    for __, name in ipairs({ lang, base }) do
        text = name and readFile(dir .. "/l10n/" .. name .. "/piclo.po")
        if text then break end
    end
    if not text then return 0 end
    local ok, entries, contexts = pcall(L10n.parse, text)
    if not ok then
        logger.warn("piclo: could not read translations for", lang, entries)
        return 0
    end
    local added = 0
    local function fill(into, from)
        for id, str in pairs(from) do
            if into[id] == nil then
                into[id] = str
                added = added + 1
            end
        end
    end
    fill(gettext.translation, entries)
    gettext.context = gettext.context or {}
    for ctx, list in pairs(contexts) do
        gettext.context[ctx] = gettext.context[ctx] or {}
        fill(gettext.context[ctx], list)
    end
    return added
end

--[[
gettext with a context, for Piclo's own wording of a word KOReader also
translates. Without a translation in that context it falls back to plain
_(msgid): KOReader's wording in languages Piclo has no file for, else English.
(KOReader's own pgettext would fall back to English straight away.)
]]
function L10n.pgettext(msgctxt, msgid)
    local gettext = require("gettext")
    local list = gettext.context and gettext.context[msgctxt]
    local str = list and list[msgid]
    if type(str) == "table" then str = str[0] end
    return str or gettext(msgid)
end

return L10n
