local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)

local function Normalize(Text: string): string
    return string.lower((string.gsub(Text, "%s+", "")))
end

local function Get_Display_Key(Entry): string
    return `{Entry.Kind}:{Entry.Name}`
end

local function Resolve_Squishy(Text: string): (string?, { string }?)
    local NormalizedText = Normalize(Text)

    if NormalizedText == "" then
        return nil, nil
    end

    local PlainNameMatches = {}

    for _, Entry in Squishies.GetIndexEntries() do
        local Key = Get_Display_Key(Entry)

        if NormalizedText == Normalize(Key) then
            return Key, nil
        end

        if NormalizedText == Normalize(Entry.Name) then
            table.insert(PlainNameMatches, Key)
        end
    end

    if #PlainNameMatches == 1 then
        return PlainNameMatches[1], nil
    end

    if #PlainNameMatches > 1 then
        return nil, PlainNameMatches
    end

    return nil, nil
end

return function(Cmdr)
    Cmdr:RegisterType("squishy", {
        Transform = function(Text: string)
            local Value, AmbiguousMatches = Resolve_Squishy(Text)

            return {
                Raw = Text,
                Value = Value,
                AmbiguousMatches = AmbiguousMatches,
            }
        end,

        Validate = function(Value)
            if Value.Value ~= nil then
                return true
            end

            if Value.AmbiguousMatches then
                return false, `Ambiguous squishy. Use one of: {table.concat(Value.AmbiguousMatches, ", ")}.`
            end

            return false, `Unknown squishy. Run getSquishies for valid names.`
        end,

        Autocomplete = function(Value)
            local NormalizedRaw = Normalize(Value.Raw)
            local Matches = {}

            for _, Entry in Squishies.GetIndexEntries() do
                local Key = Get_Display_Key(Entry)

                if
                    NormalizedRaw == ""
                    or string.find(Normalize(Key), NormalizedRaw, 1, true)
                    or string.find(Normalize(Entry.Name), NormalizedRaw, 1, true)
                    or string.find(Normalize(Entry.Rarity), NormalizedRaw, 1, true)
                then
                    table.insert(Matches, Key)
                end
            end

            return Matches
        end,

        Parse = function(Value)
            return Value.Value
        end,
    })
end
