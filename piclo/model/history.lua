--[[
Undo/redo stack of compound moves (see model/board). The history only stores
moves; the caller applies or reverts them on the board.
]]

local History = {}
History.__index = History

History.DEFAULT_LIMIT = 500

function History.new(limit)
    return setmetatable({
        limit = limit or History.DEFAULT_LIMIT,
        done = {},
        undone = {},
    }, History)
end

--- Records a freshly applied move; any redo branch is discarded.
function History:push(move)
    local done = self.done
    done[#done + 1] = move
    if #done > self.limit then
        table.remove(done, 1)
    end
    self.undone = {}
end

--- Returns the move to revert, or nil.
function History:undo()
    local move = table.remove(self.done)
    if move then
        self.undone[#self.undone + 1] = move
    end
    return move
end

--- Returns the move to re-apply, or nil.
function History:redo()
    local move = table.remove(self.undone)
    if move then
        self.done[#self.done + 1] = move
    end
    return move
end

function History:canUndo()
    return #self.done > 0
end

function History:canRedo()
    return #self.undone > 0
end

function History:clear()
    self.done = {}
    self.undone = {}
end

return History
