--[[
Loads our own SVG icon set from piclogic/icons/ (one stroke style, not the
user-themeable mdlight set). Icons are IconWidgets rendered once per
name and size and cached; they paint black on white.
]]

local Blitbuffer = require("ffi/blitbuffer")
local IconWidget = require("ui/widget/iconwidget")
local logger = require("logger")

local Icons = {
    dir = nil,
    cache = {},
    bitmaps = {},
}

-- Lightening black by 0.4 gives 0x66, the theme's secondary gray.
local DISABLED_LIGHTEN = 0.4

--- Called once by the app with the plugin's directory.
function Icons.init(plugin_dir)
    Icons.dir = plugin_dir .. "/piclogic/icons"
    Icons.cache = {}
end

--- Full path of an icon file, e.g. Icons.path("wordmark").
function Icons.path(name)
    return (Icons.dir or ".") .. "/" .. name .. ".svg"
end

function Icons.get(name, size)
    local key = name .. "@" .. size
    local icon = Icons.cache[key]
    if not icon then
        if not Icons.dir then
            logger.warn("piclogic: icons used before init")
        end
        icon = IconWidget:new{
            file = Icons.path(name),
            width = size,
            height = size,
        }
        Icons.cache[key] = icon
    end
    return icon
end

--[[
Icon pre-rendered into a white 8-bit bitmap, in one of three variants:
"normal", "disabled" (secondary gray) or "inverted" (white on black).
Variants are made off-screen so they come out right in night mode too:
blitting a bitmap to the screen honors night mode inversion.
]]
function Icons.bitmap(name, size, variant)
    variant = variant or "normal"
    local key = name .. "@" .. size .. ":" .. variant
    local bb = Icons.bitmaps[key]
    if not bb then
        bb = Blitbuffer.new(size, size, Blitbuffer.TYPE_BB8)
        bb:fill(Blitbuffer.COLOR_WHITE)
        Icons.get(name, size):paintTo(bb, 0, 0)
        if variant == "disabled" then
            bb:lightenRect(0, 0, size, size, DISABLED_LIGHTEN)
        elseif variant == "inverted" then
            bb:invertRect(0, 0, size, size)
        end
        Icons.bitmaps[key] = bb
    end
    return bb
end

--- Blits an icon variant centered in rect {x, y, w, h}.
function Icons.paint(bb, name, size, variant, rect)
    local src = Icons.bitmap(name, size, variant)
    local x = rect.x + math.floor((rect.w - size) / 2)
    local y = rect.y + math.floor((rect.h - size) / 2)
    bb:blitFrom(src, x, y, 0, 0, size, size)
end

--- Frees cached icons and bitmaps (call when the plugin window closes).
function Icons.free()
    for _, icon in pairs(Icons.cache) do
        icon:free()
    end
    for _, bb in pairs(Icons.bitmaps) do
        bb:free()
    end
    Icons.cache = {}
    Icons.bitmaps = {}
end

return Icons
