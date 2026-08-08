local CmdrUtil = require(script.Parent.Parent.Util)

return function(_, Player: Player, Amount: number): string
    return CmdrUtil.Remove_Cash(Player, Amount)
end
