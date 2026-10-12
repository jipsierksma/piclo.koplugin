--[[
Picture Logic: registers the menu entry and a Dispatcher action (so it can
be bound to a gesture or launched from a home-screen plugin), and hands off
to the app controller. Everything else lives under piclogic/. KOReader's
plugin loader keeps this directory on package.path after loading
(frontend/pluginloader.lua), so the namespaced requires resolve later.
]]

local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local PicLogic = WidgetContainer:extend{
    name = "piclogic",
    is_doc_only = false,
}

function PicLogic:onDispatcherRegisterActions()
    Dispatcher:registerAction("piclogic_open", {
        category = "none",
        event = "PicLogicOpen",
        title = _("Picture Logic"),
        general = true,
    })
end

function PicLogic:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function PicLogic:addToMainMenu(menu_items)
    menu_items.piclogic = {
        text = _("Picture Logic"),
        sorting_hint = "tools",
        callback = function() self:onPicLogicOpen() end,
    }
end

function PicLogic:onPicLogicOpen()
    if not self.app then
        local App = require("piclogic/app")
        -- version comes from _meta.lua, merged in by the plugin loader
        self.app = App.new{ ui = self.ui, path = self.path, version = self.version }
    end
    self.app:open()
    return true
end

return PicLogic
