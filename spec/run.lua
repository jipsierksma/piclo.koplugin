--[[
Minimal busted-style test runner for machines without busted.
Usage: luajit spec/run.lua spec/foo_spec.lua [...]

Supports describe / it / before_each and the assert forms the specs use, so
the same spec files also run under real busted.
]]

package.path = "./?.lua;./spec/?.lua;" .. package.path

-- KOReader modules the data layer may touch, stubbed for plain Lua.
package.preload["gettext"] = function()
    return setmetatable({}, { __call = function(_, s) return s end })
end
package.preload["logger"] = function()
    local function noop() end
    return { dbg = noop, info = noop, warn = noop, err = noop }
end

local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function show(v)
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    for k, x in pairs(v) do
        parts[#parts + 1] = tostring(k) .. "=" .. show(x)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function check(ok, msg)
    if not ok then error(msg, 3) end
end

local assert_ = {
    are = {
        same = function(e, a) check(deepEqual(e, a), "expected " .. show(e) .. ", got " .. show(a)) end,
        equal = function(e, a) check(e == a, "expected " .. show(e) .. ", got " .. show(a)) end,
    },
    is_true = function(v) check(v == true, "expected true, got " .. show(v)) end,
    is_false = function(v) check(v == false, "expected false, got " .. show(v)) end,
    is_nil = function(v) check(v == nil, "expected nil, got " .. show(v)) end,
    is_not_nil = function(v) check(v ~= nil, "expected a value, got nil") end,
    truthy = function(v) check(v, "expected truthy, got " .. show(v)) end,
    falsy = function(v) check(not v, "expected falsy, got " .. show(v)) end,
    has_error = function(fn) check(not pcall(fn), "expected an error") end,
}
assert_.are_same = assert_.are.same
assert_.are_equal = assert_.are.equal
assert_.equals = assert_.are.equal
setmetatable(assert_, { __call = function(_, v, msg) check(v, msg or "assertion failed") return v end })

local passed, failed, failures = 0, 0, {}
local stack, hooks = {}, {}

function describe(name, fn) -- luacheck: ignore
    stack[#stack + 1] = name
    hooks[#hooks + 1] = {}
    fn()
    hooks[#hooks] = nil
    stack[#stack] = nil
end

function before_each(fn) -- luacheck: ignore
    local h = hooks[#hooks]
    h[#h + 1] = fn
end

function it(name, fn) -- luacheck: ignore
    local full = table.concat(stack, " ") .. " " .. name
    local ok, err = pcall(function()
        for _, level in ipairs(hooks) do
            for _, h in ipairs(level) do h() end
        end
        fn()
    end)
    if ok then
        passed = passed + 1
        io.write(".")
    else
        failed = failed + 1
        failures[#failures + 1] = full .. "\n    " .. tostring(err)
        io.write("F")
    end
end

assert = assert_ -- luacheck: ignore

for _, file in ipairs(arg) do
    local chunk, err = loadfile(file)
    if not chunk then
        failed = failed + 1
        failures[#failures + 1] = file .. "\n    " .. err
    else
        stack = { (file:match("([^/]+)_spec%.lua$") or file) }
        chunk()
    end
end

io.write("\n")
for _, f in ipairs(failures) do
    io.write("FAIL ", f, "\n")
end
io.write(string.format("%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
