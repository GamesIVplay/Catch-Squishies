local CmdrUtil = require(script.Parent.Parent.Util)

return function(_, SquishyKey: string, PrimaryMutation: string?, Weight: number?): string
    return CmdrUtil.Give_All_Players_Squishy(SquishyKey, PrimaryMutation, Weight)
end
