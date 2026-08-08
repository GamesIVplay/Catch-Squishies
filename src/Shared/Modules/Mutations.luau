export type SquishyKind = "Slime" | "Dumpling"

export type MutationInfo = {
    Chance: number,
    IncomeMultiplier: number,
}

type MutationConfig = {
    Order: { string },
    Data: { [string]: MutationInfo },
}

local NORMAL_MUTATION = "Normal"
local DEFAULT_RNG = Random.new()

local CONFIG: { [SquishyKind]: MutationConfig } = {
    Slime = {
        Order = { "Ruby", "Gold", "Diamond", "Emerald", "Inverted" },
        Data = {
            Normal = {
                Chance = 0,
                IncomeMultiplier = 1,
            },
            Ruby = {
                Chance = 10,
                IncomeMultiplier = 1.25,
            },
            Gold = {
                Chance = 6,
                IncomeMultiplier = 1.5,
            },
            Diamond = {
                Chance = 3,
                IncomeMultiplier = 2,
            },
            Emerald = {
                Chance = 1.25,
                IncomeMultiplier = 3,
            },
            Inverted = {
                Chance = 0.5,
                IncomeMultiplier = 4,
            },
        },
    },
    Dumpling = {
        Order = { "Gold", "Diamond", "Toxic", "Void" },
        Data = {
            Normal = {
                Chance = 0,
                IncomeMultiplier = 1,
            },
            Gold = {
                Chance = 8,
                IncomeMultiplier = 1.5,
            },
            Diamond = {
                Chance = 4,
                IncomeMultiplier = 2,
            },
            Toxic = {
                Chance = 1.5,
                IncomeMultiplier = 3,
            },
            Void = {
                Chance = 0.5,
                IncomeMultiplier = 4,
            },
        },
    },
}

local MUTATION_ALIASES = table.freeze({
    None = NORMAL_MUTATION,
    Shiny = NORMAL_MUTATION,
    Golden = "Gold",
    Rainbow = NORMAL_MUTATION,
})

local Mutations = {}

Mutations.Normal = NORMAL_MUTATION
Mutations.Config = CONFIG

local function Get_Kind_Config(Kind: any): MutationConfig?
    if Kind == "Slime" or Kind == "Dumpling" then
        return CONFIG[Kind]
    end

    return nil
end

local function Normalize_Mutation_Name(Mutation: any): string
    if type(Mutation) ~= "string" or Mutation == "" then
        return NORMAL_MUTATION
    end

    return MUTATION_ALIASES[Mutation] or Mutation
end

local function Is_Config_Mutation(Config: MutationConfig, Mutation: string): boolean
    return Config.Data[Mutation] ~= nil
end

function Mutations.Normalize(Kind: any, Mutation: any): string
    local MutationName = Normalize_Mutation_Name(Mutation)

    if MutationName == NORMAL_MUTATION then
        return NORMAL_MUTATION
    end

    local Config = Get_Kind_Config(Kind)

    if Config then
        return if Is_Config_Mutation(Config, MutationName) then MutationName else NORMAL_MUTATION
    end

    for _, KindConfig in CONFIG do
        if Is_Config_Mutation(KindConfig, MutationName) then
            return MutationName
        end
    end

    return NORMAL_MUTATION
end

function Mutations.IsMutated(Kind: any, Mutation: any): boolean
    return Mutations.Normalize(Kind, Mutation) ~= NORMAL_MUTATION
end

function Mutations.GetInfo(Kind: any, Mutation: any): MutationInfo
    local MutationName = Mutations.Normalize(Kind, Mutation)
    local Config = Get_Kind_Config(Kind)

    if Config and Config.Data[MutationName] then
        return Config.Data[MutationName]
    end

    for _, KindConfig in CONFIG do
        local Info = KindConfig.Data[MutationName]

        if Info then
            return Info
        end
    end

    return CONFIG.Slime.Data[NORMAL_MUTATION]
end

function Mutations.GetIncomeMultiplier(Kind: any, Mutation: any): number
    return Mutations.GetInfo(Kind, Mutation).IncomeMultiplier
end

function Mutations.GetChance(Kind: any, Mutation: any): number
    return Mutations.GetInfo(Kind, Mutation).Chance
end

function Mutations.GetRank(Kind: any, Mutation: any): number
    local MutationName = Mutations.Normalize(Kind, Mutation)

    if MutationName == NORMAL_MUTATION then
        return 1
    end

    local Config = Get_Kind_Config(Kind)

    if Config then
        for Rank, EntryName in Config.Order do
            if EntryName == MutationName then
                return Rank + 1
            end
        end
    else
        for _, KindConfig in CONFIG do
            for Rank, EntryName in KindConfig.Order do
                if EntryName == MutationName then
                    return Rank + 1
                end
            end
        end
    end

    return 1
end

function Mutations.GetDisplayPrefix(Kind: any, Mutation: any): string
    local MutationName = Mutations.Normalize(Kind, Mutation)

    return if MutationName == NORMAL_MUTATION then "" else MutationName
end

function Mutations.FormatDisplayName(Kind: any, Name: any, Mutation: any): string
    local SquishyName = if type(Name) == "string" and Name ~= "" then Name else "Squishy"
    local KindName = if type(Kind) == "string" and Kind ~= "" then Kind else ""
    local BaseName = if KindName ~= ""
            and not string.find(string.lower(SquishyName), string.lower(KindName), 1, true)
        then `{SquishyName} {KindName}`
        else SquishyName
    local Prefix = Mutations.GetDisplayPrefix(Kind, Mutation)

    return if Prefix ~= "" then `{Prefix} {BaseName}` else BaseName
end

function Mutations.Roll(Kind: any, Rng: Random?): string
    local Config = Get_Kind_Config(Kind)

    if not Config then
        return NORMAL_MUTATION
    end

    local RollRng = Rng or DEFAULT_RNG
    local Roll = RollRng:NextNumber() * 100
    local RunningChance = 0

    for _, MutationName in Config.Order do
        local Info = Config.Data[MutationName]

        if not Info then
            continue
        end

        RunningChance += math.max(0, Info.Chance)

        if Roll < RunningChance then
            return MutationName
        end
    end

    return NORMAL_MUTATION
end

return table.freeze(Mutations)
