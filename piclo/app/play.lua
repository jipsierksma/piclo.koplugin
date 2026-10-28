--[[
The game in play, mixed into App (piclo/app.lua): starting and saving it,
the debounced progress writes, solving, showing the solution and the
pause before the reveal.
]]

local UIManager = require("ui/uimanager")
local Game = require("piclo/game")

local Play = {}

-- Seconds the finished grid stays up before the reveal.
Play.REVEAL_DELAY = 0.8
-- At most one progress write per this many seconds while playing.
Play.FLUSH_DELAY = 5

function Play:startGame(puzzle)
    self:stopGame()
    local progress = self:progress()
    self.game = Game.new{
        puzzle = puzzle,
        cells = progress:board(puzzle),
        elapsed = progress:elapsed(puzzle.id),
    }
    self.game:resume()
    progress:setLastPuzzle(puzzle.id)
end

function Play:saveGame()
    local game = self.game
    if not game or game.solved or game.practice then return end
    local p = game.puzzle
    self:progress():saveBoard(p.id, game.board.cells, p.w * p.h, game:elapsed(), game.board:isEmpty())
end

--- Saves and lets go of the game (leaving its screen).
function Play:stopGame()
    if not self.game then return end
    self.game:pause()
    self:saveGame()
    self.game = nil
    self:flush()
end

--- Clears the board in play and starts its time over.
function Play:restartGame()
    if not self.game then return end
    self.game:restart()
    self:saveGame()
    self:scheduleFlush()
    self:render()
end

--[[
"Show solution": records the puzzle as revealed (not solved), forgets the
board in play and shows the picture.
]]
function Play:showSolution()
    local game = self.game
    if not game then return end
    game:pause()
    local progress, p = self:progress(), game.puzzle
    -- Asked before recording, like the game screen did: the board's room for
    -- an unlock line has to match the picture's.
    local unlock_room = self:collection():wouldUnlock(p)
    progress:saveBoard(p.id, nil, 0, game:elapsed(), true)
    progress:markSolved(p.id, game:elapsed(), true)
    self.game = nil
    self:flush()
    self:replaceTop({ name = "reveal", data = {
        mode = "solved",
        puzzle = p,
        revealed = true,
        next_pack = self:collection():nextPackAfter(p),
        unlocked = {},
        unlock_room = unlock_room,
    } }, "full")
end

--- Forgets all puzzle progress (settings stay) and drops the game in play.
function Play:resetProgress()
    self:cancelReveal()
    self.game, self.held_game = nil, nil
    self:progress():resetAll()
    self:flush()
    self.stack = { { name = "home" }, { name = "settings", cleared = true } }
    self:render()
end

function Play:scheduleFlush()
    if self.flush_pending then return end
    self.flush_pending = true
    UIManager:scheduleIn(self.FLUSH_DELAY, self.flush_task)
end

--- Writes progress now (also cancels a pending debounced write).
function Play:flush()
    if self.flush_pending then
        UIManager:unschedule(self.flush_task)
        self.flush_pending = false
    end
    self:saveGame()
    if self._progress then self._progress:flush() end
end

function Play:onMove()
    self:saveGame()
    self:scheduleFlush()
end

-- Records the solve, then shows the reveal after a short pause.
function Play:onSolved(game)
    local progress, p, collection = self:progress(), game.puzzle, self:collection()
    local locked_before = collection:lockedPacks()
    local unlock_room = collection:wouldUnlock(p)
    progress:saveBoard(p.id, nil, 0, game:elapsed(), true)
    local result = progress:markSolved(p.id, game:elapsed())
    local unlocked = collection:newlyUnlocked(locked_before)
    collection:recordUnlocks()
    self:flush()
    local data = {
        mode = "solved",
        puzzle = p,
        elapsed = game:elapsed(),
        best = progress:best(p.id),
        result = result,
        next_pack = collection:nextPackAfter(p),
        unlock_room = unlock_room,
        unlocked = unlocked,
    }
    self.reveal_task = function()
        self.reveal_task = nil
        if not self.host then return end
        self.game = nil
        self:replaceTop({ name = "reveal", data = data }, "full")
    end
    UIManager:scheduleIn(self.REVEAL_DELAY, self.reveal_task)
end

function Play:cancelReveal()
    if self.reveal_task then
        UIManager:unschedule(self.reveal_task)
        self.reveal_task = nil
    end
end

return Play
