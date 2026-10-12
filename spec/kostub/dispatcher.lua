local Dispatcher = { actions = {} }
function Dispatcher:registerAction(name, value)
    self.actions[name] = value
    return true
end
return Dispatcher
