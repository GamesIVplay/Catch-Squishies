local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)

local function Normalize(Text: string): string
    return string.lower(string.gsub(Text, "%s+", ""))
end

local function Resolve_Lasso(Text: string): string?
    local NormalizedText = Normalize(Text)

    for _, LassoName in Lassos.Order do
        local LassoData = Lassos.Get(LassoName)

        if not LassoData then
            continue
        end

        if NormalizedText == Normalize(LassoData.Name) or NormalizedText == Normalize(LassoData.DisplayName) then
            return LassoData.Name
        end
    end

    return nil
end

local function Get_Lasso_Names(): { string }
    local Names = {}

    for _, LassoName in Lassos.Order do
        table.insert(Names, LassoName)
    end

    return Names
end

return function(Cmdr)
    Cmdr:RegisterType("lasso", {
        Transform = function(Text: string)
            return {
                Raw = Text,
                Value = Resolve_Lasso(Text),
            }
        end,

        Validate = function(Value)
            return Value.Value ~= nil, `Unknown lasso. Valid lassos: {table.concat(Get_Lasso_Names(), ", ")}.`
        end,

        Autocomplete = function(Value)
            local NormalizedRaw = Normalize(Value.Raw)
            local Matches = {}

            for _, LassoName in Lassos.Order do
                local LassoData = Lassos.Get(LassoName)

                if not LassoData then
                    continue
                end

                if
                    NormalizedRaw == ""
                    or string.find(Normalize(LassoData.Name), NormalizedRaw, 1, true)
                    or string.find(Normalize(LassoData.DisplayName), NormalizedRaw, 1, true)
                then
                    table.insert(Matches, LassoData.Name)
                end
            end

            return Matches
        end,

        Parse = function(Value)
            return Value.Value
        end,
    })
end
