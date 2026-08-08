local CmdrUtil = require(script.Parent.Parent.Util)

return function(_, Player: Player, Amount: number): string
    return CmdrUtil.Set_Cash(Player, Amount)
end
