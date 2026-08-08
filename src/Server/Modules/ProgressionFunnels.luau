local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(ReplicatedStorage.Shared.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local DailyRewards = require(ReplicatedStorage.Shared.Modules.DailyRewards)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local Log = require(ReplicatedStorage.Shared.Log)
local PlaytimeRewards = require(ReplicatedStorage.Shared.Modules.PlaytimeRewards)
local World = require(ReplicatedStorage.Shared.World)

local ProgressionFunnels = {}

local LoggedStepsByEntity: { [number]: { [string]: { [number]: boolean } } } = {}
local LASSO_FUNNEL_NAME = Config.LassoProgressionFunnelName or "LassoProgressionV1"
local DAILY_REWARDS_FUNNEL_NAME = Config.DailyRewardsFunnelName or "DailyRewardsV1"
local PLAYTIME_REWARDS_FUNNEL_NAME = Config.PlaytimeRewardsFunnelName or "PlaytimeRewardsV1"
local PLOT_UPGRADE_FUNNEL_NAME = Config.PlotUpgradeFunnelName or "PlotUpgradesV1"
local VOID_LASSO_NAME = "Void"
local PLOT_AREA_KEYS = table.freeze({
    "LeftFront",
    "RightFront",
    "CenterBack",
    "LeftBack",
    "RightBack",
})

local LASSO_FUNNEL_STEPS = {}

for _, LassoName in Lassos.Order do
    if LassoName ~= VOID_LASSO_NAME then
        local LassoData = Lassos.Get(LassoName)

        if LassoData then
            table.insert(LASSO_FUNNEL_STEPS, {
                Name = LassoData.Name,
                StepName = LassoData.DisplayName,
            })
        end
    end
end

local function Get_Player(PlayerEntity: number): Player?
    local Player = World:get(PlayerEntity, Components.Player)

    return if typeof(Player) == "Instance" and Player:IsA("Player") then Player else nil
end

local function Get_Funnel_Logs(PlayerEntity: number, FunnelName: string): { [number]: boolean }
    local EntityLogs = LoggedStepsByEntity[PlayerEntity]

    if not EntityLogs then
        EntityLogs = {}
        LoggedStepsByEntity[PlayerEntity] = EntityLogs
    end

    local FunnelLogs = EntityLogs[FunnelName]

    if not FunnelLogs then
        FunnelLogs = {}
        EntityLogs[FunnelName] = FunnelLogs
    end

    return FunnelLogs
end

local function Log_Funnel_Step(PlayerEntity: number, FunnelName: string, Step: number, StepName: string)
    Step = math.floor(tonumber(Step) or 0)

    if Step <= 0 or FunnelName == "" or StepName == "" then
        return
    end

    local Player = Get_Player(PlayerEntity)

    if not Player then
        return
    end

    local FunnelLogs = Get_Funnel_Logs(PlayerEntity, FunnelName)

    if FunnelLogs[Step] then
        return
    end

    FunnelLogs[Step] = true

    Log.Info(`Fired {FunnelName} step {Step}: {StepName} for {Player.Name} ({Player.UserId})`)

    task.spawn(function()
        pcall(function()
            AnalyticsService:LogFunnelStepEvent(Player, FunnelName, nil, Step, StepName)
        end)
    end)
end

local function Build_Lasso_Set(OwnedLassos: any): { [string]: boolean }
    local OwnedSet = {}

    if type(OwnedLassos) ~= "table" then
        return OwnedSet
    end

    for _, LassoName in OwnedLassos do
        if type(LassoName) == "string" then
            OwnedSet[LassoName] = true
        end
    end

    return OwnedSet
end

local function Build_Claimed_Set(ClaimedRewards: any): { [number]: boolean }
    local ClaimedSet = {}

    if type(ClaimedRewards) ~= "table" then
        return ClaimedSet
    end

    for _, RewardIndex in ClaimedRewards do
        if type(RewardIndex) == "number" then
            ClaimedSet[math.floor(RewardIndex)] = true
        end
    end

    return ClaimedSet
end

function ProgressionFunnels.Log_Lassos(PlayerEntity: number, OwnedLassos: any?)
    if not World:contains(PlayerEntity) then
        return
    end

    local OwnedSet = Build_Lasso_Set(OwnedLassos or World:get(PlayerEntity, Components.OwnedLassos))
    local HighestOwnedStep = 0

    for Step, StepData in LASSO_FUNNEL_STEPS do
        if OwnedSet[StepData.Name] then
            HighestOwnedStep = math.max(HighestOwnedStep, Step)
        end
    end

    for Step = 1, HighestOwnedStep do
        local StepData = LASSO_FUNNEL_STEPS[Step]

        if StepData then
            Log_Funnel_Step(PlayerEntity, LASSO_FUNNEL_NAME, Step, StepData.StepName)
        end
    end
end

function ProgressionFunnels.Log_Daily_Rewards(PlayerEntity: number, ClaimedRewards: any?)
    if not World:contains(PlayerEntity) then
        return
    end

    local ClaimedSet = Build_Claimed_Set(ClaimedRewards or World:get(PlayerEntity, Components.ClaimedDailyRewards))
    local HighestClaimedStep = 0

    for RewardIndex = 1, #DailyRewards do
        if ClaimedSet[RewardIndex] then
            HighestClaimedStep = RewardIndex
        else
            break
        end
    end

    for Step = 1, HighestClaimedStep do
        Log_Funnel_Step(PlayerEntity, DAILY_REWARDS_FUNNEL_NAME, Step, `Daily Reward {Step}`)
    end
end

function ProgressionFunnels.Log_Daily_Reward(PlayerEntity: number, RewardIndex: number)
    RewardIndex = math.clamp(math.floor(tonumber(RewardIndex) or 0), 0, #DailyRewards)

    for Step = 1, RewardIndex do
        Log_Funnel_Step(PlayerEntity, DAILY_REWARDS_FUNNEL_NAME, Step, `Daily Reward {Step}`)
    end
end

function ProgressionFunnels.Log_Playtime_Reward(PlayerEntity: number, RewardIndex: number)
    RewardIndex = math.clamp(math.floor(tonumber(RewardIndex) or 0), 0, #PlaytimeRewards)

    for Step = 1, RewardIndex do
        Log_Funnel_Step(PlayerEntity, PLAYTIME_REWARDS_FUNNEL_NAME, Step, `Playtime Reward {Step}`)
    end
end

function ProgressionFunnels.Log_Plot_Areas(PlayerEntity: number, PlotAreas: any?)
    if not World:contains(PlayerEntity) then
        return
    end

    PlotAreas = if type(PlotAreas) == "table" then PlotAreas else World:get(PlayerEntity, Components.PlotAreas)

    if type(PlotAreas) ~= "table" then
        return
    end

    local UnlockedCount = 0

    for _, AreaName in PLOT_AREA_KEYS do
        if PlotAreas[AreaName] == true then
            UnlockedCount += 1
        end
    end

    for Step = 1, UnlockedCount do
        Log_Funnel_Step(PlayerEntity, PLOT_UPGRADE_FUNNEL_NAME, Step, `Plot Upgrade {Step}`)
    end
end

function ProgressionFunnels.Initialize(PlayerEntity: number)
    ProgressionFunnels.Log_Lassos(PlayerEntity)
    ProgressionFunnels.Log_Daily_Rewards(PlayerEntity)
    ProgressionFunnels.Log_Plot_Areas(PlayerEntity)
end

function ProgressionFunnels.Cleanup(PlayerEntity: number)
    LoggedStepsByEntity[PlayerEntity] = nil
end

return table.freeze(ProgressionFunnels)
