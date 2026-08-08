local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatchConfig = require(ReplicatedStorage.Shared.Modules.CatchConfig)
local EventMutations = require(ReplicatedStorage.Shared.Modules.EventMutations)
local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local Mutations = require(ReplicatedStorage.Shared.Modules.Mutations)
local SquishyLevels = require(ReplicatedStorage.Shared.Modules.SquishyLevels)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local InventoryMath = {}

InventoryMath.RarityOrder = table.freeze({
    Common = 1,
    Rare = 2,
    Epic = 3,
    Legendary = 4,
    Secret = 5,
    Prismatic = 6,
    Divine = 7,
    Exotic = 8,
    Transcended = 9,
})

local function To_Number(Value: any, Fallback: number?): number
    if type(Value) ~= "number" or Value ~= Value then
        return Fallback or 0
    end

    return Value
end

function InventoryMath.NormalizeRarity(Rarity: any): string
    if Rarity == "Transcendent" then
        return "Transcended"
    end

    if type(Rarity) ~= "string" or Rarity == "" then
        return "Common"
    end

    return Rarity
end

function InventoryMath.GetRarityRank(Rarity: any): number
    return InventoryMath.RarityOrder[InventoryMath.NormalizeRarity(Rarity)] or 0
end

function InventoryMath.NormalizeMutation(Mutation: any, Kind: any?): string
    return Mutations.Normalize(Kind, Mutation)
end

function InventoryMath.GetMutationRank(Mutation: any, Kind: any?): number
    return Mutations.GetRank(Kind, Mutation)
end

function InventoryMath.GetMutationIncomeMultiplier(Mutation: any, Kind: any?): number
    return Mutations.GetIncomeMultiplier(Kind, Mutation)
end

function InventoryMath.NormalizeEventMutations(EventMutationList: any): { string }
    return EventMutations.NormalizeList(EventMutationList)
end

function InventoryMath.GetEventMutationIncomeMultiplier(EventMutationList: any): number
    return EventMutations.GetIncomeMultiplier(EventMutationList)
end

function InventoryMath.RollMutation(Kind: any, Rng: Random?): string
    return Mutations.Roll(Kind, Rng)
end

function InventoryMath.FormatSquishyDisplayName(Kind: any, Name: any, Mutation: any): string
    return Mutations.FormatDisplayName(Kind, Name, Mutation)
end

function InventoryMath.GetSizeIncomeMultiplier(_Item: any): number
    return 1
end

function InventoryMath.GetWeightIncomeMultiplier(Weight: any): number
    return CatchConfig.Get_Weight_Income_Multiplier(To_Number(Weight, CatchConfig.MinWeight))
end

function InventoryMath.GetLevelIncomeMultiplier(Level: any): number
    return SquishyLevels.GetIncomeMultiplier(Level)
end

function InventoryMath.GetFinalIncomePerSec(Item: any): number
    if type(Item) ~= "table" then
        return 0
    end

    if type(Item.BaseIncomePerSec) ~= "number" then
        local ExistingFinal = To_Number(Item.FinalIncomePerSec, To_Number(Item.IncomePerSec, 0))

        return math.max(0, math.floor(ExistingFinal + 0.5))
    end

    local BaseIncomePerSec = math.max(0, Item.BaseIncomePerSec)
    local FinalIncome = BaseIncomePerSec
        * InventoryMath.GetSizeIncomeMultiplier(Item)
        * InventoryMath.GetMutationIncomeMultiplier(Item.Mutation, Item.Kind)
        * InventoryMath.GetEventMutationIncomeMultiplier(Item.EventMutations)
        * InventoryMath.GetWeightIncomeMultiplier(Item.Weight)
        * InventoryMath.GetLevelIncomeMultiplier(Item.Level)

    return math.max(0, math.floor(FinalIncome + 0.5))
end

function InventoryMath.FormatIncome(Value: any): string
    local Income = math.max(0, math.floor(To_Number(Value, 0) + 0.5))

    return "$" .. Util.Abbreviate_Number(Income, 1) .. "/s"
end

function InventoryMath.FormatWeightKg(Weight: any): string
    local NumericWeight = To_Number(Weight, 0)
    local RoundedWeight = math.floor(math.max(0, NumericWeight) * 10 + 0.5) / 10

    return `{Util.Abbreviate_Number(RoundedWeight, 1)}kg`
end

function InventoryMath.GetFoodXP(FoodName: any): number
    return Foods.Get_XP(FoodName)
end

function InventoryMath.FormatFoodXP(XPValue: any): string
    return `{Util.Abbreviate_Number(math.max(0, math.floor(To_Number(XPValue, 0) + 0.5)), 1)} XP`
end

function InventoryMath.FormatCount(Count: any): string
    return Util.Abbreviate_Number(math.max(0, math.floor(To_Number(Count, 0) + 0.5)), 1)
end

return table.freeze(InventoryMath)
