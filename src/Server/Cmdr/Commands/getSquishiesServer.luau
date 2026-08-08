local CmdrUtil = require(script.Parent.Parent.Util)

return function(_, Player: Player, Weight: number?): string
    return CmdrUtil.Get_Squishies(Player, Weight)
end
