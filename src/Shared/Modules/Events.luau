local Events = {}

export type EventName = "YinYang" | "Volcanic" | "Candy" | "Toxic"

export type EventInfo = {
    Name: EventName,
    DisplayName: string,
    Chance: number,
    Image: string,
}

Events.IntervalSeconds = 15 * 60
Events.DurationSeconds = 5 * 60

Events.Order = table.freeze({
    "YinYang",
    "Volcanic",
    "Candy",
    "Toxic",
})

Events.Data = table.freeze({
    YinYang = {
        Name = "YinYang",
        DisplayName = "Yin Yang",
        Chance = 35 / 100,
        Image = "rbxassetid://138317915035795",
    },
    Volcanic = {
        Name = "Volcanic",
        DisplayName = "Volcanic",
        Chance = 28 / 100,
        Image = "rbxassetid://112422836214373",
    },
    Candy = {
        Name = "Candy",
        DisplayName = "Candy",
        Chance = 22 / 100,
        Image = "rbxassetid://127536426524827",
    },
    Toxic = {
        Name = "Toxic",
        DisplayName = "Toxic",
        Chance = 15 / 100,
        Image = "rbxassetid://73251144399969",
    },
})

local AliasMap = table.freeze({
    Yin = "YinYang",
    Yang = "YinYang",
    YinYang = "YinYang",
    Yin_Yang = "YinYang",
    ["Yin Yang"] = "YinYang",
    yinyang = "YinYang",
    volcanic = "Volcanic",
    volcano = "Volcanic",
    candy = "Candy",
    toxic = "Toxic",
})

local DEFAULT_RNG = Random.new()

function Events.Normalize(Name: any): EventName?
    if type(Name) ~= "string" or Name == "" then
        return nil
    end

    local Direct = Events.Data[Name]

    if Direct then
        return Direct.Name
    end

    local Alias = AliasMap[Name] or AliasMap[string.gsub(Name, "%s+", "")]

    if Alias and Events.Data[Alias] then
        return Alias :: EventName
    end

    local Lower = string.lower(string.gsub(Name, "%s+", ""))

    for _, EventName in Events.Order do
        if string.lower(EventName) == Lower or string.lower(Events.Data[EventName].DisplayName) == Lower then
            return EventName :: EventName
        end
    end

    return nil
end

function Events.IsEvent(Name: any): boolean
    return Events.Normalize(Name) ~= nil
end

function Events.Get(Name: any): EventInfo?
    local EventName = Events.Normalize(Name)

    return if EventName then Events.Data[EventName] else nil
end

function Events.GetDisplayName(Name: any): string
    local Info = Events.Get(Name)

    return if Info then Info.DisplayName else tostring(Name or "")
end

function Events.GetImage(Name: any): string
    local Info = Events.Get(Name)

    return if Info then Info.Image else ""
end

function Events.RollNatural(Rng: Random?): EventName
    local RollRng = Rng or DEFAULT_RNG
    local Roll = RollRng:NextNumber()
    local RunningChance = 0

    for _, EventName in Events.Order do
        local Info = Events.Data[EventName]

        RunningChance += math.max(0, Info.Chance)

        if Roll <= RunningChance then
            return EventName :: EventName
        end
    end

    return Events.Order[#Events.Order] :: EventName
end

function Events.GetNextEventAt(Now: number?): number
    local Current = if type(Now) == "number" and Now == Now then Now else workspace:GetServerTimeNow()
    local Interval = Events.IntervalSeconds

    return math.floor(Current / Interval) * Interval + Interval
end

return table.freeze(Events)
