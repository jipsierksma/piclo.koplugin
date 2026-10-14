--[[
Piclo: registers the menu entry and a Dispatcher action (so it can
be bound to a gesture or launched from a home-screen plugin), and hands off
to the app controller. Everything else lives under piclo/. KOReader's
plugin loader keeps this directory on package.path after loading
(frontend/pluginloader.lua), so the namespaced requires resolve later.
]]

local Device = require("device")
local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local Piclo = WidgetContainer:extend{
    name = "piclo",
    is_doc_only = false,
}

-- The board is played by touch; on a buttons-only device there would be no
-- way to play, so Piclo offers neither a menu entry nor a gesture action.
local function playable()
    return Device:isTouchDevice()
end

function Piclo:onDispatcherRegisterActions()
    if not playable() then return end
    Dispatcher:registerAction("piclo_open", {
        category = "none",
        event = "PicloOpen",
        title = _("Piclo"),
        general = true,
    })
end

function Piclo:init()
    if not playable() then return end
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function Piclo:addToMainMenu(menu_items)
    menu_items.piclo = {
        text = _("Piclo"),
        sorting_hint = "tools",
        callback = function() self:onPicloOpen() end,
    }
end

function Piclo:onPicloOpen()
    if not self.app then
        local App = require("piclo/app")
        -- version comes from _meta.lua, merged in by the plugin loader
        self.app = App.new{ ui = self.ui, path = self.path, version = self.version }
    end
    self.app:open()
    return true
end

-- The file manager or reader we belong to is closing (e.g. Exit, or opening
-- a book). Close our window too: KOReader only quits once no window is left.
function Piclo:onCloseWidget()
    if self.app then self.app:close() end
end

return Piclo
