-- Cheap static checks for mistakes luacheck would catch, since luacheck
-- isn't always installed.
local function luaFiles()
    local list = {}
    local p = io.popen("find main.lua _meta.lua piclo -name '*.lua'")
    for f in p:lines() do list[#list + 1] = f end
    p:close()
    return list
end

describe("lint", function()
    it("never shadows gettext's _ with a loop variable", function()
        for _, file in ipairs(luaFiles()) do
            local src = io.open(file):read("*a")
            if src:find('require%("gettext"%)') then
                assert(not src:find("for _[,%s=]"), file .. " uses _ as a loop variable")
            end
        end
    end)

    it("has no print calls in runtime code", function()
        for _, file in ipairs(luaFiles()) do
            local src = io.open(file):read("*a")
            assert(not src:find("[^%w_.:]print%("), file .. " calls print")
        end
    end)
end)
