local SquishyLevels = {}

SquishyLevels.MaxLevel = 10
SquishyLevels.LevelXpGrowth = 1.3
SquishyLevels.LevelIncomeMultiplier = 1.07
SquishyLevels.LevelScaleBonus = 0.025

SquishyLevels.RarityXpMultipliers = table.freeze({
    Common = 0.5,
    Rare = 2,
    Epic = 5,
    Legendary = 10,
    Secret = 15,
    Prismatic = 20,
    Exclusive = 20,
    Divine = 30,
    Boss = 30,
    Exotic = 40,
    Transcended = 50,
})

local function Normalize_Number(Value: any, Fallback: number?): number
    if type(Value) ~= "number" or Value ~= Value then
        return Fallback or 0
    end

    return Value
end

function SquishyLevels.NormalizeLevel(Level: any): number
    return math.clamp(math.floor(Normalize_Number(Level, 0)), 0, SquishyLevels.MaxLevel)
end

function SquishyLevels.NormalizeXp(XP: any): number
    return math.max(0, math.floor(Normalize_Number(XP, 0)))
end

function SquishyLevels.GetRarityXpMultiplier(Rarity: any): number
    if type(Rarity) ~= "string" then
        return SquishyLevels.RarityXpMultipliers.Common
    end

    return SquishyLevels.RarityXpMultipliers[Rarity] or SquishyLevels.RarityXpMultipliers.Common
end

function SquishyLevels.GetRequiredXpForLevel(Level: any, Rarity: any): number
    local NormalizedLevel = SquishyLevels.NormalizeLevel(Level)

    if NormalizedLevel >= SquishyLevels.MaxLevel then
        return 0
    end

    return math.max(
        1,
        math.ceil(
            (SquishyLevels.LevelXpGrowth ^ (NormalizedLevel - 1)) * 5 * SquishyLevels.GetRarityXpMultiplier(Rarity)
        )
    )
end

function SquishyLevels.GetIncomeMultiplier(Level: any): number
    return SquishyLevels.LevelIncomeMultiplier ^ SquishyLevels.NormalizeLevel(Level)
end

function SquishyLevels.GetScaleBonus(Level: any): number
    return SquishyLevels.NormalizeLevel(Level) * SquishyLevels.LevelScaleBonus
end

function SquishyLevels.GetProgress(Level: any, XP: any, Rarity: any): number
    local NormalizedLevel = SquishyLevels.NormalizeLevel(Level)

    if NormalizedLevel >= SquishyLevels.MaxLevel then
        return 1
    end

    local Required = SquishyLevels.GetRequiredXpForLevel(NormalizedLevel, Rarity)

    if Required <= 0 then
        return 1
    end

    return math.clamp(SquishyLevels.NormalizeXp(XP) / Required, 0, 1)
end

function SquishyLevels.ApplyXp(Level: any, XP: any, XPGain: any, Rarity: any): (number, number, boolean)
    local NewLevel = SquishyLevels.NormalizeLevel(Level)
    local NewXP = SquishyLevels.NormalizeXp(XP) + SquishyLevels.NormalizeXp(XPGain)
    local DidLevelUp = false

    while NewLevel < SquishyLevels.MaxLevel do
        local Required = SquishyLevels.GetRequiredXpForLevel(NewLevel, Rarity)

        if NewXP < Required then
            break
        end

        NewXP -= Required
        NewLevel += 1
        DidLevelUp = true
    end

    if NewLevel >= SquishyLevels.MaxLevel then
        NewXP = 0
    end

    return NewLevel, NewXP, DidLevelUp
end

return table.freeze(SquishyLevels)
