local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatchConfig = require(ReplicatedStorage.Shared.Modules.CatchConfig)
local Config = require(ReplicatedStorage.Shared.Config)
local EventMutationVFX = require(script.Parent.Parent.Modules.EventMutationVFX)
local MapRaycast = require(ReplicatedStorage.Shared.Modules.MapRaycast)
local Mutations = require(ReplicatedStorage.Shared.Modules.Mutations)
local Phases = require(ReplicatedStorage.Shared.Phases)
local RarityGradients = require(script.Parent.Parent.Modules.RarityGradients)
local RoamingMovement = require(ReplicatedStorage.Shared.Modules.RoamingMovement)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

type SquishyKind = "Slime" | "Dumpling"

type AnimationCache = {
    Kind: SquishyKind,
    IdleTrack: AnimationTrack?,
    WalkTrack: AnimationTrack?,
}

type MovementCache = {
    ServerEntity: number,
    SpawnTime: number,
    BaseY: number,
    SpawnBoxPart: BasePart,
    StartPosition: Vector3?,
    JourneyIndex: number,
    JourneyStartTime: number,
    Segment: RoamingMovement.JourneySegment,
    LastUpdateTime: number?,
}

type RoamingModelState = {
    Cache: MovementCache,
    Kind: SquishyKind,
    TargetCFrame: CFrame,
    IsWalking: boolean,
    IsPulling: boolean,
}

type BillboardCache = {
    Billboard: BillboardGui,
    NameObject: GuiObject?,
    RarityObject: GuiObject?,
    StrengthObject: GuiObject?,
    TimerObject: GuiObject?,
    IncomePerSecObject: GuiObject?,
    WeightObject: GuiObject?,
    NameLabel: TextLabel?,
    RarityLabel: TextLabel?,
    StrengthLabel: TextLabel?,
    TimerLabel: TextLabel?,
    LastNameText: string?,
    LastRarity: string?,
    LastStrengthText: string?,
    LastTimerText: string?,
}

type SpawnAreaCache = {
    Root: Folder,
    BuiltAt: number,
    Parts: { BasePart },
    ByGuid: { [string]: BasePart },
    ByIndex: { [number]: BasePart },
}

type ModelSpawnAreaCache = {
    AreaGuid: string?,
    AreaIndex: number?,
    Part: BasePart?,
}

type RuntimeState = {
    NextUpdateAt: number,
    LastBillboardAt: number,
    LastPosition: Vector3?,
    LastLod: string?,
}

type ModelListCache = {
    Container: Instance,
    BuiltAt: number,
    Models: { Model },
}

type HiddenPartState = {
    LocalTransparencyModifier: number,
    CanQuery: boolean,
}

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
local SQUISHY_OVERHEAD_NAME = "SquishyOverhead"
local BILLBOARD_ATTACHMENT_FALLBACK_NAME = "SquishyOverheadAttachment"
local ANIMATION_FADE_TIME = 0.15
local WALK_ANIMATION_SPEED = 1.25
local IDLE_ANIMATION_SPEED = 1
local ROTATION_RESPONSIVENESS = 12
local MAX_JOURNEY_ADVANCES_PER_STEP = 8
local CULL_DISTANCE = 200
local CULLED_FOLDER_NAME = "Culled"
local SUPER_CLOSE_DISTANCE = 50
local NEAR_DISTANCE = 90
local MID_DISTANCE = 160
local SUPER_CLOSE_UPDATE_INTERVAL = 1 / 60
local NEAR_UPDATE_INTERVAL = 1 / 30
local MID_UPDATE_INTERVAL = 1 / 12
local FAR_UPDATE_INTERVAL = 0.5
local CULLED_UPDATE_INTERVAL = 0.75
local BILLBOARD_UPDATE_INTERVAL = 0.25
local CULLED_ROOT_MOVE_THRESHOLD = 25
local SPAWN_AREA_CACHE_SECONDS = 5
local CACHE_CLEANUP_INTERVAL = 2
local MODEL_LIST_CACHE_INTERVAL = 0.25

local LocalPlayer = Players.LocalPlayer
local RoamingFolder: Folder? = workspace:FindFirstChild("RoamingSquishies") :: Folder?
local SpawnBoxesRoot: Instance? = workspace:FindFirstChild("SpawnBoxes")
local CulledFolder: Folder? = ReplicatedStorage:FindFirstChild(CULLED_FOLDER_NAME) :: Folder?
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local AnimationsFolder = AssetsFolder:WaitForChild("Animations")
local BillboardsFolder = AssetsFolder:WaitForChild("Billboards")
local SquishyOverheadTemplate = BillboardsFolder:WaitForChild(SQUISHY_OVERHEAD_NAME) :: BillboardGui
local AnimationCacheByModel: { [Model]: AnimationCache } = {}
local MovementCacheByModel: { [Model]: MovementCache } = {}
local BillboardCacheByModel: { [Model]: BillboardCache } = {}
local SpawnAreaCacheState: SpawnAreaCache? = nil
local ModelSpawnAreaCacheByModel: { [Model]: ModelSpawnAreaCache } = {}
local RuntimeByModel: { [Model]: RuntimeState } = {}
local HiddenPartStatesByModel: { [Model]: { [BasePart]: HiddenPartState } } = setmetatable({}, { __mode = "k" }) :: any
local ActiveModelListCache: ModelListCache? = nil
local CulledModelListCache: ModelListCache? = nil
local LastCacheCleanupAt = 0
local LastCulledRootPosition: Vector3? = nil

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

local function Get_Roam_Start_Position(Model: Model): Vector3?
    local StartX = Model:GetAttribute(ROAM_START_X_ATTRIBUTE)
    local StartY = Model:GetAttribute(ROAM_START_Y_ATTRIBUTE)
    local StartZ = Model:GetAttribute(ROAM_START_Z_ATTRIBUTE)

    if type(StartX) ~= "number" or type(StartY) ~= "number" or type(StartZ) ~= "number" then
        return nil
    end

    return Vector3.new(StartX, StartY, StartZ)
end

local function Positions_Match(Left: Vector3?, Right: Vector3?): boolean
    if Left == nil or Right == nil then
        return Left == Right
    end

    return (Left - Right).Magnitude <= 0.001
end

local function Face_Player_CFrame(Position: Vector3, RootPosition: Vector3, FallbackRotation: CFrame): CFrame
    local LookAtPosition = Vector3.new(RootPosition.X, Position.Y, RootPosition.Z)

    if (LookAtPosition - Position).Magnitude < 0.05 then
        return CFrame.new(Position) * FallbackRotation
    end

    return CFrame.lookAt(Position, LookAtPosition)
end

local function Apply_Pull_To_CFrame(Model: Model, BaseCFrame: CFrame): CFrame
    local TargetUserId = Model:GetAttribute(PULL_TARGET_USER_ID_ATTRIBUTE)
    local PullProgress = Model:GetAttribute(PULL_PROGRESS_ATTRIBUTE)
    local AnchorPosition = Get_Pull_Anchor_Position(Model)

    if type(TargetUserId) ~= "number" or type(PullProgress) ~= "number" then
        if AnchorPosition then
            local GroundedAnchor = Get_Grounded_Position(AnchorPosition, BaseCFrame.Position.Y)

            return CFrame.new(GroundedAnchor) * BaseCFrame.Rotation
        end

        return BaseCFrame
    end

    local Player = Players:GetPlayerByUserId(TargetUserId)
    local Character = Player and Player.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if not Root or not Root:IsA("BasePart") then
        return BaseCFrame
    end

    local CurrentPosition = AnchorPosition or BaseCFrame.Position
    CurrentPosition = Get_Grounded_Position(CurrentPosition, BaseCFrame.Position.Y)

    local RootPosition = Root.Position
    local FlatOffset = Vector3.new(CurrentPosition.X - RootPosition.X, 0, CurrentPosition.Z - RootPosition.Z)
    local PullAlpha = math.clamp(PullProgress, 0, 1)

    if PullAlpha <= 0 then
        return Face_Player_CFrame(CurrentPosition, RootPosition, BaseCFrame.Rotation)
    end

    if FlatOffset.Magnitude < 0.05 then
        return Face_Player_CFrame(CurrentPosition, RootPosition, BaseCFrame.Rotation)
    end

    local PullPosition = RootPosition + FlatOffset.Unit * CatchConfig.CatchPullStopDistance
    PullPosition = Get_Grounded_Position(PullPosition, CurrentPosition.Y)

    local BlendedPosition = CurrentPosition:Lerp(PullPosition, PullAlpha)
    return Face_Player_CFrame(BlendedPosition, RootPosition, BaseCFrame.Rotation)
end

local function Get_Roaming_Folder(): Folder?
    if RoamingFolder and RoamingFolder.Parent then
        return RoamingFolder
    end

    RoamingFolder = workspace:FindFirstChild("RoamingSquishies") :: Folder?

    return RoamingFolder
end

local function Get_Culled_Folder(): Folder
    if CulledFolder and CulledFolder.Parent then
        return CulledFolder
    end

    local Existing = ReplicatedStorage:FindFirstChild(CULLED_FOLDER_NAME)

    if Existing and Existing:IsA("Folder") then
        CulledFolder = Existing
        return Existing
    end

    local Folder = Instance.new("Folder")

    Folder.Name = CULLED_FOLDER_NAME
    Folder.Parent = ReplicatedStorage
    CulledFolder = Folder

    return Folder
end

local function Get_Local_Root_Position(): Vector3?
    local Character = LocalPlayer and LocalPlayer.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if Root and Root:IsA("BasePart") then
        return Root.Position
    end

    return nil
end

local function Should_Hide_For_Tutorial(): boolean
    return false
end

local function Should_Cull_Position(Position: Vector3, RootPosition: Vector3?): boolean
    if not RootPosition then
        return false
    end

    return (Position - RootPosition).Magnitude > CULL_DISTANCE
end

local function Sort_Spawn_Area_Parts(Parts: { BasePart })
    table.sort(Parts, function(Left, Right)
        local LeftIndex = Left:GetAttribute("SpawnAreaIndex")
        local RightIndex = Right:GetAttribute("SpawnAreaIndex")

        if type(LeftIndex) == "number" and type(RightIndex) == "number" and LeftIndex ~= RightIndex then
            return LeftIndex < RightIndex
        end

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

local function Get_Spawn_Boxes_Root(): Folder?
    if SpawnBoxesRoot and SpawnBoxesRoot.Parent and SpawnBoxesRoot:IsA("Folder") then
        return SpawnBoxesRoot
    end

    SpawnBoxesRoot = workspace:FindFirstChild("SpawnBoxes")

    if SpawnBoxesRoot and SpawnBoxesRoot:IsA("Folder") then
        return SpawnBoxesRoot
    end

    return nil
end

local function Build_Spawn_Area_Cache(Root: Folder): SpawnAreaCache
    local Parts = {}
    local ByGuid = {}
    local ByIndex = {}

    for _, Child in Root:GetChildren() do
        if Child:IsA("BasePart") then
            table.insert(Parts, Child)
        end
    end

    Sort_Spawn_Area_Parts(Parts)

    for Index, Part in Parts do
        ByGuid[Part.Name] = Part

        local AreaIndex = Part:GetAttribute("SpawnAreaIndex")

        if type(AreaIndex) == "number" then
            ByIndex[math.floor(AreaIndex)] = Part
        end

        if not ByIndex[Index] then
            ByIndex[Index] = Part
        end
    end

    return {
        Root = Root,
        BuiltAt = os.clock(),
        Parts = Parts,
        ByGuid = ByGuid,
        ByIndex = ByIndex,
    }
end

local function Get_Spawn_Area_Cache(): SpawnAreaCache?
    local Root = Get_Spawn_Boxes_Root()

    if not Root then
        SpawnAreaCacheState = nil
        return nil
    end

    local Cache = SpawnAreaCacheState

    if Cache and Cache.Root == Root and os.clock() - Cache.BuiltAt < SPAWN_AREA_CACHE_SECONDS then
        return Cache
    end

    Cache = Build_Spawn_Area_Cache(Root)
    SpawnAreaCacheState = Cache

    return Cache
end

local function Get_Spawn_Area_For_Model(Model: Model): BasePart?
    local Cache = Get_Spawn_Area_Cache()

    if not Cache or #Cache.Parts == 0 then
        return nil
    end

    local AreaGuid = Model:GetAttribute(ROAM_AREA_GUID_ATTRIBUTE)
    local AreaGuidString = if type(AreaGuid) == "string" then AreaGuid else nil
    local AreaIndex = Model:GetAttribute(ROAM_AREA_INDEX_ATTRIBUTE)
    local AreaIndexNumber = if type(AreaIndex) == "number" then math.floor(AreaIndex) else nil
    local ModelCache = ModelSpawnAreaCacheByModel[Model]

    if
        ModelCache
        and ModelCache.AreaGuid == AreaGuidString
        and ModelCache.AreaIndex == AreaIndexNumber
        and ModelCache.Part
        and ModelCache.Part.Parent
    then
        return ModelCache.Part
    end

    local Part: BasePart? = nil

    if AreaGuidString then
        Part = Cache.ByGuid[AreaGuidString]
    end

    if not Part and AreaIndexNumber then
        Part = Cache.ByIndex[AreaIndexNumber]
    end

    ModelSpawnAreaCacheByModel[Model] = {
        AreaGuid = AreaGuidString,
        AreaIndex = AreaIndexNumber,
        Part = Part,
    }

    return Part
end

local function Get_Animator(Model: Model): Animator?
    local AnimationController = Model:FindFirstChildOfClass("AnimationController")

    if not AnimationController then
        return nil
    end

    local Animator = AnimationController:FindFirstChildOfClass("Animator")

    if not Animator then
        Animator = Instance.new("Animator")
        Animator.Parent = AnimationController
    end

    return Animator
end

local function Load_Animation(Animator: Animator, Kind: SquishyKind, AnimationName: string): AnimationTrack?
    local Animation = AnimationsFolder:FindFirstChild(`{Kind} {AnimationName}`)

    if not Animation or not Animation:IsA("Animation") then
        return nil
    end

    local Track = Animator:LoadAnimation(Animation)
    Track.Looped = true

    return Track
end

local function Stop_Animation_Cache(Cache: AnimationCache)
    if Cache.IdleTrack then
        Cache.IdleTrack:Stop(ANIMATION_FADE_TIME)
    end

    if Cache.WalkTrack then
        Cache.WalkTrack:Stop(ANIMATION_FADE_TIME)
    end
end

local function Stop_Model_Animations(Model: Model)
    local Cache = AnimationCacheByModel[Model]

    if Cache then
        Stop_Animation_Cache(Cache)
    end
end

local function Set_Model_Tutorial_Hidden(Model: Model, Hidden: boolean)
    local HiddenStates = HiddenPartStatesByModel[Model]

    if Hidden then
        if not HiddenStates then
            HiddenStates = {}
            HiddenPartStatesByModel[Model] = HiddenStates
        end

        for _, Descendant in Model:GetDescendants() do
            if not Descendant:IsA("BasePart") then
                continue
            end

            if not HiddenStates[Descendant] then
                HiddenStates[Descendant] = {
                    LocalTransparencyModifier = Descendant.LocalTransparencyModifier,
                    CanQuery = Descendant.CanQuery,
                }
            end

            Descendant.LocalTransparencyModifier = 1
            Descendant.CanQuery = false
        end

        Stop_Model_Animations(Model)
        return
    end

    if not HiddenStates then
        return
    end

    for Part, State in HiddenStates do
        if not Part.Parent then
            continue
        end

        Part.LocalTransparencyModifier = State.LocalTransparencyModifier
        Part.CanQuery = State.CanQuery
    end

    HiddenPartStatesByModel[Model] = nil
end

local function Get_Animation_Cache(Model: Model, Kind: SquishyKind): AnimationCache?
    local Cache = AnimationCacheByModel[Model]

    if Cache and Cache.Kind == Kind then
        return Cache
    end

    if Cache then
        Stop_Animation_Cache(Cache)
    end

    local Animator = Get_Animator(Model)

    if not Animator then
        return nil
    end

    Cache = {
        Kind = Kind,
        IdleTrack = Load_Animation(Animator, Kind, "Idle"),
        WalkTrack = Load_Animation(Animator, Kind, "Walk"),
    }
    AnimationCacheByModel[Model] = Cache

    return Cache
end

local function Update_Animation(Model: Model, Kind: SquishyKind, IsWalking: boolean)
    local Cache = Get_Animation_Cache(Model, Kind)

    if not Cache then
        return
    end

    local Track_To_Play = if IsWalking then Cache.WalkTrack else Cache.IdleTrack
    local Track_To_Stop = if IsWalking then Cache.IdleTrack else Cache.WalkTrack

    if Track_To_Stop and Track_To_Stop.IsPlaying then
        Track_To_Stop:Stop(ANIMATION_FADE_TIME)
    end

    if Track_To_Play and not Track_To_Play.IsPlaying then
        Track_To_Play:Play(ANIMATION_FADE_TIME)
    end

    if Cache.IdleTrack then
        Cache.IdleTrack:AdjustSpeed(IDLE_ANIMATION_SPEED)
    end

    if Cache.WalkTrack then
        Cache.WalkTrack:AdjustSpeed(WALK_ANIMATION_SPEED)
    end
end

local function Cleanup_Animation_Cache()
    for Model, Cache in AnimationCacheByModel do
        if Model.Parent then
            continue
        end

        Stop_Animation_Cache(Cache)
        AnimationCacheByModel[Model] = nil
    end
end

local function Cleanup_Movement_Cache()
    for Model in MovementCacheByModel do
        if Model.Parent then
            continue
        end

        MovementCacheByModel[Model] = nil
    end
end

local function Get_Attribute_Number(Model: Model, Attribute: string): number?
    local Value = Model:GetAttribute(Attribute)

    if type(Value) == "number" then
        return Value
    end

    return nil
end

local function Get_Attribute_String(Model: Model, Attribute: string): string?
    local Value = Model:GetAttribute(Attribute)

    if type(Value) == "string" then
        return Value
    end

    return nil
end

local function Find_Primary_Base_Part(Model: Model): BasePart?
    if Model.PrimaryPart then
        return Model.PrimaryPart
    end

    return Model:FindFirstChildWhichIsA("BasePart", true)
end

local function Get_Billboard_Attachment(Model: Model): Attachment?
    local ExistingAttachment = Model:FindFirstChild("Attachment", true)

    if ExistingAttachment and ExistingAttachment:IsA("Attachment") then
        return ExistingAttachment
    end

    local RootPart = Find_Primary_Base_Part(Model)

    if not RootPart then
        return nil
    end

    local FallbackAttachment = RootPart:FindFirstChild(BILLBOARD_ATTACHMENT_FALLBACK_NAME)

    if FallbackAttachment and FallbackAttachment:IsA("Attachment") then
        return FallbackAttachment
    end

    FallbackAttachment = Instance.new("Attachment")
    FallbackAttachment.Name = BILLBOARD_ATTACHMENT_FALLBACK_NAME
    FallbackAttachment.Parent = RootPart

    return FallbackAttachment
end

local function Find_Text_Label(Root: Instance, Name: string): TextLabel?
    local DirectChild = Root:FindFirstChild(Name)

    if DirectChild and DirectChild:IsA("TextLabel") then
        return DirectChild
    end

    for _, Descendant in Root:GetDescendants() do
        if Descendant.Name == Name and Descendant:IsA("TextLabel") then
            return Descendant
        end
    end

    return nil
end

local function Find_Gui_Object(Root: Instance, Name: string): GuiObject?
    local DirectChild = Root:FindFirstChild(Name)

    if DirectChild and DirectChild:IsA("GuiObject") then
        return DirectChild
    end

    for _, Descendant in Root:GetDescendants() do
        if Descendant.Name == Name and Descendant:IsA("GuiObject") then
            return Descendant
        end
    end

    return nil
end

local function Find_Field_Label(Root: Instance, Name: string): TextLabel?
    local FieldObject = Find_Gui_Object(Root, Name)

    if FieldObject then
        if FieldObject:IsA("TextLabel") then
            return FieldObject
        end

        local NestedLabel = FieldObject:FindFirstChildWhichIsA("TextLabel", true)

        if NestedLabel then
            return NestedLabel
        end
    end

    return Find_Text_Label(Root, Name)
end

local function Apply_Rarity_Gradient(Label: TextLabel, Rarity: string?)
    RarityGradients.ApplyToText(Label, Rarity)
end

local function Apply_Name_Mutation_Gradient(Label: TextLabel, Kind: string?, Mutation: string?)
    if Mutations.Normalize(Kind, Mutation) == Mutations.Normal then
        RarityGradients.ClearFromText(Label)
        return
    end

    RarityGradients.ApplyToText(Label, Mutation)
end

local function Get_Or_Create_Billboard_Cache(Model: Model): BillboardCache?
    local Cache = BillboardCacheByModel[Model]

    if Cache and Cache.Billboard.Parent then
        return Cache
    end

    local Attachment = Get_Billboard_Attachment(Model)

    if not Attachment then
        return nil
    end

    local Billboard = Attachment:FindFirstChild(SQUISHY_OVERHEAD_NAME)

    if not Billboard or not Billboard:IsA("BillboardGui") then
        Billboard = SquishyOverheadTemplate:Clone()
        Billboard.Name = SQUISHY_OVERHEAD_NAME
        Billboard.Parent = Attachment
    end

    Billboard.MaxDistance = Config.Overheads.RoamingMaxDistance

    Cache = {
        Billboard = Billboard,
        NameObject = Find_Gui_Object(Billboard, "Name"),
        RarityObject = Find_Gui_Object(Billboard, "Rarity"),
        StrengthObject = Find_Gui_Object(Billboard, "Strength"),
        TimerObject = Find_Gui_Object(Billboard, "Timer"),
        IncomePerSecObject = Find_Gui_Object(Billboard, "IncomePerSec")
            or Find_Gui_Object(Billboard, "Income Per Sec")
            or Find_Gui_Object(Billboard, "Income"),
        WeightObject = Find_Gui_Object(Billboard, "Weight"),
        NameLabel = Find_Field_Label(Billboard, "Name"),
        RarityLabel = Find_Field_Label(Billboard, "Rarity"),
        StrengthLabel = Find_Field_Label(Billboard, "Strength"),
        TimerLabel = Find_Field_Label(Billboard, "Timer"),
        LastNameText = nil,
        LastRarity = nil,
        LastStrengthText = nil,
        LastTimerText = nil,
    }

    BillboardCacheByModel[Model] = Cache

    return Cache
end

local function Format_Strength(Strength: number?): string
    if type(Strength) ~= "number" or Strength ~= Strength then
        return "💪 --"
    end

    return `💪 {Util.Abbreviate_Number(math.max(0, math.floor(Strength + 0.5)), 1)}`
end

local function Format_Time_Remaining(Seconds: number?): string
    if type(Seconds) ~= "number" or Seconds ~= Seconds then
        return "⏰ --"
    end

    local TotalSeconds = math.max(0, math.ceil(Seconds))
    local Hours = math.floor(TotalSeconds / 3_600)
    local Minutes = math.floor((TotalSeconds % 3_600) / 60)
    local RemainingSeconds = TotalSeconds % 60

    if Hours > 0 then
        return string.format("⏰ %dh %02dm", Hours, Minutes)
    end

    if Minutes > 0 then
        return string.format("⏰ %dm %02ds", Minutes, RemainingSeconds)
    end

    return `⏰ {RemainingSeconds}s`
end

local function Get_Display_Name(Model: Model): string
    return Get_Attribute_String(Model, "Name") or "Squishy"
end

local function Get_Display_Name_With_Kind(Model: Model): string
    local Name = Get_Display_Name(Model)
    local Kind = Get_Attribute_String(Model, "Kind")
    local Mutation = Get_Attribute_String(Model, "Mutation")

    if type(Kind) ~= "string" or Kind == "" then
        return Mutations.FormatDisplayName(Kind, Name, Mutation)
    end

    return Mutations.FormatDisplayName(Kind, Name, Mutation)
end

local function Get_Despawn_Time(Model: Model): number?
    local DespawnTime = Get_Attribute_Number(Model, "DespawnTime")

    if DespawnTime then
        return DespawnTime
    end

    local SpawnTime = Get_Attribute_Number(Model, "SpawnTime")
    local Lifetime = Get_Attribute_Number(Model, "Lifetime")

    if not SpawnTime or not Lifetime then
        return nil
    end

    return SpawnTime + Lifetime
end

local function Set_Label_Text(Label: TextLabel?, Text: string, PreviousText: string?): string
    if Label and Text ~= PreviousText then
        Label.Text = Text
    end

    return Text
end

local function Set_Field_Visible(Object: GuiObject?, Visible: boolean)
    if Object then
        Object.Visible = Visible

        if Visible then
            if Object:IsA("TextLabel") then
                Object.Visible = true
            end

            for _, Descendant in Object:GetDescendants() do
                if Descendant:IsA("TextLabel") then
                    Descendant.Visible = true
                end
            end
        end
    end
end

local function Update_Roaming_Billboard(Model: Model, Now: number)
    local Cache = Get_Or_Create_Billboard_Cache(Model)

    if not Cache then
        return
    end

    Cache.Billboard.Enabled = true

    local Rarity = Get_Attribute_String(Model, "Rarity") or "Common"
    local Kind = Get_Attribute_String(Model, "Kind")
    local Mutation = Get_Attribute_String(Model, "Mutation")
    local Strength = Get_Attribute_Number(Model, "Strength")
    local DespawnTime = Get_Despawn_Time(Model)
    local TimerText = Format_Time_Remaining(if DespawnTime then DespawnTime - Now else nil)
    local StrengthText = Format_Strength(Strength)
    local NameText = Get_Display_Name_With_Kind(Model)

    Set_Field_Visible(Cache.NameObject, true)
    Set_Field_Visible(Cache.RarityObject, true)
    Set_Field_Visible(Cache.StrengthObject, true)
    Set_Field_Visible(Cache.TimerObject, true)
    Set_Field_Visible(Cache.IncomePerSecObject, false)
    Set_Field_Visible(Cache.WeightObject, false)

    Cache.LastNameText = Set_Label_Text(Cache.NameLabel, NameText, Cache.LastNameText)
    if Cache.NameLabel then
        Apply_Name_Mutation_Gradient(Cache.NameLabel, Kind, Mutation)
    end
    Cache.LastStrengthText = Set_Label_Text(Cache.StrengthLabel, StrengthText, Cache.LastStrengthText)
    Cache.LastTimerText = Set_Label_Text(Cache.TimerLabel, TimerText, Cache.LastTimerText)

    if Cache.RarityLabel and Cache.LastRarity ~= Rarity then
        Cache.RarityLabel.Text = Rarity
        Apply_Rarity_Gradient(Cache.RarityLabel, Rarity)
        Cache.LastRarity = Rarity
    end
end

local function Set_Roaming_Billboard_Enabled(Model: Model, Enabled: boolean)
    local Cache = BillboardCacheByModel[Model]

    if Cache and Cache.Billboard.Parent then
        Cache.Billboard.Enabled = Enabled
    end
end

local function Cleanup_Billboard_Cache()
    for Model, Cache in BillboardCacheByModel do
        if Model.Parent and Cache.Billboard.Parent then
            continue
        end

        BillboardCacheByModel[Model] = nil
    end
end

local function Cleanup_Runtime_Cache()
    for Model in RuntimeByModel do
        if Model.Parent then
            continue
        end

        RuntimeByModel[Model] = nil
        HiddenPartStatesByModel[Model] = nil
    end
end

local function Cleanup_Spawn_Area_Model_Cache()
    for Model in ModelSpawnAreaCacheByModel do
        if Model.Parent then
            continue
        end

        ModelSpawnAreaCacheByModel[Model] = nil
    end
end

local function Cleanup_Caches(Now: number)
    if Now - LastCacheCleanupAt < CACHE_CLEANUP_INTERVAL then
        return
    end

    LastCacheCleanupAt = Now

    Cleanup_Animation_Cache()
    Cleanup_Movement_Cache()
    Cleanup_Billboard_Cache()
    Cleanup_Runtime_Cache()
    Cleanup_Spawn_Area_Model_Cache()
end

local function Get_Runtime_State(Model: Model): RuntimeState
    local Runtime = RuntimeByModel[Model]

    if Runtime then
        return Runtime
    end

    Runtime = {
        NextUpdateAt = 0,
        LastBillboardAt = 0,
        LastPosition = nil,
        LastLod = nil,
    }
    RuntimeByModel[Model] = Runtime

    return Runtime
end

local function Get_Distance_To_Root(Position: Vector3, RootPosition: Vector3?): number
    if not RootPosition then
        return math.huge
    end

    return (Position - RootPosition).Magnitude
end

local function Get_Lod(Position: Vector3, RootPosition: Vector3?, IsCulled: boolean): string
    if IsCulled then
        return "Culled"
    end

    local Distance = Get_Distance_To_Root(Position, RootPosition)

    if Distance <= SUPER_CLOSE_DISTANCE then
        return "SuperClose"
    end

    if Distance <= NEAR_DISTANCE then
        return "Near"
    end

    if Distance <= MID_DISTANCE then
        return "Mid"
    end

    return "Far"
end

local function Get_Update_Interval(Position: Vector3, RootPosition: Vector3?, IsCulled: boolean): number
    local Lod = Get_Lod(Position, RootPosition, IsCulled)

    if Lod == "Culled" then
        return CULLED_UPDATE_INTERVAL
    end

    if Lod == "SuperClose" then
        return SUPER_CLOSE_UPDATE_INTERVAL
    end

    if Lod == "Near" then
        return NEAR_UPDATE_INTERVAL
    end

    if Lod == "Mid" then
        return MID_UPDATE_INTERVAL
    end

    return FAR_UPDATE_INTERVAL
end

local function Is_Model_Pulling(Model: Model): boolean
    return type(Model:GetAttribute(PULL_PROGRESS_ATTRIBUTE)) == "number"
end

local function Should_Update_Roaming_Model(
    Model: Model,
    Runtime: RuntimeState,
    Now: number,
    RootPosition: Vector3?,
    IsCulled: boolean,
    ForceCulledCheck: boolean
): boolean
    if Is_Model_Pulling(Model) then
        return true
    end

    if ForceCulledCheck and IsCulled then
        Runtime.NextUpdateAt = 0
    end

    if Now < Runtime.NextUpdateAt then
        return false
    end

    if Runtime.LastPosition then
        Runtime.NextUpdateAt = Now + Get_Update_Interval(Runtime.LastPosition, RootPosition, IsCulled)
    end

    return true
end

local function Build_Model_List_Cache(Container: Instance, Now: number): ModelListCache
    local Models = {}

    for _, Child in Container:GetChildren() do
        if Child:IsA("Model") then
            table.insert(Models, Child)
        end
    end

    return {
        Container = Container,
        BuiltAt = Now,
        Models = Models,
    }
end

local function Get_Model_List(Container: Instance, Now: number, IsCulled: boolean): { Model }
    local Cache = if IsCulled then CulledModelListCache else ActiveModelListCache

    if Cache and Cache.Container == Container and Now - Cache.BuiltAt < MODEL_LIST_CACHE_INTERVAL then
        return Cache.Models
    end

    Cache = Build_Model_List_Cache(Container, Now)

    if IsCulled then
        CulledModelListCache = Cache
    else
        ActiveModelListCache = Cache
    end

    return Cache.Models
end

local function Create_Movement_Cache(
    Seed: number,
    ServerEntity: number,
    SpawnTime: number,
    BaseY: number,
    SpawnBoxPart: BasePart,
    Now: number,
    StartPosition: Vector3?
): MovementCache?
    local CurrentPosition = StartPosition
        or RoamingMovement.GetInitialPosition(Seed, ServerEntity, SpawnTime, SpawnBoxPart, BaseY)
    local JourneyIndex = 1
    local JourneyStartTime = SpawnTime
    local Segment = RoamingMovement.GetJourneySegment(
        Seed,
        ServerEntity,
        SpawnTime,
        JourneyIndex,
        CurrentPosition,
        SpawnBoxPart,
        BaseY
    )

    while Now - JourneyStartTime > Segment.IdleDuration + Segment.WalkDuration do
        JourneyStartTime += Segment.IdleDuration + Segment.WalkDuration
        CurrentPosition = Segment.To
        JourneyIndex += 1
        Segment = RoamingMovement.GetJourneySegment(
            Seed,
            ServerEntity,
            SpawnTime,
            JourneyIndex,
            CurrentPosition,
            SpawnBoxPart,
            BaseY
        )

        if JourneyIndex > 256 then
            return nil
        end
    end

    return {
        ServerEntity = ServerEntity,
        SpawnTime = SpawnTime,
        BaseY = BaseY,
        SpawnBoxPart = SpawnBoxPart,
        StartPosition = StartPosition,
        JourneyIndex = JourneyIndex,
        JourneyStartTime = JourneyStartTime,
        Segment = Segment,
        LastUpdateTime = nil,
    }
end

local function Get_Movement_Cache(
    Model: Model,
    Seed: number,
    ServerEntity: number,
    SpawnTime: number,
    BaseY: number,
    SpawnBoxPart: BasePart,
    Now: number,
    StartPosition: Vector3?
): MovementCache?
    local Cache = MovementCacheByModel[Model]

    if
        Cache
        and Cache.ServerEntity == ServerEntity
        and Cache.SpawnTime == SpawnTime
        and Cache.BaseY == BaseY
        and Cache.SpawnBoxPart == SpawnBoxPart
        and Positions_Match(Cache.StartPosition, StartPosition)
    then
        return Cache
    end

    Cache = Create_Movement_Cache(Seed, ServerEntity, SpawnTime, BaseY, SpawnBoxPart, Now, StartPosition)
    MovementCacheByModel[Model] = Cache

    return Cache
end

local function Advance_Movement_Cache(Cache: MovementCache, Seed: number, SpawnBoxPart: BasePart, Now: number)
    for _ = 1, MAX_JOURNEY_ADVANCES_PER_STEP do
        local SegmentDuration = Cache.Segment.IdleDuration + Cache.Segment.WalkDuration

        if Now - Cache.JourneyStartTime <= SegmentDuration then
            return
        end

        Cache.JourneyStartTime += SegmentDuration
        Cache.JourneyIndex += 1
        Cache.Segment = RoamingMovement.GetJourneySegment(
            Seed,
            Cache.ServerEntity,
            Cache.SpawnTime,
            Cache.JourneyIndex,
            Cache.Segment.To,
            SpawnBoxPart,
            Cache.BaseY
        )
    end
end

local function Pivot_With_Smooth_Rotation(
    Model: Model,
    Cache: MovementCache,
    TargetCFrame: CFrame,
    Now: number,
    SmoothPosition: boolean
)
    if not Cache.LastUpdateTime then
        Cache.LastUpdateTime = Now
        Model:PivotTo(TargetCFrame)
        return
    end

    local DeltaTime = math.clamp(Now - Cache.LastUpdateTime, 0, 0.1)
    local RotationAlpha = 1 - math.exp(-ROTATION_RESPONSIVENESS * DeltaTime)
    local PositionAlpha = if SmoothPosition
        then 1 - math.exp(-CatchConfig.CatchPullPositionResponsiveness * DeltaTime)
        else 1
    local CurrentPivot = Model:GetPivot()
    local SmoothedPosition = CurrentPivot.Position:Lerp(TargetCFrame.Position, PositionAlpha)
    local SmoothedRotation = CurrentPivot.Rotation:Lerp(TargetCFrame.Rotation, RotationAlpha)

    Cache.LastUpdateTime = Now
    Model:PivotTo(CFrame.new(SmoothedPosition) * SmoothedRotation)
end

local function Get_Roaming_Model_State(Model: Model, Seed: number, Now: number): RoamingModelState?
    local ServerEntity = Get_Attribute_Number(Model, "ServerEntity")
    local Kind = Get_Attribute_String(Model, "Kind")
    local SpawnTime = Get_Attribute_Number(Model, "SpawnTime")
    local Lifetime = Get_Attribute_Number(Model, "Lifetime")
    local BaseY = Get_Attribute_Number(Model, "BaseY")
    local SpawnBoxPart = Get_Spawn_Area_For_Model(Model)
    local StartPosition = Get_Roam_Start_Position(Model)

    if not ServerEntity or not Kind or not SpawnTime or not Lifetime or not BaseY or not SpawnBoxPart then
        return nil
    end

    if Kind ~= "Slime" and Kind ~= "Dumpling" then
        return nil
    end

    if Now < SpawnTime or Now > SpawnTime + Lifetime then
        return nil
    end

    local Cache = Get_Movement_Cache(Model, Seed, ServerEntity, SpawnTime, BaseY, SpawnBoxPart, Now, StartPosition)

    if not Cache then
        return nil
    end

    if Model:GetAttribute(TutorialSteps.StationaryTargetAttribute) == true then
        local StationaryPosition = StartPosition or Model:GetPivot().Position
        local TargetCFrame = Apply_Pull_To_CFrame(Model, CFrame.new(StationaryPosition))
        local PullProgress = Model:GetAttribute(PULL_PROGRESS_ATTRIBUTE)
        local IsPulling = type(PullProgress) == "number"

        return {
            Cache = Cache,
            Kind = Kind :: SquishyKind,
            TargetCFrame = TargetCFrame,
            IsWalking = false,
            IsPulling = IsPulling,
        }
    end

    Advance_Movement_Cache(Cache, Seed, SpawnBoxPart, Now)

    local State = RoamingMovement.GetStateFromSegment(Cache.Segment, Cache.JourneyIndex, Now - Cache.JourneyStartTime)

    if not State then
        return nil
    end

    local TargetCFrame = Apply_Pull_To_CFrame(Model, State.CFrame)
    local PullProgress = Model:GetAttribute(PULL_PROGRESS_ATTRIBUTE)
    local IsPulling = type(PullProgress) == "number"

    return {
        Cache = Cache,
        Kind = Kind :: SquishyKind,
        TargetCFrame = TargetCFrame,
        IsWalking = State.IsWalking,
        IsPulling = IsPulling,
    }
end

local function Cull_Roaming_Model(Model: Model, Culled: Folder)
    if Model.Parent == Culled then
        return
    end

    Stop_Model_Animations(Model)
    Model.Parent = Culled
end

local function Restore_Roaming_Model(Model: Model, Folder: Folder, State: RoamingModelState, Now: number)
    if Model.Parent == Folder then
        return
    end

    Model.Parent = Folder
    Model:PivotTo(State.TargetCFrame)
    State.Cache.LastUpdateTime = Now
end

local function Update_Roaming_Model(
    Model: Model,
    Seed: number,
    Now: number,
    Folder: Folder,
    Culled: Folder,
    RootPosition: Vector3?,
    Runtime: RuntimeState
)
    local State = Get_Roaming_Model_State(Model, Seed, Now)

    if not State then
        Runtime.NextUpdateAt = Now + FAR_UPDATE_INTERVAL
        return
    end

    local TargetPosition = State.TargetCFrame.Position
    Runtime.LastPosition = TargetPosition

    if Should_Hide_For_Tutorial() then
        Set_Roaming_Billboard_Enabled(Model, false)
        Set_Model_Tutorial_Hidden(Model, true)
        Runtime.NextUpdateAt = Now + NEAR_UPDATE_INTERVAL
        return
    end

    Set_Model_Tutorial_Hidden(Model, false)
    EventMutationVFX.Sync(Model, Model:GetAttribute("EventMutations"))

    if Should_Cull_Position(State.TargetCFrame.Position, RootPosition) then
        Runtime.LastLod = "Culled"
        Runtime.NextUpdateAt = Now + CULLED_UPDATE_INTERVAL
        Set_Roaming_Billboard_Enabled(Model, false)
        Cull_Roaming_Model(Model, Culled)
        return
    end

    local WasCulled = Model.Parent == Culled
    local Lod = Get_Lod(TargetPosition, RootPosition, false)
    local ShouldUpdateBillboard = Lod ~= "Far" and Now - Runtime.LastBillboardAt >= BILLBOARD_UPDATE_INTERVAL

    Restore_Roaming_Model(Model, Folder, State, Now)

    if ShouldUpdateBillboard then
        Runtime.LastBillboardAt = Now
        Update_Roaming_Billboard(Model, Now)
    elseif Lod == "Far" then
        Set_Roaming_Billboard_Enabled(Model, false)
    end

    if not WasCulled then
        local PullProgress = Model:GetAttribute(PULL_PROGRESS_ATTRIBUTE)
        local SmoothPullPosition = State.IsPulling and type(PullProgress) == "number" and (PullProgress :: number) < 1

        Pivot_With_Smooth_Rotation(Model, State.Cache, State.TargetCFrame, Now, SmoothPullPosition)
    end

    if Lod == "Far" and not State.IsPulling then
        Stop_Model_Animations(Model)
    else
        Update_Animation(Model, State.Kind, State.IsWalking or State.IsPulling)
    end

    Runtime.LastLod = Lod
    Runtime.NextUpdateAt = Now + Get_Update_Interval(TargetPosition, RootPosition, false)
end

return {
    name = script.Name,
    phase = Phases.Runservice.PreRender,
    system = function()
        local Seed = ReplicatedStorage:GetAttribute(ROAMING_SEED_ATTRIBUTE)
        local Folder = Get_Roaming_Folder()
        local Culled = Get_Culled_Folder()

        if type(Seed) ~= "number" or not Folder then
            return
        end

        local Now = workspace:GetServerTimeNow()
        local RootPosition = Get_Local_Root_Position()
        local ForceCulledCheck = false

        if RootPosition then
            ForceCulledCheck = not LastCulledRootPosition
                or (RootPosition - LastCulledRootPosition).Magnitude >= CULLED_ROOT_MOVE_THRESHOLD

            if ForceCulledCheck then
                LastCulledRootPosition = RootPosition
            end
        end

        for _, Child in Get_Model_List(Folder, Now, false) do
            if Child.Parent == Folder then
                local Runtime = Get_Runtime_State(Child)

                if Should_Update_Roaming_Model(Child, Runtime, Now, RootPosition, false, false) then
                    Update_Roaming_Model(Child, Seed, Now, Folder, Culled, RootPosition, Runtime)
                end
            end
        end

        for _, Child in Get_Model_List(Culled, Now, true) do
            if Child.Parent == Culled then
                local Runtime = Get_Runtime_State(Child)

                if Should_Update_Roaming_Model(Child, Runtime, Now, RootPosition, true, ForceCulledCheck) then
                    Update_Roaming_Model(Child, Seed, Now, Folder, Culled, RootPosition, Runtime)
                end
            end
        end

        Cleanup_Caches(Now)
    end,
}
