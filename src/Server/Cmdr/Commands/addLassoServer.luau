local CmdrUtil = require(script.Parent.Parent.Util)

return function(_, Player: Player, LassoName: string): string
    return CmdrUtil.Add_Lasso(Player, LassoName)
end
