--[[
Navigation, mixed into App (piclo/app.lua).

Navigation is a stack of routes ({name = "home" | "help" | "packs" | "pack"
| "game" | "reveal" | "settings", ...}); back pops one, so it returns to
wherever the screen was opened from: a collection opened from Packs goes
back to Packs, one reached from the home card goes back home. Screens are
rebuilt from data and settings each time they show, so a changed setting
takes effect as soon as its screen is back on top.
]]

local UIManager = require("ui/uimanager")
local Coach = require("piclo/coach")
local Game = require("piclo/game")
local GameScreen = require("piclo/ui/screens/game")
local HelpScreen = require("piclo/ui/screens/help")
local HomeScreen = require("piclo/ui/screens/home")
local Host = require("piclo/ui/host")
local PackScreen = require("piclo/ui/screens/pack")
local PacksScreen = require("piclo/ui/screens/packs")
local RevealScreen = require("piclo/ui/screens/reveal")
local SettingsScreen = require("piclo/ui/screens/settings")
local T = require("ffi/util").template
local _ = require("gettext")
local C_ = require("piclo/l10n").pgettext

local Routes = {}

--- Opens the app on its home screen (with help first, on the very first run).
function Routes:open()
    -- Still open but covered, e.g. a home-screen plugin put itself on top
    -- when the device woke: rendering would stay out of sight, so close
    -- (which saves) and open again on top.
    -- Also when a close is pending: start over rather than close under the player.
    if self.host and (self.close_task or UIManager:getTopmostVisibleWidget() ~= self.host) then
        self:close()
    end
    if not self.host then
        self.host = Host:new{ app = self }
        UIManager:show(self.host)
    end
    -- Also covers saves from before unlocks were remembered.
    self:collection():recordUnlocks()
    self.held_game = nil
    self.stack = { { name = "home" } }
    if not self:progress().seen_help then
        self:progress():setSeenHelp()
        self.stack[2] = { name = "help", first_run = true }
    end
    self:render()
end

function Routes:build(route)
    if route.name == "home" then return HomeScreen.new{ app = self } end
    if route.name == "help" then return HelpScreen.new{ app = self, first_run = route.first_run } end
    if route.name == "settings" then return SettingsScreen.new{ app = self, cleared = route.cleared } end
    if route.name == "packs" then return PacksScreen.new{ app = self, page = route.page } end
    if route.name == "pack" then
        return PackScreen.new{ app = self, pack = self:catalog():pack(route.pack_id), page = route.page,
            marked = route.marked }
    end
    if route.name == "game" and route.practice then return self:buildPractice(route.practice) end
    if route.name == "game" then
        local p = self.game.puzzle
        local deghost = self:setting("deghost_every")
        self.game:setMistakeMode(self:setting("mistakes"))
        return GameScreen.new{
            app = self,
            game = self.game,
            -- e.g. "Around the House · 7"
            title = T(_("%1 · %2"), self:catalog():pack(p.pack_id).title, p.number),
            deghost_every = (deghost and deghost > 0) and deghost or nil,
            highlight_done = self:setting("highlight_done"),
            hold_action = self:setting("hold_action"),
            show_timer = self:setting("show_timer"),
            rail_side = self:setting("rail_side"),
            unlock_room = self:collection():wouldUnlock(p),
        }
    end
    return RevealScreen.new{ app = self, data = route.data, rail_side = self:setting("rail_side") }
end

-- A practice board: guided, no menu or timer, and nothing is saved.
function Routes:buildPractice(k)
    local n = #self:lessons()
    self.game:setMistakeMode("off")
    return GameScreen.new{
        app = self,
        game = self.game,
        title = T(_("Practice %1 of %2"), k, n),
        highlight_done = self:setting("highlight_done"),
        hold_action = self:setting("hold_action"),
        rail_side = self:setting("rail_side"),
        practice = {
            coach = Coach.new(self:lessons()[k]),
            button = k < n and _("Next practice") or C_("Piclo", "Done"),
            on_button = function()
                if k < n then self:startPractice(k + 1, true) else self:finishPractice() end
            end,
        },
    }
end

--[[
Opens practice puzzle k on a fresh board, over How to play (or instead of
the one before). How to play can be opened from a game's menu, so a game in
play is put aside for when the practice ends.
]]
function Routes:startPractice(k, replace)
    if self.game and not self.game.practice then
        self.game:pause()
        self:flush()
        self.held_game = self.game
    else
        self:stopGame()
    end
    self.game = Game.new{ puzzle = self:lessons()[k].puzzle }
    self.game.practice = k
    local route = { name = "game", practice = k }
    if replace then self:replaceTop(route) else self:push(route) end
end

-- Leaving a practice board: the game put aside for it is back in play.
function Routes:leavePractice()
    self:stopGame()
    self.game, self.held_game = self.held_game, nil
end

--[[
"Done" after the last practice moves on rather than back to How to play:
on the first run to the first puzzle, otherwise to wherever How to play
was opened from.
]]
function Routes:finishPractice()
    self:leavePractice()
    self.stack[#self.stack] = nil
    local help = self.stack[#self.stack]
    if help and help.name == "help" then self.stack[#self.stack] = nil end
    local spot = self:collection():spotlight()
    if help and help.first_run and spot.puzzle and not self.game then
        return self:openPuzzle(spot.puzzle)
    end
    self:render()
end

-- The timer runs only while the board is on screen.
function Routes:render(refresh)
    local route = self.stack[#self.stack]
    if self.game then
        if route.name == "game" then self.game:resume() else self.game:pause() end
    end
    self.host:setScreen(self:build(route), refresh)
end

function Routes:push(route)
    self.stack[#self.stack + 1] = route
    self:render()
end

function Routes:replaceTop(route, refresh)
    self.stack[#self.stack] = route
    self:render(refresh)
end

function Routes:back()
    self:cancelReveal()
    local top = table.remove(self.stack)
    if top and top.practice then
        self:leavePractice()
    elseif top and top.name == "game" then
        self:stopGame()
    end
    if #self.stack == 0 then
        self:closeSoon()
    else
        self:render()
    end
end

--[[
Leaving: the window stays a moment (dropping taps) before it closes, so the
second tap of a double tap can't open something in the file browser below.
]]
function Routes:closeSoon()
    if not self.host or Host.TAP_GUARD <= 0 then return self:close() end
    self.host:guard()
    self.close_task = function()
        self.close_task = nil
        self:close()
    end
    UIManager:scheduleIn(Host.TAP_GUARD, self.close_task)
end

function Routes:showHelp()
    self:push{ name = "help" }
end

function Routes:showSettings()
    self:push{ name = "settings" }
end

function Routes:showPacks()
    self:push{ name = "packs" }
end

function Routes:showPack(pack_id)
    self:push{ name = "pack", pack_id = pack_id }
end

--- Paged screens remember their page so back returns to it.
function Routes:rememberPage(page)
    local top = self.stack[#self.stack]
    if top then top.page = page end
end

--- Unsolved puzzles open the board; solved and revealed ones their picture.
function Routes:openPuzzle(puzzle)
    -- Leaving a collection for a puzzle ends its "just solved" moment.
    local top = self.stack[#self.stack]
    if top and top.name == "pack" then top.marked = nil end
    local progress = self:progress()
    local revealed = progress:isRevealed(puzzle.id)
    if revealed or progress:isSolved(puzzle.id) then
        self:push{ name = "reveal", data = {
            mode = "view",
            puzzle = puzzle,
            best = progress:best(puzzle.id),
            revealed = revealed,
        } }
        return
    end
    self:startGame(puzzle)
    self:push{ name = "game" }
end

function Routes:playAgain(puzzle)
    self:progress():restart(puzzle.id)
    self:startGame(puzzle)
    self:replaceTop{ name = "game" }
end

--[[
From a reveal to the pack's collection, reusing it from the stack if
present. Otherwise (the puzzle came from the home card) the collection
takes the reveal's place, so back goes home rather than to Packs.
marked (optional): the puzzle id just solved, which the collection frames.
]]
function Routes:backToCollection(pack_id, marked)
    local route
    for k = #self.stack, 1, -1 do
        local r = self.stack[k]
        if r.name == "pack" and r.pack_id == pack_id then
            for j = #self.stack, k + 1, -1 do self.stack[j] = nil end
            route = r
            break
        end
    end
    if not route then
        route = { name = "pack", pack_id = pack_id }
        self.stack[math.max(1, #self.stack)] = route
    end
    route.marked = marked
    -- Open on the page with the new picture.
    if marked then route.page = nil end
    self:render()
end

--[[
From the reveal of a pack's last puzzle to the next pack's collection. It
takes the place of the reveal and the finished pack's collection, so back
goes where that collection would have: Packs, or home.
]]
function Routes:showNextPack(pack_id)
    self.stack[#self.stack] = nil
    local below = self.stack[#self.stack]
    if below and below.name == "pack" then self.stack[#self.stack] = nil end
    self:push{ name = "pack", pack_id = pack_id }
end

return Routes
