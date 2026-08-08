local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(ReplicatedStorage.Shared.Components)
local Log = require(ReplicatedStorage.Shared.Log)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local World = require(ReplicatedStorage.Shared.World)

local TutorialProgress = {}

local LoggedStepsByEntity: { [number]: { [number]: boolean } } = {}
local LoggedSubeventsByEntity: { [number]: { [string]: boolean } } = {}
local PLAYER_JOINED_FUNNEL_STEP = 1

local function Get_Player(PlayerEntity: number): Player?
    local Player = World:get(PlayerEntity, Components.Player)

    return if typeof(Player) == "Instance" and Player:IsA("Player") then Player else nil
end

local function Log_Funnel_Step(PlayerEntity: number, Step: number)
    Step = math.floor(tonumber(Step) or 0)

    if type(TutorialSteps.OnboardingFunnelSteps[Step]) ~= "string" then
        return
    end

    local Player = Get_Player(PlayerEntity)

    if not Player then
        return
    end

    local LoggedSteps = LoggedStepsByEntity[PlayerEntity]

    if not LoggedSteps then
        LoggedSteps = {}
        LoggedStepsByEntity[PlayerEntity] = LoggedSteps
    end

    if LoggedSteps[Step] then
        return
    end

    LoggedSteps[Step] = true

    local StepName = TutorialSteps.Get_Funnel_Name(Step)

    Log.Info(`Fired {TutorialSteps.OnboardingFunnelName} step {Step}: {StepName} for {Player.Name} ({Player.UserId})`)

    task.spawn(function()
        pcall(function()
            AnalyticsService:LogFunnelStepEvent(Player, TutorialSteps.OnboardingFunnelName, nil, Step, StepName)
        end)
    end)
end

local function Log_Subevent_Funnel_Step(PlayerEntity: number, SubeventName: string)
    local SubeventData = TutorialSteps.Get_Subevent_Data(SubeventName)

    if not SubeventData then
        return
    end

    local Player = Get_Player(PlayerEntity)

    if not Player then
        return
    end

    local LoggedSubevents = LoggedSubeventsByEntity[PlayerEntity]

    if not LoggedSubevents then
        LoggedSubevents = {}
        LoggedSubeventsByEntity[PlayerEntity] = LoggedSubevents
    end

    if LoggedSubevents[SubeventName] then
        return
    end

    LoggedSubevents[SubeventName] = true

    local FunnelName = TutorialSteps.OnboardingSubeventFunnelName

    Log.Info(`Fired {FunnelName} step {SubeventData.Step}: {SubeventData.Name} for {Player.Name} ({Player.UserId})`)

    task.spawn(function()
        pcall(function()
            AnalyticsService:LogFunnelStepEvent(Player, FunnelName, nil, SubeventData.Step, SubeventData.Name)
        end)
    end)
end

function TutorialProgress.Get(PlayerEntity: number): number
    return TutorialSteps.Normalize_Step(World:get(PlayerEntity, Components.TutorialStep))
end

function TutorialProgress.Is_Complete(PlayerEntity: number): boolean
    return TutorialSteps.Is_Complete(TutorialProgress.Get(PlayerEntity))
end

function TutorialProgress.Log_Player_Joined(PlayerEntity: number)
    Log_Funnel_Step(PlayerEntity, PLAYER_JOINED_FUNNEL_STEP)
end

function TutorialProgress.Log_Completed_Action(PlayerEntity: number, Step: number)
    local FunnelStep = TutorialSteps.Get_Completed_Action_Funnel_Step(Step)

    if not FunnelStep then
        return
    end

    Log_Funnel_Step(PlayerEntity, FunnelStep)
end

function TutorialProgress.Log_Complete(PlayerEntity: number)
    Log_Funnel_Step(PlayerEntity, TutorialSteps.CompleteFunnelStep)
end

function TutorialProgress.Log_Subevent(PlayerEntity: number, SubeventName: string)
    Log_Subevent_Funnel_Step(PlayerEntity, SubeventName)
end

function TutorialProgress.Set(PlayerEntity: number, Step: number): boolean
    if not World:contains(PlayerEntity) then
        return false
    end

    Step = TutorialSteps.Normalize_Step(Step)

    local CurrentStep = TutorialProgress.Get(PlayerEntity)

    if Step < CurrentStep then
        return false
    end

    World:set(PlayerEntity, Components.TutorialStep, Step)

    return Step > CurrentStep
end

function TutorialProgress.Rewind_To(PlayerEntity: number, Step: number): boolean
    if not World:contains(PlayerEntity) then
        return false
    end

    Step = TutorialSteps.Normalize_Step(Step)

    local CurrentStep = TutorialProgress.Get(PlayerEntity)

    if Step >= CurrentStep then
        return TutorialProgress.Set(PlayerEntity, Step)
    end

    World:set(PlayerEntity, Components.TutorialStep, Step)

    return true
end

function TutorialProgress.Advance_To(PlayerEntity: number, Step: number): boolean
    if TutorialProgress.Is_Complete(PlayerEntity) then
        return false
    end

    Step = TutorialSteps.Normalize_Step(Step)

    if Step <= TutorialProgress.Get(PlayerEntity) then
        return false
    end

    return TutorialProgress.Set(PlayerEntity, Step)
end

function TutorialProgress.Complete_Step(PlayerEntity: number, ExpectedStep: number, NextStep: number): boolean
    if TutorialProgress.Get(PlayerEntity) ~= ExpectedStep then
        return false
    end

    if not TutorialProgress.Set(PlayerEntity, NextStep) then
        return false
    end

    TutorialProgress.Log_Completed_Action(PlayerEntity, ExpectedStep)

    if TutorialSteps.Is_Complete(NextStep) then
        TutorialProgress.Log_Complete(PlayerEntity)
    end

    return true
end

function TutorialProgress.Initialize(PlayerEntity: number)
    local Step = TutorialProgress.Get(PlayerEntity)

    World:set(PlayerEntity, Components.TutorialStep, Step)

    if not TutorialSteps.Is_Complete(Step) then
        TutorialProgress.Log_Player_Joined(PlayerEntity)
    end
end

function TutorialProgress.Cleanup(PlayerEntity: number)
    LoggedStepsByEntity[PlayerEntity] = nil
    LoggedSubeventsByEntity[PlayerEntity] = nil
end

return TutorialProgress
