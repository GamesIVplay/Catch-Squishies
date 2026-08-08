local MUTATION_NAMES = table.freeze({
    "Random",
    "Normal",
    "Ruby",
    "Gold",
    "Diamond",
    "Emerald",
    "Inverted",
    "Toxic",
    "Void",
})

local function Normalize(Text: string): string
    return string.lower(string.gsub(Text, "%s+", ""))
end

return function(Cmdr)
    Cmdr:RegisterType("primaryMutation", {
        Transform = function(Text: string)
            local NormalizedText = Normalize(Text)

            for _, MutationName in MUTATION_NAMES do
                if Normalize(MutationName) == NormalizedText then
                    return {
                        Raw = Text,
                        Value = MutationName,
                    }
                end
            end

            return {
                Raw = Text,
                Value = nil,
            }
        end,

        Validate = function(Value)
            if Value.Value ~= nil then
                return true
            end

            return false, `Unknown primary mutation. Use one of: {table.concat(MUTATION_NAMES, ", ")}.`
        end,

        Autocomplete = function(Value)
            local Raw = Normalize(Value.Raw or "")
            local Matches = {}

            for _, MutationName in MUTATION_NAMES do
                if Raw == "" or string.find(Normalize(MutationName), Raw, 1, true) then
                    table.insert(Matches, MutationName)
                end
            end

            return Matches
        end,

        Parse = function(Value)
            return Value.Value
        end,
    })
end
