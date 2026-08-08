local CmdrUtil = require(script.Parent.Parent.Util)

return function(_, Player: Player): string
    return CmdrUtil.Unlock_Areas(Player)
end
