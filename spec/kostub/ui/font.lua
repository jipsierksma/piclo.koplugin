local Screen = require("device").screen
return {
    getFace = function(_, name, size)
        return { name = name, size = Screen:scaleBySize(size) }
    end,
}
