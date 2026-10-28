-- Piclo's own translations: the .po reader, adding them to KOReader's
-- gettext table, and each language file covering every string in the code.
local L10n = require("piclo/l10n")

local function read(path)
    local f = assert(io.open(path))
    local s = f:read("*a")
    f:close()
    return s
end

-- Every _("...") and N_("...", "...") in the plugin's Lua files, and as a
-- second result every C_("context", "...") as { [context] = { [msgid] = true } }.
local function sourceStrings()
    local files = { "main.lua" }
    local p = io.popen("find piclo -name '*.lua'")
    for f in p:lines() do files[#files + 1] = f end
    p:close()
    local found, contexts = {}, {}
    for _, file in ipairs(files) do
        local src = read(file)
        for s in src:gmatch('[^%w_]_%("(.-)"%)') do found[s] = true end
        for ctx, s in src:gmatch('C_%("(.-)",%s*"(.-)"%)') do
            contexts[ctx] = contexts[ctx] or {}
            contexts[ctx][s] = true
        end
        for one, many in src:gmatch('N_%("(.-)",%s*"(.-)"') do
            found[one] = true
            found[many] = "plural of " .. one
        end
    end
    return found, contexts
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

    it("keeps entries with a context apart", function()
        local po = table.concat({
            'msgid "Restart"', 'msgstr "Herstarten (algemeen)"', "",
            'msgctxt "Piclo"', 'msgid "Restart"', 'msgstr "Opnieuw"',
            -- no blank line: the context still starts a new entry
            'msgctxt "Piclo"', 'msgid "Done"', 'msgstr "Klaar"',
        }, "\n")
        local t, contexts = L10n.parse(po)
        assert.are.equal("Herstarten (algemeen)", t["Restart"])
        assert.are.equal("Opnieuw", contexts.Piclo["Restart"])
        assert.are.equal("Klaar", contexts.Piclo["Done"])
        assert.is_nil(t["Done"])
    end)

    it("adds Dutch to KOReader's table without changing KOReader's own words", function()
        local gettext = { current_lang = "nl_NL", translation = { Cancel = "Annuleren (KOReader)" } }
        assert.is_true(L10n.load(".", gettext) > 0)
        assert.are.equal("Ei", gettext.translation["Egg"])
        assert.are.equal("Annuleren (KOReader)", gettext.translation["Cancel"])
    end)

    it("uses Piclo's wording for its own labels where KOReader has another", function()
        local gettext = require("gettext")
        local saved = { gettext.current_lang, gettext.translation, gettext.context }
        gettext.current_lang, gettext.translation, gettext.context = "fr", { Restart = "Redémarrer" }, {}
        L10n.load(".", gettext)
        local ok, err = pcall(function()
            assert.are.equal("Redémarrer", gettext.translation["Restart"])
            assert.are.equal("Recommencer", L10n.pgettext("Piclo", "Restart"))
            -- No Piclo wording in that context: KOReader's, else English.
            -- (The stub's _() is English unless .translate stands in for KOReader.)
            gettext.translate = function(s) return s == "Open" and "Ouvrir" or s end
            assert.are.equal("Ouvrir", L10n.pgettext("Piclo", "Open"))
            assert.are.equal("Unknown", L10n.pgettext("Piclo", "Unknown"))
        end)
        gettext.translate = nil
        gettext.current_lang, gettext.translation, gettext.context = saved[1], saved[2], saved[3]
        assert(ok, err)
    end)

    it("reads the file once per language", function()
        local gettext = { current_lang = "nl_NL", translation = {} }
        assert.is_true(L10n.load(".", gettext) > 0)
        gettext.translation["Egg"] = nil
        assert.are.equal(0, L10n.load(".", gettext))
        assert.is_nil(gettext.translation["Egg"])
    end)

    it("leaves English and unknown languages alone", function()
        assert.are.equal(0, L10n.load(".", { current_lang = "C", translation = {} }))
        assert.are.equal(0, L10n.load(".", { current_lang = "xx_YY", translation = {} }))
    end)

    for lang, name in pairs({ nl = "Dutch", de = "German", fr = "French" }) do
        it("has " .. name .. " for every string in the code, with the same placeholders", function()
            local t, translated = L10n.parse(read("l10n/" .. lang .. "/piclo.po"))
            local strings, contexts = sourceStrings()
            local pluralOf = {}
            for ctx, list in pairs(contexts) do
                for s in pairs(list) do
                    local str = translated[ctx] and translated[ctx][s]
                    assert(str, "no " .. name .. " for: " .. ctx .. " | " .. s)
                    assert.are.equal(placeholders(s), placeholders(str))
                end
            end
            for many, how in pairs(strings) do
                if how ~= true then pluralOf[how:sub(#"plural of " + 1)] = many end
            end
            for s, how in pairs(strings) do
                if how == true then
                    local str = t[s]
                    assert(str, "no " .. name .. " for: " .. s)
                    if type(str) == "table" then
                        -- Every form may use the count, even the singular
                        -- (French uses it for 0 and 1).
                        local allowed = placeholders(pluralOf[s])
                        for __, form in pairs(str) do
                            for p in form:gmatch("%%%d") do
                                assert(allowed:find(p, 1, true), p .. " not in: " .. pluralOf[s])
                            end
                        end
                    else
                        assert.are.equal(placeholders(s), placeholders(str))
                    end
                end
            end
        end)
    end
end)
