local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Modules.Events)

return function(Cmdr)
    Cmdr:RegisterType("event", {
        Transform = function(Text: string)
            return {
                Raw = Text,
                Value = Events.Normalize(Text),
            }
        end,

        Validate = function(Value)
            if Value.Value ~= nil then
                return true
            end

            return false, `Unknown event. Use one of: {table.concat(Events.Order, ", ")}.`
        end,

        Autocomplete = function(Value)
            local Raw = string.lower(Value.Raw or "")
            local Matches = {}

            for _, EventName in Events.Order do
                local Info = Events.Get(EventName)
                local DisplayName = if Info then Info.DisplayName else EventName

                if
                    Raw == ""
                    or string.find(string.lower(EventName), Raw, 1, true)
                    or string.find(string.lower(DisplayName), Raw, 1, true)
                then
                    table.insert(Matches, EventName)
                end
            end

            return Matches
        end,

        Parse = function(Value)
            return Value.Value
        end,
    })
end
