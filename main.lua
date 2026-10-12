--[[
Picture Logic: registers the menu entry and hands off to the app controller.
Everything else lives under piclogic/. KOReader's plugin loader keeps this
directory on package.path after loading (frontend/pluginloader.lua), so the
namespaced requires below resolve when the menu is used.
]]

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local PicLogic = WidgetContainer:extend{
    name = "piclogic",
    is_doc_only = false,
}

function PicLogic:init()
    self.ui.menu:registerToMainMenu(self)
end

function PicLogic:getApp()
    if not self.app then
        local App = require("piclogic/app")
        self.app = App.new{ ui = self.ui, path = self.path }
    end
    return self.app
end

function PicLogic:addToMainMenu(menu_items)
    -- Preview build: one entry per board size until the home screen lands.
    local function play(index)
        return function() self:getApp():openPack(index) end
    end
    menu_items.piclogic = {
        text = _("Picture Logic"),
        sorting_hint = "tools",
        sub_item_table = {
            { text = _("Play 5×5"), callback = play(1) },
            { text = _("Play 10×10"), callback = play(2) },
            { text = _("Play 15×15"), callback = play(3) },
        },
    }
end

return PicLogic
