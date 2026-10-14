-- ui/time with a clock the specs move by hand (seconds; to_s is the identity).
local time = { t = 0 }
function time.now() return time.t end
function time.to_s(t) return t end
return time
