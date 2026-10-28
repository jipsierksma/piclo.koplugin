-- Piclo's own translations: the .po reader, adding them to KOReader's
-- gettext table, and the Dutch file covering every string in the code.
local L10n = require("piclo/l10n")

local function read(path)
    local f = assert(io.open(path))
    local s = f:read("*a")
    f:close()
    return s
end

-- Every _("...") and N_("...", "...") in the plugin's Lua files.
local function sourceStrings()
    local files = { "main.lua" }
    local p = io.popen("find piclo -name '*.lua'")
    for f in p:lines() do files[#files + 1] = f end
    p:close()
    local found = {}
    for _, file in ipairs(files) do
        local src = read(file)
        for s in src:gmatch('[^%w_]_%("(.-)"%)') do found[s] = true end
        for one, many in src:gmatch('N_%("(.-)",%s*"(.-)"') do
            found[one] = true
            found[many] = "plural of " .. one
        end
    end
    return found
end

local function placeholders(s)
    local set = {}
    for p in s:gmatch("%%%d") do set[#set + 1] = p end
    table.sort(set)
    return table.concat(set, " ")
end

describe("translations", function()
    it("reads singular, plural, multi-line and escaped entries", function()
        local po = table.concat({
            'msgid ""', 'msgstr "Content-Type: text/plain; charset=UTF-8\\n"', "",
            'msgid "Mug"', 'msgstr "Mok"', "",
            'msgid "Long"', 'msgstr ""', '"two "', '"lines"', "",
            'msgid "Quote \\"x\\""', 'msgstr "Aanhaling \\"x\\""', "",
            'msgid "1 square"', 'msgid_plural "%1 squares"', 'msgstr[0] "1 vakje"', 'msgstr[1] "%1 vakjes"', "",
            "#, fuzzy", 'msgid "Unsure"', 'msgstr "Onzeker"', "",
            'msgid "Empty"', 'msgstr ""',
        }, "\n")
        local t = L10n.parse(po)
        assert.are.equal("Mok", t["Mug"])
        assert.are.equal("two lines", t["Long"])
        assert.are.equal('Aanhaling "x"', t['Quote "x"'])
        assert.are.same({ [0] = "1 vakje", [1] = "%1 vakjes" }, t["1 square"])
        assert.is_nil(t["Unsure"])
        assert.is_nil(t["Empty"])
        assert.is_nil(t[""])
    end)

    it("adds Dutch to KOReader's table without changing KOReader's own words", function()
        local gettext = { current_lang = "nl_NL", translation = { Cancel = "Annuleren (KOReader)" } }
        assert.is_true(L10n.load(".", gettext) > 0)
        assert.are.equal("Ei", gettext.translation["Egg"])
        assert.are.equal("Annuleren (KOReader)", gettext.translation["Cancel"])
    end)

    it("leaves English and unknown languages alone", function()
        assert.are.equal(0, L10n.load(".", { current_lang = "C", translation = {} }))
        assert.are.equal(0, L10n.load(".", { current_lang = "xx_YY", translation = {} }))
    end)

    it("has Dutch for every string in the code, with the same placeholders", function()
        local nl = L10n.parse(read("l10n/nl/piclo.po"))
        local plurals = {}
        for id, str in pairs(nl) do
            if type(str) == "table" then plurals[id] = str end
        end
        for s, how in pairs(sourceStrings()) do
            if how == true then
                local str = nl[s]
                assert(str, "no Dutch for: " .. s)
                local first = type(str) == "table" and str[0] or str
                assert.are.equal(placeholders(s), placeholders(first))
            end
        end
        for id, forms in pairs(plurals) do
            assert.are.equal(placeholders(id) .. "", placeholders(forms[0]))
        end
    end)
end)
