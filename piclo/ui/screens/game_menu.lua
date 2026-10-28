--[[
The game's more menu, a bottom sheet: how long the puzzle has been played,
Restart puzzle, Show solution and Settings. Restart (on a started board)
and Show solution ask first, in a confirm sheet that replaces the menu.
]]

local T = require("ffi/util").template
local _ = require("gettext")
local C_ = require("piclo/l10n").pgettext
local Format = require("piclo/util/format")
local Sheet = require("piclo/ui/components/sheet")

local GameMenu = {}

function GameMenu.confirmRestart(screen)
    local window, app = screen.window, screen.app
    if screen.game.board:isEmpty() then
        window:closeSheet(false)
        return app:restartGame()
    end
    window:showSheet(Sheet.confirm{
        title = _("Restart this puzzle?"),
        text = _("Your marks and time on this board will be cleared."),
        ok_text = C_("Piclo", "Restart"),
        on_ok = function()
            window:closeSheet(false)
            app:restartGame()
        end,
    })
end

function GameMenu.confirmReveal(screen)
    local window, app = screen.window, screen.app
    window:showSheet(Sheet.confirm{
        title = _("Show the solution?"),
        text = _("The picture joins your collection as revealed rather than solved. You can play it again any time."),
        ok_text = _("Show solution"),
        on_ok = function()
            window:closeSheet(false)
            app:showSolution()
        end,
    })
end

--- Opens the menu over a game screen.
function GameMenu.open(screen)
    local window = screen.window
    window:showSheet(Sheet.menu{
        title = screen.title,
        subtitle = T(_("Played for %1"), Format.duration(screen.game:elapsed())),
        items = {
            { text = _("Restart puzzle"), on_tap = function() GameMenu.confirmRestart(screen) end },
            { text = _("Show solution"), on_tap = function() GameMenu.confirmReveal(screen) end },
            -- People get stuck mid-puzzle, so the rules are one tap away here too.
            { text = _("How to play"), on_tap = function()
                window:closeSheet(false)
                screen.app:showHelp()
            end },
            { text = _("Settings"), on_tap = function()
                window:closeSheet(false)
                screen.app:showSettings()
            end },
        },
    })
end

return GameMenu
