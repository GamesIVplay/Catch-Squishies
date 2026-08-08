local CatchConfig = {}

CatchConfig.ProgressBarMinimumScale = 0.12
CatchConfig.LockGreenBarScale = 0.4
CatchConfig.LockProgress = math.clamp(
    (CatchConfig.LockGreenBarScale - CatchConfig.ProgressBarMinimumScale) / (1 - CatchConfig.ProgressBarMinimumScale),
    0,
    1
)
CatchConfig.ClickGraceSeconds = 0.35
CatchConfig.MaxClicksPerSecond = 14
CatchConfig.ClickFeedbackCooldownSeconds = 0.18
CatchConfig.MaxStartDistance = 40
CatchConfig.MaxMaintainDistance = 115
CatchConfig.ThrowDistance = 40
CatchConfig.ThrowHitPadding = 3
CatchConfig.ThrowLocalHitStep = 1.5
CatchConfig.ThrowTravelSpeed = 55
CatchConfig.MinThrowDuration = 0.45
CatchConfig.MaxThrowDuration = 2.1
CatchConfig.ThrowCooldownSeconds = 0.65
CatchConfig.ThrowTopPitchDegrees = 0
CatchConfig.ThrowTopYawDegrees = 90
CatchConfig.ThrowTopRollDegrees = 0
CatchConfig.ThrowAutoAimAngleDegrees = 12
CatchConfig.ThrowAutoAimRadius = 6
CatchConfig.CameraAimRightOffset = 3.5
CatchConfig.AimRaycastDistance = 1_000
CatchConfig.ControllerThrowKeyCode = Enum.KeyCode.ButtonR2
CatchConfig.MaxAimOriginDistance = 20
CatchConfig.RopeThickness = 0.12
CatchConfig.RopeExtraLength = 0.1
CatchConfig.IdleTimeoutSeconds = 10
CatchConfig.PullDurationSeconds = 0.3
CatchConfig.CatchPullStopDistance = 4
CatchConfig.CatchPullPositionResponsiveness = 10
CatchConfig.CatchHudTransitionSeconds = 0.16
CatchConfig.CatchMinigameIntroDelaySeconds = 0.16
CatchConfig.CatchMinigameIntroSeconds = 0.2
CatchConfig.CatchCompleteUiHoldSeconds = 0.6
CatchConfig.MinWeight = 8
CatchConfig.MaxWeight = 100
CatchConfig.MaxWeightStrengthBonus = 0.35
CatchConfig.MaxWeightIncomeBonus = 1.5
CatchConfig.MaxTargetStrength = 50_000
CatchConfig.IncomeStrengthFactor = 0.03

local RNG = Random.new()

local RARITY_BASE_STRENGTH = table.freeze({
    Common = 20,
    Rare = 35,
    Epic = 60,
    Legendary = 90,
    Secret = 130,
    Prismatic = 170,
    Divine = 220,
    Exotic = 280,
    Transcended = 350,
})

CatchConfig.RarityBaseStrength = RARITY_BASE_STRENGTH

local RARITY_GREEN_BAR_IMAGES = table.freeze({
    Common = "rbxassetid://96968499777541",
    Rare = "rbxassetid://125544965821042",
    Epic = "rbxassetid://113886592943693",
    Legendary = "rbxassetid://79185874198844",
    Secret = "rbxassetid://136287302810232",
    Prismatic = "rbxassetid://123054333589612",
    Divine = "rbxassetid://124833068599191",
    Exotic = "rbxassetid://101989610479070",
    Transcended = "rbxassetid://135954845046813",
})

CatchConfig.RarityGreenBarImages = RARITY_GREEN_BAR_IMAGES

local RARITY_DISPLAY_IMAGES = table.freeze({
    Common = "rbxassetid://137619176949809",
    Rare = "rbxassetid://78687881513259",
    Epic = "rbxassetid://107436324563653",
    Legendary = "rbxassetid://120100497099438",
    Secret = "rbxassetid://72791581821391",
    Prismatic = "rbxassetid://81785010837786",
    Divine = "rbxassetid://80345944223472",
    Exotic = "rbxassetid://122190752474596",
    Transcended = "rbxassetid://129286205607178",
})

CatchConfig.RarityDisplayImages = RARITY_DISPLAY_IMAGES

CatchConfig.DifficultySettings = table.freeze({
    [1] = table.freeze({
        ChunkDrain = 5,
        DrainInterval = 1.2,
        AutoFailThreshold = 8,
        AutoFailDuration = 4,
        ClicksNeeded = { 10, 14 },
    }),
    [2] = table.freeze({
        ChunkDrain = 5,
        DrainInterval = 1.1,
        AutoFailThreshold = 8.5,
        AutoFailDuration = 3.8,
        ClicksNeeded = { 15, 18 },
    }),
    [3] = table.freeze({
        ChunkDrain = 5,
        DrainInterval = 1,
        AutoFailThreshold = 9,
        AutoFailDuration = 3.6,
        ClicksNeeded = { 20, 24 },
    }),
    [4] = table.freeze({
        ChunkDrain = 5,
        DrainInterval = 0.9,
        AutoFailThreshold = 9.5,
        AutoFailDuration = 3.4,
        ClicksNeeded = { 26, 30 },
    }),
    [5] = table.freeze({
        ChunkDrain = 5,
        DrainInterval = 0.7,
        AutoFailThreshold = 10,
        AutoFailDuration = 3.2,
        ClicksNeeded = { 32, 38 },
    }),
    [6] = table.freeze({
        ChunkDrain = 5,
        DrainInterval = 0.7,
        AutoFailThreshold = 10.5,
        AutoFailDuration = 3,
        ClicksNeeded = { 40, 47 },
    }),
    [7] = table.freeze({
        ChunkDrain = 6,
        DrainInterval = 0.6,
        AutoFailThreshold = 11,
        AutoFailDuration = 2.9,
        ClicksNeeded = { 52, 69 },
    }),
    [8] = table.freeze({
        ChunkDrain = 7,
        DrainInterval = 0.7,
        AutoFailThreshold = 11.5,
        AutoFailDuration = 2.7,
        ClicksNeeded = { 60, 70 },
    }),
    [9] = table.freeze({
        ChunkDrain = 7,
        DrainInterval = 0.65,
        AutoFailThreshold = 11.8,
        AutoFailDuration = 2.6,
        ClicksNeeded = { 70, 82 },
    }),
    [10] = table.freeze({
        ChunkDrain = 8,
        DrainInterval = 0.65,
        AutoFailThreshold = 12,
        AutoFailDuration = 2.5,
        ClicksNeeded = { 78, 90 },
    }),
})

local function Get_Rarity_Base_Strength(Rarity: string?): number
    if type(Rarity) ~= "string" then
        return RARITY_BASE_STRENGTH.Common
    end

    return RARITY_BASE_STRENGTH[Rarity] or RARITY_BASE_STRENGTH.Common
end

function CatchConfig.Get_Rarity_Base_Strength(Rarity: string?): number
    return Get_Rarity_Base_Strength(Rarity)
end

function CatchConfig.Get_Green_Bar_Image(Rarity: string?): string?
    if type(Rarity) ~= "string" then
        return RARITY_GREEN_BAR_IMAGES.Common
    end

    return RARITY_GREEN_BAR_IMAGES[Rarity] or RARITY_GREEN_BAR_IMAGES.Common
end

function CatchConfig.Get_Display_Image(Rarity: string?): string?
    if type(Rarity) ~= "string" then
        return RARITY_DISPLAY_IMAGES.Common
    end

    return RARITY_DISPLAY_IMAGES[Rarity] or RARITY_DISPLAY_IMAGES.Common
end

function CatchConfig.Get_Base_Target_Strength(SquishyData: any): number
    if type(SquishyData) ~= "table" then
        return Get_Rarity_Base_Strength(nil)
    end

    local CustomStrength = SquishyData.CustomStrength

    if type(CustomStrength) == "number" and CustomStrength == CustomStrength then
        return math.clamp(math.floor(CustomStrength + 0.5), 1, CatchConfig.MaxTargetStrength)
    end

    local IncomePerSec = SquishyData.IncomePerSec

    if type(IncomePerSec) ~= "number" or IncomePerSec ~= IncomePerSec then
        IncomePerSec = 0
    end

    local BaseStrength = Get_Rarity_Base_Strength(SquishyData.Rarity)
        + math.floor(math.max(0, IncomePerSec) * CatchConfig.IncomeStrengthFactor + 0.5)

    return math.clamp(BaseStrength, 1, CatchConfig.MaxTargetStrength)
end

function CatchConfig.Get_Target_Strength(SquishyData: any): number
    return CatchConfig.Get_Base_Target_Strength(SquishyData)
end

function CatchConfig.Get_Weight_Alpha(Weight: number?): number
    if type(Weight) ~= "number" or Weight ~= Weight then
        return 0
    end

    return math.clamp(
        (Weight - CatchConfig.MinWeight) / math.max(1, CatchConfig.MaxWeight - CatchConfig.MinWeight),
        0,
        1
    )
end

function CatchConfig.Get_Weight_Strength_Multiplier(Weight: number?): number
    return 1 + CatchConfig.Get_Weight_Alpha(Weight) * CatchConfig.MaxWeightStrengthBonus
end

function CatchConfig.Get_Weight_Income_Multiplier(Weight: number?): number
    return 1 + CatchConfig.Get_Weight_Alpha(Weight) * CatchConfig.MaxWeightIncomeBonus
end

function CatchConfig.Get_Catch_Strength(SquishyData: any, Weight: number?): number
    if type(SquishyData) == "table" then
        local CustomStrength = SquishyData.CustomStrength

        if type(CustomStrength) == "number" and CustomStrength == CustomStrength then
            return math.clamp(math.floor(CustomStrength + 0.5), 1, CatchConfig.MaxTargetStrength)
        end
    end

    local BaseStrength = CatchConfig.Get_Base_Target_Strength(SquishyData)

    return math.clamp(
        math.floor(BaseStrength * CatchConfig.Get_Weight_Strength_Multiplier(Weight) + 0.5),
        1,
        CatchConfig.MaxTargetStrength
    )
end

function CatchConfig.Get_Weighted_Target_Strength(SquishyData: any, Weight: number?): number
    return CatchConfig.Get_Catch_Strength(SquishyData, Weight)
end

function CatchConfig.Get_Weighted_Income_Per_Sec(SquishyData: any, Weight: number?): number
    if type(SquishyData) ~= "table" then
        return 0
    end

    local IncomePerSec = SquishyData.IncomePerSec

    if type(IncomePerSec) ~= "number" or IncomePerSec ~= IncomePerSec then
        return 0
    end

    return math.max(0, math.floor(IncomePerSec * CatchConfig.Get_Weight_Income_Multiplier(Weight) + 0.5))
end

function CatchConfig.Get_Difficulty(TargetStrength: number, LassoStrength: number, _Rarity: string?): number
    local SafeTargetStrength = math.max(1, TargetStrength)
    local SafeLassoStrength = math.max(1, LassoStrength)
    local Ratio = SafeTargetStrength / SafeLassoStrength
    local Difficulty = math.floor(math.sqrt(math.max(0, Ratio - 1)) * 4 + 1 + 0.5)

    return math.clamp(Difficulty, 1, 10)
end

function CatchConfig.Get_Difficulty_Settings(Difficulty: number): any
    local ClampedDifficulty = math.clamp(math.floor(Difficulty + 0.5), 1, 10)

    return CatchConfig.DifficultySettings[ClampedDifficulty] or CatchConfig.DifficultySettings[1]
end

function CatchConfig.Get_Clicks_Needed(Difficulty: number): number
    local Settings = CatchConfig.Get_Difficulty_Settings(Difficulty)
    local Range = Settings.ClicksNeeded
    local Minimum = math.max(1, math.floor(Range[1] + 0.5))
    local Maximum = math.max(Minimum, math.floor(Range[2] + 0.5))

    return RNG:NextInteger(Minimum, Maximum)
end

function CatchConfig.Get_Click_Gain(ClicksNeeded: number): number
    return 1 / math.max(1, ClicksNeeded)
end

function CatchConfig.Get_Progress_Bar_Scale(Progress: number): number
    local ClampedProgress = math.clamp(Progress, 0, 1)

    return CatchConfig.ProgressBarMinimumScale + ClampedProgress * (1 - CatchConfig.ProgressBarMinimumScale)
end

function CatchConfig.Get_Drain_Chunk(Difficulty: number): number
    return CatchConfig.Get_Difficulty_Settings(Difficulty).ChunkDrain / 100
end

function CatchConfig.Get_Drain_Interval(Difficulty: number): number
    return CatchConfig.Get_Difficulty_Settings(Difficulty).DrainInterval
end

function CatchConfig.Get_Depletion_Tween_Time(Difficulty: number): number
    return CatchConfig.Get_Drain_Interval(Difficulty) * 0.7
end

function CatchConfig.Get_Auto_Fail_Threshold(Difficulty: number): number
    return CatchConfig.Get_Difficulty_Settings(Difficulty).AutoFailThreshold / 100
end

function CatchConfig.Get_Auto_Fail_Duration(Difficulty: number): number
    return CatchConfig.Get_Difficulty_Settings(Difficulty).AutoFailDuration
end

return table.freeze(CatchConfig)
