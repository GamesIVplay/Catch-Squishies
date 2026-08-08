local CmdrUtil = require(script.Parent.Parent.Util)

return function(_, Player: Player, SquishyKey: string, PrimaryMutation: string?, Weight: number?): string
    return CmdrUtil.Add_Squishy(Player, SquishyKey, PrimaryMutation, Weight)
end
