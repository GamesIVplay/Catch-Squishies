local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CatchConfig = require(ReplicatedStorage.Shared.Modules.CatchConfig)
local Components = require(ReplicatedStorage.Shared.Components)
local EventMutations = require(ReplicatedStorage.Shared.Modules.EventMutations)
local EventService = require(script.Parent.Parent.Modules.EventService)
local MapRaycast = require(ReplicatedStorage.Shared.Modules.MapRaycast)
local Mutations = require(ReplicatedStorage.Shared.Modules.Mutations)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local RoamingMovement = require(ReplicatedStorage.Shared.Modules.RoamingMovement)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local TutorialProgress = require(ServerScriptService.Server.Modules.TutorialProgress)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local World = require(ReplicatedStorage.Shared.World)

local RARITY_LUCK = 1
local SPAWN_INTERVAL_SECONDS = 4
local SPAWN_SPACING_STUDS = 6
local SPAWN_SPACING_ATTEMPTS = 12
local SPAWN_SPACING_TIME_STEP_SECONDS = 0.017
local EVENT_MUTATION_ROLL_TICK_SECONDS = 0.5
local EVENT_MUTATION_ROLL_END_PADDING_SECONDS = 3
local TUTORIAL_TARGET_CHECK_INTERVAL = 0.5
local MIN_LIFETIME_SECONDS = 180
local MAX_LIFETIME_SECONDS = 300
local TUTORIAL_TARGET_LIFETIME_SECONDS = 900
local TUTORIAL_TARGET_FORWARD_OFFSET_STUDS = 8
local TUTORIAL_TARGET_AREA_MARGIN_STUDS = 4
local TUTORIAL_TARGET_SPAWN_AREA_NAME = "Center"
local MIN_SQUISHY_WEIGHT = 8
local MAX_SQUISHY_WEIGHT = 100
local COMMON_MAX_SQUISHY_WEIGHT = 25
local MIN_SCALE_WEIGHT = 8
local MAX_SCALE_WEIGHT = 100
local MIN_SQUISHY_SCALE = 1
local MAX_SQUISHY_SCALE = 5
local RARITY_SCALE_STEP = 0.1
local ROAMING_SEED_ATTRIBUTE = "RoamingSeed"
local PULL_TARGET_USER_ID_ATTRIBUTE = "PullTargetUserId"
local PULL_PROGRESS_ATTRIBUTE = "PullProgress"
local PULL_ANCHOR_X_ATTRIBUTE = "PullAnchorX"
local PULL_ANCHOR_Y_ATTRIBUTE = "PullAnchorY"
local PULL_ANCHOR_Z_ATTRIBUTE = "PullAnchorZ"
local ROAM_START_X_ATTRIBUTE = "RoamStartX"
local ROAM_START_Y_ATTRIBUTE = "RoamStartY"
local ROAM_START_Z_ATTRIBUTE = "RoamStartZ"
local ROAM_AREA_GUID_ATTRIBUTE = "RoamAreaGuid"
local ROAM_AREA_INDEX_ATTRIBUTE = "RoamAreaIndex"
local WEIGHT_BUCKETS = {
    {
        Min = 8,
        Max = 12,
        Chance = 60,
    },
    {
        Min = 13,
        Max = 20,
        Chance = 23,
    },
    {
        Min = 21,
        Max = 30,
        Chance = 10,
    },
    {
        Min = 31,
        Max = 40,
        Chance = 4,
    },
    {
        Min = 41,
        Max = 60,
        Chance = 2,
    },
    {
        Min = 61,
        Max = 80,
        Chance = 0.8,
    },
    {
        Min = 81,
        Max = 100,
        Chance = 0.2,
    },
}
local RARITY_SCALE_INDEX = table.freeze({
    Common = 0,
    Rare = 1,
    Epic = 2,
    Legendary = 3,
    Secret = 4,
    Prismatic = 5,
    Divine = 6,
    Exotic = 7,
    Transcended = 8,
})

type RoamingArea = {
    Guid: string,
    Index: number,
    Name: string,
    Part: BasePart,
    Capacity: number,
}

local SpawnBoxesRoot = workspace:WaitForChild("SpawnBoxes", 10)

if not SpawnBoxesRoot then
    error("workspace.SpawnBoxes folder is required for roaming squishy spawning")
end

local RoamingFolder = workspace:FindFirstChild("RoamingSquishies") :: Folder?
local LifetimeRNG = Random.new()
local WeightRNG = Random.new()
local EventMutationRNG = Random.new()
local LastSpawnTimesByAreaGuid: { [string]: number } = {}
local LastEventMutationRollTick = 0
local LastTutorialTargetCheck = 0
local DidInitialSpawn = false

type SquishyRoll = {
    Kind: "Slime" | "Dumpling",
    Name: string,
}

type EventMutationRollState = {
    StartedAt: number,
    RollAt: number,
    Rolled: boolean,
}

local EventMutationRollsByEntity: { [number]: { [string]: EventMutationRollState } } = {}

if not RoamingFolder then
    RoamingFolder = Instance.new("Folder")
    RoamingFolder.Name = "RoamingSquishies"
    RoamingFolder.Parent = workspace
end

local RoamingSeed = ReplicatedStorage:GetAttribute(ROAMING_SEED_ATTRIBUTE)

if type(RoamingSeed) ~= "number" then
    RoamingSeed = Random.new():NextInteger(1, 2_147_483_647)
    ReplicatedStorage:SetAttribute(ROAMING_SEED_ATTRIBUTE, RoamingSeed)
end

local RoamingSquishies = World:query(Components.Renderable, Components.SpawnTime, Components.Lifetime)
    :with(Components.Tags.WildSquishy, Components.Tags.Roaming)
    :cached()

local CachedRoamingAreas: { RoamingArea }? = nil

local function Sort_Spawn_Area_Parts(Parts: { BasePart })
    table.sort(Parts, function(Left, Right)
        local LeftNumber = tonumber(Left.Name)
        local RightNumber = tonumber(Right.Name)

        if LeftNumber and RightNumber and LeftNumber ~= RightNumber then
            return LeftNumber < RightNumber
        end

        if Left.Name ~= Right.Name then
            return Left.Name < Right.Name
        end

        return Left:GetFullName() < Right:GetFullName()
    end)
end

local function Get_Spawn_Area_Parts(): { BasePart }
    if not SpawnBoxesRoot:IsA("Folder") then
        error("workspace.SpawnBoxes must be a Folder containing BasePart spawn areas")
    end

    local Parts = {}

    for _, Child in SpawnBoxesRoot:GetChildren() do
        if Child:IsA("BasePart") then
            table.insert(Parts, Child)
        end
    end

    Sort_Spawn_Area_Parts(Parts)

    return Parts
end

local function Get_Required_Area_Capacity(AreaPart: BasePart): number
    local MaxAttribute = AreaPart:GetAttribute("Max")

    if type(MaxAttribute) ~= "number" then
        error(`SpawnBoxes area "{AreaPart.Name}" is missing required positive number attribute "Max"`)
    end

    local Capacity = math.floor(MaxAttribute)

    if Capacity <= 0 then
        error(`SpawnBoxes area "{AreaPart.Name}" has invalid Max attribute; Max must be greater than 0`)
    end

    return Capacity
end

local function Generate_Unique_Area_Guid(UsedGuids: { [string]: boolean }): string
    local Guid = HttpService:GenerateGUID(false)

    while UsedGuids[Guid] do
        Guid = HttpService:GenerateGUID(false)
    end

    UsedGuids[Guid] = true

    return Guid
end

local function Get_Roaming_Areas(): { RoamingArea }
    if CachedRoamingAreas then
        return CachedRoamingAreas
    end

    local Parts = Get_Spawn_Area_Parts()

    if #Parts == 0 then
        error("workspace.SpawnBoxes must contain at least one BasePart spawn area")
    end

    local Areas = {}
    local UsedGuids = {}

    for Index, Part in Parts do
        local Capacity = Get_Required_Area_Capacity(Part)
        local Guid = Generate_Unique_Area_Guid(UsedGuids)
        local Name = Part.Name

        Part:SetAttribute("SpawnAreaName", Name)
        Part.Name = Guid
        Part:SetAttribute("SpawnAreaGuid", Guid)
        Part:SetAttribute("SpawnAreaIndex", Index)

        table.insert(Areas, {
            Guid = Guid,
            Index = Index,
            Name = Name,
            Part = Part,
            Capacity = Capacity,
        })
    end

    CachedRoamingAreas = Areas

    return Areas
end

local function Get_Area_By_Model(Model: Model?, Areas: { RoamingArea }): RoamingArea?
    if #Areas == 0 then
        return nil
    end

    if Model then
        local AreaGuid = Model:GetAttribute(ROAM_AREA_GUID_ATTRIBUTE)

        if type(AreaGuid) == "string" then
            for _, Area in Areas do
                if Area.Guid == AreaGuid then
                    return Area
                end
            end
        end

        local AreaIndex = Model:GetAttribute(ROAM_AREA_INDEX_ATTRIBUTE)

        if type(AreaIndex) == "number" then
            local RoundedIndex = math.floor(AreaIndex)

            for _, Area in Areas do
                if Area.Index == RoundedIndex then
                    return Area
                end
            end
        end
    end

    return nil
end

local function Count_Roaming_Squishies_In_Area(Area: RoamingArea, Areas: { RoamingArea }): number
    local Count = 0

    for _Entity, Model: Model in RoamingSquishies:iter() do
        local ModelArea = Get_Area_By_Model(Model, Areas)

        if ModelArea and ModelArea.Index == Area.Index then
            Count += 1
        end
    end

    return Count
end

local function Prepare_Model(Model: Model)
    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Descendant.Anchored = true
            Descendant.CanCollide = false
        end
    end
end

local function Roll_Squishy_Weight(MaxWeight: number): number
    local Total_Chance = 0

    for _, Bucket in WEIGHT_BUCKETS do
        if Bucket.Min > MaxWeight then
            continue
        end

        Total_Chance += Bucket.Chance
    end

    local Roll = WeightRNG:NextNumber(0, Total_Chance)
    local Running_Chance = 0

    for _, Bucket in WEIGHT_BUCKETS do
        if Bucket.Min > MaxWeight then
            continue
        end

        Running_Chance += Bucket.Chance

        if Roll <= Running_Chance then
            return WeightRNG:NextInteger(Bucket.Min, math.min(Bucket.Max, MaxWeight))
        end
    end

    return WeightRNG:NextInteger(MIN_SQUISHY_WEIGHT, MaxWeight)
end

local function Get_Max_Weight_For_Rarity(Rarity: string): number
    if Rarity == "Common" then
        return COMMON_MAX_SQUISHY_WEIGHT
    end

    return MAX_SQUISHY_WEIGHT
end

local function Get_Scale_From_Weight(Weight: number): number
    local Clamped_Weight = math.clamp(Weight, MIN_SCALE_WEIGHT, MAX_SCALE_WEIGHT)
    local Alpha = (Clamped_Weight - MIN_SCALE_WEIGHT) / (MAX_SCALE_WEIGHT - MIN_SCALE_WEIGHT)

    return MIN_SQUISHY_SCALE + Alpha * (MAX_SQUISHY_SCALE - MIN_SQUISHY_SCALE)
end

local function Get_Rarity_Scale_Boost(Rarity: string): number
    return (RARITY_SCALE_INDEX[Rarity] or 0) * RARITY_SCALE_STEP
end

local function Get_Flat_Distance(Left: Vector3, Right: Vector3): number
    return Vector3.new(Left.X - Right.X, 0, Left.Z - Right.Z).Magnitude
end

local function Get_Roam_Start_Position(Model: Model?): Vector3?
    if not Model then
        return nil
    end

    local StartX = Model:GetAttribute(ROAM_START_X_ATTRIBUTE)
    local StartY = Model:GetAttribute(ROAM_START_Y_ATTRIBUTE)
    local StartZ = Model:GetAttribute(ROAM_START_Z_ATTRIBUTE)

    if type(StartX) ~= "number" or type(StartY) ~= "number" or type(StartZ) ~= "number" then
        return nil
    end

    return Vector3.new(StartX, StartY, StartZ)
end

local function Get_Roaming_Position_For_Spacing(
    Entity: number,
    SpawnTime: number,
    Lifetime: number,
    Now: number,
    Area: RoamingArea
): Vector3?
    local BaseY = World:get(Entity, Components.BaseY)

    if type(BaseY) ~= "number" then
        return nil
    end

    local Model = World:get(Entity, Components.Renderable)
    local StartPosition = Get_Roam_Start_Position(Model)

    if Model and Model:GetAttribute(TutorialSteps.StationaryTargetAttribute) == true and StartPosition then
        return StartPosition
    end

    return RoamingMovement.GetCurrentPosition(
        RoamingSeed :: number,
        Entity,
        SpawnTime,
        Lifetime,
        Now,
        Area.Part,
        BaseY,
        StartPosition
    )
end

local function Get_Nearest_Roaming_Distance(
    Position: Vector3,
    Now: number,
    Area: RoamingArea,
    Areas: { RoamingArea }
): number
    local NearestDistance = math.huge

    for Entity, _Model: Model, SpawnTime: number, Lifetime: number in RoamingSquishies:iter() do
        local ModelArea = Get_Area_By_Model(_Model, Areas)

        if not ModelArea or ModelArea.Index ~= Area.Index then
            continue
        end

        local RoamingPosition = Get_Roaming_Position_For_Spacing(Entity, SpawnTime, Lifetime, Now, Area)

        if not RoamingPosition then
            continue
        end

        NearestDistance = math.min(NearestDistance, Get_Flat_Distance(Position, RoamingPosition))
    end

    return NearestDistance
end

local function Get_Spaced_Spawn_Position(
    Entity: number,
    SpawnTime: number,
    Area: RoamingArea,
    Areas: { RoamingArea }
): (Vector3, number)
    local Seed = RoamingSeed :: number
    local BestPosition = RoamingMovement.GetInitialPosition(Seed, Entity, SpawnTime, Area.Part, Area.Part.Position.Y)
    local BestSpawnTime = SpawnTime
    local BestDistance = Get_Nearest_Roaming_Distance(BestPosition, SpawnTime, Area, Areas)

    if SPAWN_SPACING_STUDS <= 0 or BestDistance >= SPAWN_SPACING_STUDS then
        return BestPosition, BestSpawnTime
    end

    for Attempt = 2, math.max(SPAWN_SPACING_ATTEMPTS, 1) do
        local CandidateSpawnTime = SpawnTime - ((Attempt - 1) * SPAWN_SPACING_TIME_STEP_SECONDS)
        local CandidatePosition =
            RoamingMovement.GetInitialPosition(Seed, Entity, CandidateSpawnTime, Area.Part, Area.Part.Position.Y)
        local CandidateDistance = Get_Nearest_Roaming_Distance(CandidatePosition, SpawnTime, Area, Areas)

        if CandidateDistance >= SPAWN_SPACING_STUDS then
            return CandidatePosition, CandidateSpawnTime
        end

        if CandidateDistance > BestDistance then
            BestPosition = CandidatePosition
            BestSpawnTime = CandidateSpawnTime
            BestDistance = CandidateDistance
        end
    end

    return BestPosition, BestSpawnTime
end

local function Get_Event_Roll_Record(Entity: number): { [string]: EventMutationRollState }
    local Record = EventMutationRollsByEntity[Entity]

    if not Record then
        Record = {}
        EventMutationRollsByEntity[Entity] = Record
    end

    return Record
end

local function Get_Event_Mutation_Roll_Time(ActiveEvent: any, Now: number): number?
    local EndsAt = if type(ActiveEvent) == "table" and type(ActiveEvent.EndsAt) == "number"
        then ActiveEvent.EndsAt
        else Now

    if EndsAt <= Now then
        return nil
    end

    local LatestRollAt = EndsAt - EVENT_MUTATION_ROLL_END_PADDING_SECONDS

    if LatestRollAt <= Now then
        return Now
    end

    return EventMutationRNG:NextNumber(Now, LatestRollAt)
end

local function Get_Or_Create_Event_Mutation_Roll(
    Entity: number,
    EventName: string,
    ActiveEvent: any,
    Now: number
): EventMutationRollState?
    local StartedAt = if type(ActiveEvent) == "table" and type(ActiveEvent.StartedAt) == "number"
        then ActiveEvent.StartedAt
        else 0
    local RollRecord = Get_Event_Roll_Record(Entity)
    local ExistingRoll = RollRecord[EventName]

    if type(ExistingRoll) == "table" and ExistingRoll.StartedAt == StartedAt then
        return ExistingRoll
    end

    local RollAt = Get_Event_Mutation_Roll_Time(ActiveEvent, Now)

    if not RollAt then
        return nil
    end

    local NewRoll = {
        StartedAt = StartedAt,
        RollAt = RollAt,
        Rolled = false,
    }

    RollRecord[EventName] = NewRoll

    return NewRoll
end

local function Mark_Event_Mutation_Rolls_Complete(Entity: number, ActiveEvents: any, Now: number)
    if type(ActiveEvents) ~= "table" then
        return
    end

    local RollRecord = Get_Event_Roll_Record(Entity)

    for EventName, ActiveEvent in ActiveEvents do
        local StartedAt = if type(ActiveEvent) == "table" and type(ActiveEvent.StartedAt) == "number"
            then ActiveEvent.StartedAt
            else 0

        RollRecord[EventName] = {
            StartedAt = StartedAt,
            RollAt = Now,
            Rolled = true,
        }
    end
end

local function Is_Tutorial_Roll_Rarity(Step: number, Rarity: string): boolean
    if Step == TutorialSteps.CatchFirst then
        return Rarity == "Common"
    end

    if Step == TutorialSteps.CatchStrong then
        return Rarity == "Rare"
    end

    return false
end

local function Get_Tutorial_Roll(Step: number): SquishyRoll?
    for _, Entry in Squishies.GetIndexEntries() do
        if not Is_Tutorial_Roll_Rarity(Step, Entry.Rarity) then
            continue
        end

        if not Squishies.GetModel(Entry.Kind, Entry.Name, Mutations.Normal) then
            continue
        end

        return {
            Kind = Entry.Kind,
            Name = Entry.Name,
        }
    end

    return nil
end

local function Get_Player_Root_CFrame(Player: Player): CFrame?
    local Character = Player.Character
    local Root = Character and (Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart)

    return if Root and Root:IsA("BasePart") then Root.CFrame else nil
end

local function Get_Player_Root_Position(Player: Player): Vector3?
    local RootCFrame = Get_Player_Root_CFrame(Player)

    return if RootCFrame then RootCFrame.Position else nil
end

local function Get_Player_Plot_Spawn_Position(PlayerEntity: number?): Vector3?
    if not PlayerEntity or not World:contains(PlayerEntity) then
        return nil
    end

    local PlotEntity = World:target(PlayerEntity, Components.Relationships.Plot)
    local Plot = PlotEntity and World:get(PlotEntity, Components.Renderable)
    local Spawn = Plot and Plot:FindFirstChild("Spawn")

    return if Spawn and Spawn:IsA("BasePart") then Spawn.Position else nil
end

local function Get_Tutorial_Anchor_Position(Player: Player, PlayerEntity: number?): Vector3?
    return Get_Player_Plot_Spawn_Position(PlayerEntity) or Get_Player_Root_Position(Player)
end

local function Get_Nearest_Area_To_Position(Position: Vector3?, Areas: { RoamingArea }): RoamingArea?
    local BestArea = Areas[1]
    local BestDistance = math.huge

    if not Position then
        return BestArea
    end

    for _, Area in Areas do
        local Distance = Get_Flat_Distance(Position, Area.Part.Position)

        if Distance < BestDistance then
            BestArea = Area
            BestDistance = Distance
        end
    end

    return BestArea
end

local function Get_Tutorial_Spawn_Area(RoamingAreas: { RoamingArea }): RoamingArea?
    for _, Area in RoamingAreas do
        local SpawnAreaName = Area.Part:GetAttribute("SpawnAreaName")

        if Area.Name == TUTORIAL_TARGET_SPAWN_AREA_NAME or SpawnAreaName == TUTORIAL_TARGET_SPAWN_AREA_NAME then
            return Area
        end
    end

    return nil
end

local function Clamp_Position_To_Area(Area: RoamingArea, Position: Vector3): Vector3
    local LocalPosition = Area.Part.CFrame:PointToObjectSpace(Position)
    local HalfSize = Area.Part.Size * 0.5
    local MaxX = math.max(0, HalfSize.X - math.min(TUTORIAL_TARGET_AREA_MARGIN_STUDS, HalfSize.X))
    local MaxZ = math.max(0, HalfSize.Z - math.min(TUTORIAL_TARGET_AREA_MARGIN_STUDS, HalfSize.Z))
    local ClampedLocal =
        Vector3.new(math.clamp(LocalPosition.X, -MaxX, MaxX), 0, math.clamp(LocalPosition.Z, -MaxZ, MaxZ))
    local WorldPosition = Area.Part.CFrame:PointToWorldSpace(ClampedLocal)

    return MapRaycast.GetGroundedPosition(WorldPosition, Area.Part.Position.Y, 120, 400)
end

local function Get_Forward_Tutorial_Position(Area: RoamingArea, AnchorPosition: Vector3): Vector3
    local Forward = Vector3.new(Area.Part.Position.X - AnchorPosition.X, 0, Area.Part.Position.Z - AnchorPosition.Z)

    if Forward.Magnitude < 0.05 then
        Forward = Vector3.new(Area.Part.CFrame.LookVector.X, 0, Area.Part.CFrame.LookVector.Z)
    end

    if Forward.Magnitude < 0.05 then
        return AnchorPosition
    end

    return AnchorPosition + Forward.Unit * TUTORIAL_TARGET_FORWARD_OFFSET_STUDS
end

local function Get_Tutorial_Spawn_Position(
    Entity: number,
    SpawnTime: number,
    Area: RoamingArea,
    Areas: { RoamingArea },
    Player: Player?,
    PlayerEntity: number?
): (Vector3, number)
    local AnchorPosition = Player and Get_Tutorial_Anchor_Position(Player, PlayerEntity) or nil

    if not AnchorPosition then
        return Get_Spaced_Spawn_Position(Entity, SpawnTime, Area, Areas)
    end

    return Clamp_Position_To_Area(Area, Get_Forward_Tutorial_Position(Area, AnchorPosition)), SpawnTime
end

local function Has_Tutorial_Target(Player: Player, Step: number): boolean
    for _Entity, Model: Model in RoamingSquishies:iter() do
        if
            Model:GetAttribute(TutorialSteps.TargetUserIdAttribute) == Player.UserId
            and Model:GetAttribute(TutorialSteps.TargetStepAttribute) == Step
        then
            return true
        end
    end

    return false
end

local function Get_Tutorial_Role_For_Target_Step(Step: number): string?
    if Step == TutorialSteps.CatchFirst then
        return TutorialSteps.FirstRole
    end

    if Step == TutorialSteps.CatchStrong then
        return TutorialSteps.StrongRole
    end

    return nil
end

local function Has_Tutorial_Role(PlayerEntity: number, Role: string): boolean
    for _, Items in
        {
            World:get(PlayerEntity, Components.OwnedSquishies),
            World:get(PlayerEntity, Components.PlotSquishies),
        }
    do
        if type(Items) ~= "table" then
            continue
        end

        for _, Item in Items do
            if type(Item) == "table" and Item.TutorialRole == Role then
                return true
            end
        end
    end

    return false
end

local function Needs_Tutorial_Target(PlayerEntity: number, Step: number): boolean
    local Role = Get_Tutorial_Role_For_Target_Step(Step)

    return Role ~= nil and not Has_Tutorial_Role(PlayerEntity, Role)
end

local function Get_Tutorial_Target_Step(CurrentStep: number?): number?
    CurrentStep = TutorialSteps.Normalize_Step(CurrentStep)

    if CurrentStep == TutorialSteps.EquipLasso or CurrentStep == TutorialSteps.CatchFirst then
        return TutorialSteps.CatchFirst
    end

    return nil
end

local function Spawn_Roaming_Squishy(
    Area: RoamingArea,
    Areas: { RoamingArea },
    TutorialPlayer: Player?,
    TutorialStep: number?,
    TutorialPlayerEntity: number?
): boolean
    local Roll = if TutorialStep then Get_Tutorial_Roll(TutorialStep) else Squishies.Roll_Squishy(RARITY_LUCK)

    if not Roll then
        return false
    end

    local Mutation = if TutorialStep then Mutations.Normal else Mutations.Roll(Roll.Kind)
    local ActiveEvents = EventService.GetActiveEvents()
    local EventMutationList = if TutorialStep
        then {}
        else EventMutations.RollForActiveEvents(ActiveEvents, EventMutationRNG)
    local Template = Squishies.GetModel(Roll.Kind, Roll.Name, Mutation)

    if not Template then
        return false
    end

    local SquishyData = Squishies.GetData(Roll.Kind, Roll.Name)

    if not SquishyData then
        return false
    end

    local Entity = World:entity()
    local Model = Template:Clone()
    local SpawnTime = workspace:GetServerTimeNow()
    local Lifetime = if TutorialStep
        then TUTORIAL_TARGET_LIFETIME_SECONDS
        else LifetimeRNG:NextNumber(MIN_LIFETIME_SECONDS, MAX_LIFETIME_SECONDS)
    local Weight = Roll_Squishy_Weight(Get_Max_Weight_For_Rarity(SquishyData.Rarity))
    local Strength = CatchConfig.Get_Catch_Strength(SquishyData, Weight)
    local Scale = Get_Scale_From_Weight(Weight) + Get_Rarity_Scale_Boost(SquishyData.Rarity)
    local SpawnPosition: Vector3
    local SpacedSpawnTime: number

    if TutorialPlayer then
        SpawnPosition, SpacedSpawnTime =
            Get_Tutorial_Spawn_Position(Entity, SpawnTime, Area, Areas, TutorialPlayer, TutorialPlayerEntity)
    else
        SpawnPosition, SpacedSpawnTime = Get_Spaced_Spawn_Position(Entity, SpawnTime, Area, Areas)
    end

    SpawnTime = SpacedSpawnTime

    local DespawnTime = SpawnTime + Lifetime
    local BaseY = SpawnPosition.Y

    Model.Name = tostring(Entity)
    Prepare_Model(Model)
    Model:ScaleTo(Scale)
    Model:PivotTo(CFrame.new(SpawnPosition))
    Model:SetAttribute("Rarity", SquishyData.Rarity)
    Model:SetAttribute("Mutation", Mutation)
    Model:SetAttribute("EventMutations", EventMutations.EncodeAttribute(EventMutationList))
    Model:SetAttribute("Strength", Strength)
    Model:SetAttribute("DespawnTime", DespawnTime)
    Model:SetAttribute(ROAM_AREA_GUID_ATTRIBUTE, Area.Guid)
    Model:SetAttribute(ROAM_AREA_INDEX_ATTRIBUTE, Area.Index)

    if TutorialPlayer and TutorialStep then
        Model:SetAttribute(TutorialSteps.TargetUserIdAttribute, TutorialPlayer.UserId)
        Model:SetAttribute(TutorialSteps.TargetStepAttribute, TutorialStep)
        Model:SetAttribute(TutorialSteps.StationaryTargetAttribute, true)
        Model:SetAttribute(ROAM_START_X_ATTRIBUTE, SpawnPosition.X)
        Model:SetAttribute(ROAM_START_Y_ATTRIBUTE, SpawnPosition.Y)
        Model:SetAttribute(ROAM_START_Z_ATTRIBUTE, SpawnPosition.Z)
    end

    Model.Parent = RoamingFolder
    Model:AddTag("Roaming")
    Model:AddTag("WildSquishy")

    World:set(Entity, Components.Renderable, Model)
    World:set(Entity, Components.Kind, Roll.Kind)
    World:set(Entity, Components.Name, Roll.Name)
    World:set(Entity, Components.Mutation, Mutation)
    World:set(Entity, Components.EventMutations, EventMutationList)
    World:set(Entity, Components.SpawnTime, SpawnTime)
    World:set(Entity, Components.Lifetime, Lifetime)
    World:set(Entity, Components.BaseY, BaseY)
    World:set(Entity, Components.Weight, Weight)
    World:set(Entity, Components.Cleanup, function()
        EventMutationRollsByEntity[Entity] = nil

        if Model.Parent then
            Model:Destroy()
        end
    end)

    World:add(Entity, Components.Tags.Roaming)
    World:add(Entity, Components.Tags.WildSquishy)
    World:add(Entity, Components.Tags.Networked)

    Mark_Event_Mutation_Rolls_Complete(Entity, ActiveEvents, SpawnTime)

    return true
end

local function Apply_Event_Mutation_Rolls_To_Roaming()
    local Now = workspace:GetServerTimeNow()

    if Now - LastEventMutationRollTick < EVENT_MUTATION_ROLL_TICK_SECONDS then
        return
    end

    LastEventMutationRollTick = Now

    local ActiveEvents = EventService.GetActiveEvents()

    if next(ActiveEvents) == nil then
        return
    end

    for Entity, _Model: Model in RoamingSquishies:iter() do
        local CurrentEventMutations = EventMutations.NormalizeList(World:get(Entity, Components.EventMutations))
        local DidChange = false

        for EventName, ActiveEvent in ActiveEvents do
            if EventMutations.Has(CurrentEventMutations, EventName) then
                continue
            end

            local EventRoll = Get_Or_Create_Event_Mutation_Roll(Entity, EventName, ActiveEvent, Now)

            if
                not EventRoll
                or EventRoll.Rolled == true
                or type(EventRoll.RollAt) ~= "number"
                or Now < EventRoll.RollAt
            then
                continue
            end

            EventRoll.Rolled = true

            if not EventMutations.RollForEvent(EventName, EventMutationRNG) then
                continue
            end

            CurrentEventMutations = EventMutations.Add(CurrentEventMutations, EventName)
            DidChange = true
        end

        if DidChange then
            World:set(Entity, Components.EventMutations, CurrentEventMutations)
        end
    end
end

local function Despawn_Expired_Squishies()
    local Now = workspace:GetServerTimeNow()

    for Entity, _Model: Model, SpawnTime: number, Lifetime: number in RoamingSquishies:iter() do
        if Now >= SpawnTime + Lifetime then
            World:delete(Entity)
        end
    end
end

local function Cleanup_Tutorial_Targets()
    local ToDelete = {}

    for Entity, Model: Model in RoamingSquishies:iter() do
        local TargetUserId = Model:GetAttribute(TutorialSteps.TargetUserIdAttribute)
        local TargetStep = Model:GetAttribute(TutorialSteps.TargetStepAttribute)

        if type(TargetUserId) ~= "number" and type(TargetStep) ~= "number" then
            continue
        end

        local Player = if type(TargetUserId) == "number" then Players:GetPlayerByUserId(TargetUserId) else nil
        local PlayerEntity = Player and Registry.Get("Players", Player)
        local CurrentStep = PlayerEntity and World:contains(PlayerEntity) and TutorialProgress.Get(PlayerEntity) or nil
        local TargetStepForCurrentStep = Get_Tutorial_Target_Step(CurrentStep)

        if
            not Player
            or not PlayerEntity
            or not World:contains(PlayerEntity)
            or TutorialSteps.Is_Complete(CurrentStep)
            or TargetStepForCurrentStep ~= TargetStep
            or not Needs_Tutorial_Target(PlayerEntity, TargetStep)
            or Model:GetAttribute(TutorialSteps.StationaryTargetAttribute) ~= true
        then
            table.insert(ToDelete, Entity)
        end
    end

    for _, Entity in ToDelete do
        if World:contains(Entity) then
            World:delete(Entity)
        end
    end
end

local function Ensure_Tutorial_Targets()
    local Now = workspace:GetServerTimeNow()

    if Now - LastTutorialTargetCheck < TUTORIAL_TARGET_CHECK_INTERVAL then
        return
    end

    LastTutorialTargetCheck = Now
    Cleanup_Tutorial_Targets()

    local Areas = Get_Roaming_Areas()

    for _, Player in Players:GetPlayers() do
        local PlayerEntity = Registry.Get("Players", Player)

        if not PlayerEntity or not World:contains(PlayerEntity) then
            continue
        end

        local Step = TutorialProgress.Get(PlayerEntity)
        local TargetStep = Get_Tutorial_Target_Step(Step)

        if
            not TargetStep
            or not Needs_Tutorial_Target(PlayerEntity, TargetStep)
            or Has_Tutorial_Target(Player, TargetStep)
        then
            continue
        end

        local Area = Get_Tutorial_Spawn_Area(Areas)
            or Get_Nearest_Area_To_Position(Get_Tutorial_Anchor_Position(Player, PlayerEntity), Areas)

        if Area then
            Spawn_Roaming_Squishy(Area, Areas, Player, TargetStep, PlayerEntity)
        end
    end
end

local function Get_Model_By_Entity(Entity: number): Model?
    for _, Child in RoamingFolder:GetChildren() do
        if not Child:IsA("Model") then
            continue
        end

        if Child:GetAttribute("ServerEntity") == Entity then
            return Child
        end
    end

    return nil
end

local function Get_Number_For_Entity(Entity: number, Component: any, Attribute: string): number?
    local Model = Get_Model_By_Entity(Entity)
    local Attribute_Value = Model and Model:GetAttribute(Attribute)

    if type(Attribute_Value) == "number" then
        return Attribute_Value
    end

    if not World:contains(Entity) then
        return nil
    end

    local Component_Value = World:get(Entity, Component)

    if type(Component_Value) == "number" then
        return Component_Value
    end

    return nil
end

local function Get_Grounded_Position(Position: Vector3, FallbackY: number): Vector3
    return MapRaycast.GetGroundedPosition(Position, FallbackY, 120, 400)
end

local function Get_Pull_Anchor_Position(Model: Model): Vector3?
    local AnchorX = Model:GetAttribute(PULL_ANCHOR_X_ATTRIBUTE)
    local AnchorY = Model:GetAttribute(PULL_ANCHOR_Y_ATTRIBUTE)
    local AnchorZ = Model:GetAttribute(PULL_ANCHOR_Z_ATTRIBUTE)

    if type(AnchorX) ~= "number" or type(AnchorY) ~= "number" or type(AnchorZ) ~= "number" then
        return nil
    end

    return Vector3.new(AnchorX, AnchorY, AnchorZ)
end

local function Face_Player_CFrame(Position: Vector3, RootPosition: Vector3, FallbackRotation: CFrame): CFrame
    local LookAtPosition = Vector3.new(RootPosition.X, Position.Y, RootPosition.Z)

    if (LookAtPosition - Position).Magnitude < 0.05 then
        return CFrame.new(Position) * FallbackRotation
    end

    return CFrame.lookAt(Position, LookAtPosition)
end

local function Get_Current_CFrame(Entity: number): CFrame?
    local SpawnTime = Get_Number_For_Entity(Entity, Components.SpawnTime, "SpawnTime")
    local Lifetime = Get_Number_For_Entity(Entity, Components.Lifetime, "Lifetime")
    local BaseY = Get_Number_For_Entity(Entity, Components.BaseY, "BaseY")
    local Model = Get_Model_By_Entity(Entity)
    local Area = Get_Area_By_Model(Model, Get_Roaming_Areas())
    local StartPosition = Get_Roam_Start_Position(Model)

    if not SpawnTime or not Lifetime or not BaseY or not Area then
        return nil
    end

    local CurrentCFrame = RoamingMovement.GetCurrentCFrame(
        RoamingSeed :: number,
        Entity,
        SpawnTime,
        Lifetime,
        workspace:GetServerTimeNow(),
        Area.Part,
        BaseY,
        StartPosition
    )

    if not CurrentCFrame then
        return nil
    end

    if Model and Model:GetAttribute(TutorialSteps.StationaryTargetAttribute) == true then
        CurrentCFrame = CFrame.new(StartPosition or CurrentCFrame.Position)
    end

    local TargetUserId = Model and Model:GetAttribute(PULL_TARGET_USER_ID_ATTRIBUTE)
    local PullProgress = Model and Model:GetAttribute(PULL_PROGRESS_ATTRIBUTE)
    local AnchorPosition = Model and Get_Pull_Anchor_Position(Model)

    if type(TargetUserId) ~= "number" or type(PullProgress) ~= "number" then
        if AnchorPosition then
            local GroundedAnchor = Get_Grounded_Position(AnchorPosition, CurrentCFrame.Position.Y)

            return CFrame.new(GroundedAnchor) * CurrentCFrame.Rotation
        end

        return CurrentCFrame
    end

    local Player = Players:GetPlayerByUserId(TargetUserId)
    local Character = Player and Player.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if not Root or not Root:IsA("BasePart") then
        return CurrentCFrame
    end

    local CurrentPosition = AnchorPosition or CurrentCFrame.Position
    CurrentPosition = Get_Grounded_Position(CurrentPosition, CurrentCFrame.Position.Y)

    local RootPosition = Root.Position
    local FlatOffset = Vector3.new(CurrentPosition.X - RootPosition.X, 0, CurrentPosition.Z - RootPosition.Z)
    local PullAlpha = math.clamp(PullProgress, 0, 1)

    if PullAlpha <= 0 then
        return Face_Player_CFrame(CurrentPosition, RootPosition, CurrentCFrame.Rotation)
    end

    if FlatOffset.Magnitude < 0.05 then
        return Face_Player_CFrame(CurrentPosition, RootPosition, CurrentCFrame.Rotation)
    end

    local PullPosition = RootPosition + FlatOffset.Unit * CatchConfig.CatchPullStopDistance
    PullPosition = Get_Grounded_Position(PullPosition, CurrentPosition.Y)

    local BlendedPosition = CurrentPosition:Lerp(PullPosition, PullAlpha)
    return Face_Player_CFrame(BlendedPosition, RootPosition, CurrentCFrame.Rotation)
end

local function Get_Current_Position(Entity: number): Vector3?
    local Current_CFrame = Get_Current_CFrame(Entity)

    if not Current_CFrame then
        return nil
    end

    return Current_CFrame.Position
end

local function Fill_Initial_Spawns()
    if DidInitialSpawn then
        return
    end

    DidInitialSpawn = true

    local Areas = Get_Roaming_Areas()

    for _, Area in Areas do
        local MissingSquishies = Area.Capacity - Count_Roaming_Squishies_In_Area(Area, Areas)

        for _ = 1, math.max(MissingSquishies, 0) do
            if not Spawn_Roaming_Squishy(Area, Areas) then
                break
            end
        end
    end
end

local function Spawn_Over_Time()
    local Now = workspace:GetServerTimeNow()
    local Areas = Get_Roaming_Areas()

    for _, Area in Areas do
        if Count_Roaming_Squishies_In_Area(Area, Areas) >= Area.Capacity then
            continue
        end

        local LastSpawnTime = LastSpawnTimesByAreaGuid[Area.Guid] or 0

        if Now - LastSpawnTime < SPAWN_INTERVAL_SECONDS then
            continue
        end

        LastSpawnTimesByAreaGuid[Area.Guid] = Now
        Spawn_Roaming_Squishy(Area, Areas)
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.PreUpdate,
    GetCurrentCFrame = Get_Current_CFrame,
    GetCurrentPosition = Get_Current_Position,
    system = function()
        Fill_Initial_Spawns()
        Ensure_Tutorial_Targets()
        Despawn_Expired_Squishies()
        Spawn_Over_Time()
        Apply_Event_Mutation_Rolls_To_Roaming()
    end,
}
