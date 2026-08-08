local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Modules.Events)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local Lighting = require(script.Parent.Parent.Modules.Lighting)
local Phases = require(ReplicatedStorage.Shared.Phases)
local peek = Fusion.peek

local NORMAL_LIGHTING_NAME = "Normal"
local LastLoadedLightingName: string? = nil

local function Get_Lightings_Folder(): Folder?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Lightings = Assets and Assets:FindFirstChild("Lightings")

    return if Lightings and Lightings:IsA("Folder") then Lightings else nil
end

local function Get_Active_Events(): { any }
    local EventState = peek(FusionValues.EventState)
    local ActiveEvents = if type(EventState) == "table" then EventState.ActiveEvents else nil
    local Result = {}

    if type(ActiveEvents) ~= "table" then
        return Result
    end

    for _, ActiveEvent in ActiveEvents do
        if type(ActiveEvent) ~= "table" then
            continue
        end

        local EventName = Events.Normalize(ActiveEvent.Name)

        if not EventName then
            continue
        end

        table.insert(Result, {
            Name = EventName,
            StartedAt = if type(ActiveEvent.StartedAt) == "number" then ActiveEvent.StartedAt else 0,
        })
    end

    return Result
end

local function Get_Latest_Event_Name(ActiveEvents: { any }): string?
    local LatestEventName = nil
    local LatestStartedAt = -math.huge

    for _, ActiveEvent in ActiveEvents do
        if ActiveEvent.StartedAt > LatestStartedAt then
            LatestStartedAt = ActiveEvent.StartedAt
            LatestEventName = ActiveEvent.Name
        end
    end

    return LatestEventName
end

local function Load_Lighting(Name: string)
    if LastLoadedLightingName == Name then
        return
    end

    local Lightings = Get_Lightings_Folder()
    local Config = Lightings and Lightings:FindFirstChild(Name)

    if not Config or not Config:IsA("Configuration") then
        return
    end

    Lighting.Load(Config)
    LastLoadedLightingName = Name
end

local function Update()
    local LatestEventName = Get_Latest_Event_Name(Get_Active_Events())

    Load_Lighting(LatestEventName or NORMAL_LIGHTING_NAME)
end

return {
    name = script.Name,
    phase = Phases.Runservice.Last,
    system = Update,
    runConditions = {},
}
