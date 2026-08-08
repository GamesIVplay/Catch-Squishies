local Dumplings = require(script.Parent.Dumplings)
local Mutations = require(script.Parent.Mutations)
local Slimes = require(script.Parent.Slimes)

type SquishyKind = "Slime" | "Dumpling"

type Squishy = {
    Rarity: string,
    IncomePerSec: number,
    CustomStrength: number?,
    Image: string,
}

type SquishyEntry = {
    Kind: SquishyKind,
    Name: string,
}

type SquishyIndexEntry = {
    Key: string,
    Kind: SquishyKind,
    Name: string,
    Rarity: string,
    IncomePerSec: number,
    Image: string,
}

type WeightedRarity = {
    Rarity: string,
    Weight: number,
}

type RollResult = {
    Kind: SquishyKind,
    Name: string,
}

type RollSquishyFunction = (Luck: number?) -> RollResult?
type GetDataFunction = (Kind: SquishyKind, Squishy_Name: string) -> Squishy?
type GetDataFromKeyFunction = (Key: string) -> (Squishy?, SquishyKind?, string?)
type GetModelFunction = (Kind: SquishyKind, Squishy_Name: string, Mutation: string?) -> Model?
type GetIndexEntriesFunction = () -> { SquishyIndexEntry }

type SquishiesModule = {
    Slimes: typeof(Slimes),
    Dumplings: typeof(Dumplings),
    RarityOrder: { string },
    RarityWeights: { [string]: number },
    Roll_Squishy: RollSquishyFunction,
    GetData: GetDataFunction,
    GetDataFromKey: GetDataFromKeyFunction,
    GetModel: GetModelFunction,
    GetKey: (Kind: SquishyKind, Squishy_Name: string) -> string,
    ParseKey: (Key: string) -> (SquishyKind?, string?),
    GetDisplayName: (Kind: SquishyKind, Squishy_Name: string, Mutation: string?) -> string,
    GetIndexEntries: GetIndexEntriesFunction,
}

local RNG = Random.new()
local LUCK_ROLL_EFFECT_STRENGTH = 0.7
local RARITY_ORDER = {
    "Common",
    "Rare",
    "Epic",
    "Legendary",
    "Secret",
    "Prismatic",
    "Divine",
    "Exotic",
    "Transcended",
}
local RARITY_WEIGHTS = {
    Common = 55.7,
    Rare = 22,
    Epic = 11,
    Legendary = 5.5,
    Secret = 2.5,
    Prismatic = 1.3,
    Divine = 0.8,
    Exotic = 0.7,
    Transcended = 0.5,
}

local function Get_Source(Kind: SquishyKind): { [string]: any }
    if Kind == "Slime" then
        return Slimes
    end

    return Dumplings
end

local function Get_Rarity_Rank(Rarity: string): number
    for Rank, RarityName in RARITY_ORDER do
        if RarityName == Rarity then
            return Rank
        end
    end

    return math.huge
end

local function GetKey(Kind: SquishyKind, Squishy_Name: string): string
    return `{Kind}:{Squishy_Name}`
end

local function ParseKey(Key: string): (SquishyKind?, string?)
    if type(Key) ~= "string" then
        return nil, nil
    end

    local Kind, Squishy_Name = Key:match("^([^:]+):(.+)$")

    if (Kind ~= "Slime" and Kind ~= "Dumpling") or type(Squishy_Name) ~= "string" or Squishy_Name == "" then
        return nil, nil
    end

    return Kind :: SquishyKind, Squishy_Name
end

local GetData: GetDataFunction = function(Kind: SquishyKind, Squishy_Name: string): Squishy?
    local Source = Get_Source(Kind)
    local Squishy_Data = Source[Squishy_Name]

    if type(Squishy_Data) == "table" then
        return Squishy_Data :: Squishy
    end

    return nil
end

local GetDataFromKey: GetDataFromKeyFunction = function(Key: string): (Squishy?, SquishyKind?, string?)
    local Kind, Squishy_Name = ParseKey(Key)

    if not Kind or not Squishy_Name then
        return nil, nil, nil
    end

    return GetData(Kind, Squishy_Name), Kind, Squishy_Name
end

local GetModel: GetModelFunction = function(Kind: SquishyKind, Squishy_Name: string, Mutation: string?): Model?
    if Kind == "Slime" then
        return Slimes.GetModel(Squishy_Name, Mutation)
    end

    return Dumplings.GetModel(Squishy_Name, Mutation)
end

local function GetDisplayName(Kind: SquishyKind, Squishy_Name: string, Mutation: string?): string
    return Mutations.FormatDisplayName(Kind, Squishy_Name, Mutation)
end

local function Add_Index_Entries(Kind: SquishyKind, Source: { [string]: any }, Entries: { SquishyIndexEntry })
    for Squishy_Name, Source_Data in Source do
        if type(Source_Data) ~= "table" then
            continue
        end

        local Squishy_Data = Source_Data :: Squishy

        table.insert(Entries, {
            Key = GetKey(Kind, Squishy_Name),
            Kind = Kind,
            Name = Squishy_Name,
            Rarity = Squishy_Data.Rarity,
            IncomePerSec = Squishy_Data.IncomePerSec,
            Image = Squishy_Data.Image,
        })
    end
end

local function GetIndexEntries(): { SquishyIndexEntry }
    local Entries: { SquishyIndexEntry } = {}

    Add_Index_Entries("Slime", Slimes, Entries)
    Add_Index_Entries("Dumpling", Dumplings, Entries)

    table.sort(Entries, function(Left, Right)
        local LeftRarityRank = Get_Rarity_Rank(Left.Rarity)
        local RightRarityRank = Get_Rarity_Rank(Right.Rarity)

        if LeftRarityRank ~= RightRarityRank then
            return LeftRarityRank < RightRarityRank
        end

        if Left.IncomePerSec ~= Right.IncomePerSec then
            return Left.IncomePerSec < Right.IncomePerSec
        end

        if Left.Kind ~= Right.Kind then
            return Left.Kind < Right.Kind
        end

        return Left.Name < Right.Name
    end)

    return Entries
end

local function Add_Rarity_Entries(
    Kind: SquishyKind,
    Source: { [string]: any },
    Rarity: string,
    Entries: { SquishyEntry }
)
    for Squishy_Name, Source_Data in Source do
        if type(Source_Data) ~= "table" then
            continue
        end

        local Squishy_Data = Source_Data :: Squishy

        if Squishy_Data.Rarity == Rarity then
            table.insert(Entries, {
                Kind = Kind,
                Name = Squishy_Name,
            })
        end
    end
end

local function Get_Rarity_Entries(Rarity: string): { SquishyEntry }
    local Entries: { SquishyEntry } = {}

    Add_Rarity_Entries("Slime", Slimes, Rarity, Entries)
    Add_Rarity_Entries("Dumpling", Dumplings, Rarity, Entries)

    return Entries
end

local function Roll_Rarity(Luck: number?): string?
    local Luck_Multiplier = math.max(Luck or 1, 0.01)
    local Luck_Exponent = 1 + ((1 / Luck_Multiplier) - 1) * LUCK_ROLL_EFFECT_STRENGTH
    local Total_Weight = 0
    local Weighted_Rarities: { WeightedRarity } = {}

    for _, Rarity in RARITY_ORDER do
        local Weight = RARITY_WEIGHTS[Rarity]

        if Weight and Weight > 0 then
            local Adjusted_Weight = Weight ^ Luck_Exponent

            Total_Weight += Adjusted_Weight
            table.insert(Weighted_Rarities, {
                Rarity = Rarity,
                Weight = Adjusted_Weight,
            })
        end
    end

    if Total_Weight <= 0 then
        return nil
    end

    local Roll = RNG:NextNumber(0, Total_Weight)
    local Running_Weight = 0

    for _, Entry in Weighted_Rarities do
        Running_Weight += Entry.Weight

        if Roll <= Running_Weight then
            return Entry.Rarity
        end
    end

    local Fallback_Entry = Weighted_Rarities[#Weighted_Rarities]

    if not Fallback_Entry then
        return nil
    end

    return Fallback_Entry.Rarity
end

local Roll_Squishy: RollSquishyFunction = function(Luck: number?): RollResult?
    local Rarity = Roll_Rarity(Luck)

    if not Rarity then
        return nil
    end

    local Entries = Get_Rarity_Entries(Rarity)

    if #Entries <= 0 then
        return nil
    end

    local Entry = Entries[RNG:NextInteger(1, #Entries)]

    if not Entry then
        return nil
    end

    return {
        Kind = Entry.Kind,
        Name = Entry.Name,
    }
end

return table.freeze({
    Slimes = Slimes,
    Dumplings = Dumplings,
    RarityOrder = table.freeze(table.clone(RARITY_ORDER)),
    RarityWeights = RARITY_WEIGHTS,
    Roll_Squishy = Roll_Squishy,
    GetData = GetData,
    GetDataFromKey = GetDataFromKey,
    GetModel = GetModel,
    GetKey = GetKey,
    ParseKey = ParseKey,
    GetDisplayName = GetDisplayName,
    GetIndexEntries = GetIndexEntries,
} :: SquishiesModule)
