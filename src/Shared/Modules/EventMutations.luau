local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Modules.Events)

local EventMutations = {}

export type EventMutationInfo = {
    Name: string,
    Chance: number,
    IncomeMultiplier: number,
    Image: string,
}

EventMutations.Data = table.freeze({
    YinYang = {
        Name = "YinYang",
        Chance = 15 / 100,
        IncomeMultiplier = 1.15,
        Image = "rbxassetid://138317915035795",
    },
    Volcanic = {
        Name = "Volcanic",
        Chance = 11 / 100,
        IncomeMultiplier = 1.25,
        Image = "rbxassetid://112422836214373",
    },
    Candy = {
        Name = "Candy",
        Chance = 7.5 / 100,
        IncomeMultiplier = 1.4,
        Image = "rbxassetid://127536426524827",
    },
    Toxic = {
        Name = "Toxic",
        Chance = 4 / 100,
        IncomeMultiplier = 1.75,
        Image = "rbxassetid://73251144399969",
    },
})

local ORDER_RANK = {}

for Rank, EventName in Events.Order do
    ORDER_RANK[EventName] = Rank
end

local function Add_Normalized(Result: { string }, Seen: { [string]: boolean }, Name: any)
    local EventName = Events.Normalize(Name)

    if not EventName or Seen[EventName] or not EventMutations.Data[EventName] then
        return
    end

    Seen[EventName] = true
    table.insert(Result, EventName)
end

function EventMutations.NormalizeList(Value: any): { string }
    local Result = {}
    local Seen = {}

    if type(Value) == "string" then
        for Entry in string.gmatch(Value, "[^,]+") do
            Add_Normalized(Result, Seen, string.gsub(Entry, "^%s*(.-)%s*$", "%1"))
        end
    elseif type(Value) == "table" then
        for _, Entry in Value do
            Add_Normalized(Result, Seen, Entry)
        end
    end

    table.sort(Result, function(Left, Right)
        return (ORDER_RANK[Left] or math.huge) < (ORDER_RANK[Right] or math.huge)
    end)

    return Result
end

function EventMutations.EncodeAttribute(Value: any): string
    return table.concat(EventMutations.NormalizeList(Value), ",")
end

function EventMutations.DecodeAttribute(Value: any): { string }
    return EventMutations.NormalizeList(Value)
end

function EventMutations.Has(Value: any, Name: any): boolean
    local EventName = Events.Normalize(Name)

    if not EventName then
        return false
    end

    for _, Existing in EventMutations.NormalizeList(Value) do
        if Existing == EventName then
            return true
        end
    end

    return false
end

function EventMutations.Add(Value: any, Name: any): ({ string }, boolean)
    local Result = EventMutations.NormalizeList(Value)
    local EventName = Events.Normalize(Name)

    if not EventName or EventMutations.Has(Result, EventName) then
        return Result, false
    end

    table.insert(Result, EventName)

    return EventMutations.NormalizeList(Result), true
end

function EventMutations.GetIncomeMultiplier(Value: any): number
    local Multiplier = 1

    for _, EventName in EventMutations.NormalizeList(Value) do
        local Info = EventMutations.Data[EventName]

        if Info and type(Info.IncomeMultiplier) == "number" then
            Multiplier *= Info.IncomeMultiplier
        end
    end

    return Multiplier
end

function EventMutations.RollForEvent(EventName: any, Rng: Random?): boolean
    local NormalizedEventName = Events.Normalize(EventName)
    local Info = NormalizedEventName and EventMutations.Data[NormalizedEventName]

    if not Info then
        return false
    end

    return (Rng or Random.new()):NextNumber() <= math.max(0, Info.Chance)
end

function EventMutations.RollForActiveEvents(ActiveEvents: any, Rng: Random?, Existing: any?): ({ string }, { string })
    local Result = EventMutations.NormalizeList(Existing)
    local Added = {}
    local RollRng = Rng or Random.new()

    if type(ActiveEvents) ~= "table" then
        return Result, Added
    end

    local function Try_Roll(EventName: any)
        local NormalizedEventName = Events.Normalize(EventName)

        if not NormalizedEventName or EventMutations.Has(Result, NormalizedEventName) then
            return
        end

        if EventMutations.RollForEvent(NormalizedEventName, RollRng) then
            local Updated = EventMutations.Add(Result, NormalizedEventName)
            Result = Updated
            table.insert(Added, NormalizedEventName)
        end
    end

    for Key, Entry in ActiveEvents do
        if type(Entry) == "table" then
            Try_Roll(Entry.Name or Key)
        else
            Try_Roll(Key)
        end
    end

    return Result, Added
end

return table.freeze(EventMutations)
