local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Network = require(ReplicatedFirst.Network)
local peek = Fusion.peek

local Config = require(ReplicatedStorage.Shared.Config)
local EventMutationVFX = require(script.Parent.Parent.Modules.EventMutationVFX)
local EventMutations = require(ReplicatedStorage.Shared.Modules.EventMutations)
local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local HudPlaceButton = require(script.Parent.Parent.Modules.HudPlaceButton)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local LocalNotifications = require(script.Parent.Parent.Modules.LocalNotifications)
local MapRaycast = require(ReplicatedStorage.Shared.Modules.MapRaycast)
local Phases = require(ReplicatedStorage.Shared.Phases)
local RarityGradients = require(script.Parent.Parent.Modules.RarityGradients)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local SquishyLevels = require(ReplicatedStorage.Shared.Modules.SquishyLevels)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

type PlotSquishyData = {
    Id: string,
    Kind: string,
    Name: string,
    Rarity: string,
    TutorialRole: string?,
    Weight: number,
    Mutation: string,
    EventMutations: { string },
    Level: number,
    XP: number,
    BaseIncomePerSec: number,
    FinalIncomePerSec: number,
    PositionX: number,
    PositionY: number,
    PositionZ: number,
    StoredCash: number,
    LastCashUpdate: number,
    MoveState: string,
    MoveStartX: number,
    MoveStartY: number,
    MoveStartZ: number,
    MoveTargetX: number,
    MoveTargetY: number,
    MoveTargetZ: number,
    MoveStartedAt: number,
    MoveDuration: number,
    IdleUntil: number,
    MoveIndex: number,
}

type AnimationState = {
    Idle: AnimationTrack?,
    Walk: AnimationTrack?,
    IsWalking: boolean?,
}

type PlotSquishyState = {
    ownerUserId: number,
    id: string,
    kind: string,
    name: string,
    rarity: string,
    weight: number,
    mutation: string,
    eventMutations: { string },
    level: number,
    xp: number,
    incomePerSec: number,
    storedCash: number,
    lastCashUpdate: number,
    lastCollectRequestAt: number,
    lastFeedRequestAt: number,
    model: Model,
    baseScale: number,
    bounceSerial: number,
    feedPrompt: ProximityPrompt?,
    feedPromptAttachment: Attachment?,
    feedPromptConnection: RBXScriptConnection?,
    pickupPrompt: ProximityPrompt?,
    pickupPromptAttachment: Attachment?,
    pickupPromptConnection: RBXScriptConnection?,
    modelRadius: number,
    footOffset: number,
    moveState: string,
    moveStart: Vector3,
    moveTarget: Vector3,
    moveStartedAt: number,
    moveDuration: number,
    idleUntil: number,
    moveIndex: number,
    nextMovementUpdateAt: number,
    nextOverheadUpdateAt: number,
    nextCollectCheckAt: number,
    nextFeedPromptUpdateAt: number,
    forceMovementUpdate: boolean,
    animations: AnimationState,
}

type OverheadCache = {
    billboard: BillboardGui,
    nameObject: GuiObject?,
    rarityObject: GuiObject?,
    cashObject: GuiObject?,
    incomePerSecObject: GuiObject?,
    strengthObject: GuiObject?,
    timerObject: GuiObject?,
    weightObject: GuiObject?,
    levelProgressObject: GuiObject?,
    levelObject: GuiObject?,
    nameLabel: TextLabel?,
    rarityLabel: TextLabel?,
    cashLabel: TextLabel?,
    levelLabel: TextLabel?,
    lastNameText: string?,
    lastRarity: string?,
    lastCashText: string?,
    lastLevelText: string?,
}

local LocalPlayer = Players.LocalPlayer
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local AnimationsFolder = AssetsFolder:WaitForChild("Animations")
local BillboardsFolder = AssetsFolder:WaitForChild("Billboards")
local SquishyOverheadTemplate = BillboardsFolder:WaitForChild("SquishyOverhead") :: BillboardGui

local Constants = {
    PLOT_SQUISHY_FOLDER_NAME = "PlotSquishies",
    HIGHLIGHT_NAME = "PlotSquishyHoverHighlight",
    SQUISHY_OVERHEAD_NAME = "SquishyOverhead",
    OVERHEAD_ATTACHMENT_FALLBACK_NAME = "PlotSquishyOverheadAttachment",
    FEED_PROMPT_ATTACHMENT_NAME = "FeedPromptAttachment",
    FEED_PROMPT_NAME = "FeedSquishyPrompt",
    PICKUP_PROMPT_ATTACHMENT_NAME = "PickupPromptAttachment",
    PICKUP_PROMPT_NAME = "PickupSquishyPrompt",
    COLLECT_TOUCH_PADDING_XZ = 1.25,
    COLLECT_TOUCH_PADDING_Y = 3,
    COLLECT_REQUEST_COOLDOWN = 1,
    FEED_REQUEST_COOLDOWN = 0.1,
    FEED_PROMPT_MAX_DISTANCE = 24,
    FEED_PROMPT_HOLD_DURATION = 0.25,
    PICKUP_PROMPT_MAX_DISTANCE = 18,
    PICKUP_PROMPT_HOLD_DURATION = 0,
    SUPER_CLOSE_DISTANCE = 50,
    SUPER_CLOSE_MOVING_UPDATE_INTERVAL = 1 / 60,
    MOVING_UPDATE_INTERVAL = 1 / 30,
    IDLE_UPDATE_INTERVAL = 0.5,
    OVERHEAD_UPDATE_INTERVAL = 0.25,
    COLLECT_CHECK_INTERVAL = 0.1,
    FEED_PROMPT_UPDATE_INTERVAL = 0.2,
    STATE_LIST_REBUILD_INTERVAL = 0.5,
    MAX_STATE_UPDATES_PER_FRAME = 48,
    HOVER_UPDATE_INTERVAL = 1 / 30,
    FOOD_TOSS_DURATION = 0.42,
    FOOD_TOSS_MIN_ARC_HEIGHT = 3,
    FOOD_TOSS_ARC_DISTANCE_SCALE = 0.22,
    FOOD_TOSS_ROTATION_SPEED = Vector3.new(3.5, 4.5, 2),
    CUSTOM_HOTBAR_SLOT_NAMES = table.freeze({
        [3] = "3",
        [4] = "4",
        [5] = "5",
        [6] = "6",
        [7] = "7",
    }),
    MIN_SCALE_WEIGHT = 8,
    MAX_SCALE_WEIGHT = 100,
    MIN_SQUISHY_SCALE = 1,
    MAX_SQUISHY_SCALE = 5,
    RARITY_SCALE_STEP = 0.1,
    WALK_DISTANCE_THRESHOLD = 0.45,
    GROUND_FALLBACK_Y = 14,
    GROUND_RAY_UP = 80,
    GROUND_RAY_DOWN = 240,
    ANIMATION_FADE_TIME = 0.12,
    WALK_ANIMATION_SPEED = 0.8,
    IDLE_ANIMATION_SPEED = 1,
    TURN_LERP_ALPHA = 0.14,
    MOVE_STATE_MOVING = "Moving",
    LEVEL_UP_EFFECT_LIFETIME = 5,
    COLLECT_BOUNCE_MIN_CASH = 1,
    SQUISHY_BOUNCE_SCALE_MULTIPLIER = 1.12,
    SQUISHY_BOUNCE_UP_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    SQUISHY_BOUNCE_DOWN_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    RARITY_SCALE_INDEX = table.freeze({
        Common = 0,
        Rare = 1,
        Epic = 2,
        Legendary = 3,
        Secret = 4,
        Prismatic = 5,
        Divine = 6,
        Exotic = 7,
        Transcended = 8,
    }),
}
local StatesByOwner: { [number]: { [string]: PlotSquishyState } } = {}
local DidRequestSync = false
local PlotSquishyFolder: Folder? = nil
local HoveredState: PlotSquishyState? = nil
local HoverHighlight: Highlight? = nil
local OverheadCacheByModel: { [Model]: OverheadCache } = {}
local StateUpdateList: { PlotSquishyState } = {}
local StateUpdateCursor = 1
local StateListDirty = true
local LastStateListRebuildAt = 0
local LastHoverUpdateAt = 0
local HoverRaycastParams: RaycastParams? = nil
local HoverRaycastFolder: Folder? = nil
local CurrentUpdateNow = 0
local CachedFoodStateAt = -1
local CachedEquippedFoodItemId: string? = nil
local PendingReturnedEquipItemId: string? = nil
local PendingReturnedEquipStartedAt = 0
local Is_Food_Equipped: (() -> boolean)? = nil
local Update_Feed_Prompt: ((PlotSquishyState) -> ())? = nil
local Update_Pickup_Prompt: ((PlotSquishyState) -> ())? = nil
local Get_Current_Feed_Prompt_Signature: (() -> string)? = nil
local LastFeedPromptSignature = ""

local RETURN_EQUIP_TIMEOUT = 5

local function Get_Folder(): Folder
    if PlotSquishyFolder and PlotSquishyFolder.Parent then
        return PlotSquishyFolder
    end

    local Existing = workspace:FindFirstChild(Constants.PLOT_SQUISHY_FOLDER_NAME)

    if Existing and Existing:IsA("Folder") then
        PlotSquishyFolder = Existing
        return Existing
    end

    local Folder = Instance.new("Folder")
    Folder.Name = Constants.PLOT_SQUISHY_FOLDER_NAME
    Folder.Parent = workspace
    PlotSquishyFolder = Folder

    return Folder
end

local function Get_Scale_From_Weight(Weight: number): number
    local ClampedWeight = math.clamp(Weight, Constants.MIN_SCALE_WEIGHT, Constants.MAX_SCALE_WEIGHT)
    local Alpha = (ClampedWeight - Constants.MIN_SCALE_WEIGHT)
        / (Constants.MAX_SCALE_WEIGHT - Constants.MIN_SCALE_WEIGHT)

    return Constants.MIN_SQUISHY_SCALE + Alpha * (Constants.MAX_SQUISHY_SCALE - Constants.MIN_SQUISHY_SCALE)
end

local function Get_Rarity_Scale_Boost(Rarity: string): number
    return (Constants.RARITY_SCALE_INDEX[Rarity] or 0) * Constants.RARITY_SCALE_STEP
end

local function Get_Model_Scale(Weight: number, Rarity: string, Level: number): number
    return Get_Scale_From_Weight(Weight) + Get_Rarity_Scale_Boost(Rarity) + SquishyLevels.GetScaleBonus(Level)
end

local function Get_Tutorial_Step_From_Fusion(): number?
    if peek(FusionValues.TutorialStepReceived) ~= true then
        return nil
    end

    return TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep))
end

local function Is_Tutorial_Strong_Feed_Target(State: PlotSquishyState): boolean
    local Step = Get_Tutorial_Step_From_Fusion()

    return Step == TutorialSteps.FeedStrong and State.model:GetAttribute("TutorialRole") == TutorialSteps.StrongRole
end

local function Is_Tutorial_Blocking_Feed_Target(State: PlotSquishyState): boolean
    local Step = Get_Tutorial_Step_From_Fusion()

    return Step ~= nil and not TutorialSteps.Is_Complete(Step) and not Is_Tutorial_Strong_Feed_Target(State)
end

local function Scale_Model(Model: Model, Scale: number)
    pcall(function()
        Model:ScaleTo(Scale)
    end)
end

local function Get_Model_Effect_Part(Model: Model): BasePart?
    local PrimaryPart = Model.PrimaryPart

    if PrimaryPart and PrimaryPart:IsA("BasePart") then
        return PrimaryPart
    end

    return Model:FindFirstChildWhichIsA("BasePart", true)
end

local function Get_Confetti_Template(): Attachment?
    local EffectsFolder = AssetsFolder:FindFirstChild("Effects")
    local VFXFolder = AssetsFolder:FindFirstChild("VFX")
    local Template = (EffectsFolder and EffectsFolder:FindFirstChild("Confetti"))
        or (VFXFolder and VFXFolder:FindFirstChild("Confetti"))

    if Template and Template:IsA("Attachment") then
        return Template
    end

    return nil
end

local function Get_Confetti_Sound_Template(): Sound?
    local WorldSounds = SoundService:FindFirstChild("World")
    local AssetSounds = AssetsFolder:FindFirstChild("Sounds")
    local AssetWorldSounds = AssetSounds and AssetSounds:FindFirstChild("World")
    local Template = (WorldSounds and WorldSounds:FindFirstChild("Confetti"))
        or (AssetWorldSounds and AssetWorldSounds:FindFirstChild("Confetti"))

    if Template and Template:IsA("Sound") then
        return Template
    end

    return nil
end

local function Emit_Attachment(Attachment: Attachment)
    for _, Inst in Attachment:GetDescendants() do
        if not Inst:IsA("ParticleEmitter") then
            continue
        end

        local EmitCount = Inst:GetAttribute("EmitCount")

        Inst:Emit(if type(EmitCount) == "number" then EmitCount else 1)
    end
end

local function Play_Level_Up_Confetti(Model: Model)
    local EffectPart = Get_Model_Effect_Part(Model)

    if not EffectPart then
        return
    end

    local SoundTemplate = Get_Confetti_Sound_Template()

    if SoundTemplate then
        local Sound = SoundTemplate:Clone()

        Sound.Parent = EffectPart
        Sound.PlayOnRemove = true
        Sound:Destroy()
    end

    local EffectTemplate = Get_Confetti_Template()

    if not EffectTemplate then
        return
    end

    local Effect = EffectTemplate:Clone()
    local BoundsCFrame, BoundsSize = Model:GetBoundingBox()
    local EffectPosition = BoundsCFrame.Position + Vector3.new(0, math.max(1, BoundsSize.Y * 0.35), 0)

    Effect.CFrame = EffectPart.CFrame:ToObjectSpace(CFrame.new(EffectPosition))
    Effect.Parent = EffectPart
    Emit_Attachment(Effect)
    Debris:AddItem(Effect, Constants.LEVEL_UP_EFFECT_LIFETIME)
end

local function Play_Squishy_Bounce(State: PlotSquishyState)
    local Model = State.model
    local BaseScale = State.baseScale

    if not Model.Parent or BaseScale <= 0 then
        return
    end

    State.bounceSerial += 1
    local Serial = State.bounceSerial
    local ScaleValue = Instance.new("NumberValue")
    local Connection: RBXScriptConnection? = nil

    ScaleValue.Value = BaseScale
    Connection = ScaleValue.Changed:Connect(function(Value)
        if State.bounceSerial ~= Serial or not Model.Parent then
            return
        end

        Scale_Model(Model, Value)
    end)

    local UpTween = TweenService:Create(ScaleValue, Constants.SQUISHY_BOUNCE_UP_INFO, {
        Value = BaseScale * Constants.SQUISHY_BOUNCE_SCALE_MULTIPLIER,
    })
    local DownTween = TweenService:Create(ScaleValue, Constants.SQUISHY_BOUNCE_DOWN_INFO, {
        Value = BaseScale,
    })

    local function Cleanup()
        if Connection then
            Connection:Disconnect()
            Connection = nil
        end

        ScaleValue:Destroy()
    end

    UpTween.Completed:Connect(function(PlaybackState)
        if State.bounceSerial ~= Serial or not Model.Parent or PlaybackState ~= Enum.PlaybackState.Completed then
            Cleanup()
            return
        end

        DownTween:Play()
    end)

    DownTween.Completed:Connect(function()
        if State.bounceSerial == Serial and Model.Parent then
            Scale_Model(Model, State.baseScale)
        end

        Cleanup()
    end)

    UpTween:Play()
end

local function Get_Debris_Parent(): Instance
    return workspace:FindFirstChild("Debris") or workspace
end

local function Prepare_Food_Toss_Model(Model: Model)
    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Descendant.Anchored = true
            Descendant.CanCollide = false
            Descendant.CanTouch = false
            Descendant.CanQuery = false
            Descendant.Massless = true
        elseif Descendant:IsA("Script") or Descendant:IsA("LocalScript") then
            Descendant:Destroy()
        end
    end

    if not Model.PrimaryPart then
        local PrimaryPart = Model:FindFirstChildWhichIsA("BasePart", true)

        if PrimaryPart then
            Model.PrimaryPart = PrimaryPart
        end
    end
end

local function Get_Character_Hand_Position(): Vector3?
    local Character = LocalPlayer.Character

    if not Character then
        return nil
    end

    local Hand = Character:FindFirstChild("RightHand")
        or Character:FindFirstChild("Right Arm")
        or Character:FindFirstChild("HumanoidRootPart")

    if Hand and Hand:IsA("BasePart") then
        return Hand.Position
    end

    return nil
end

local function Get_Squishy_Toss_Target(State: PlotSquishyState): Vector3
    local BoundsCFrame, BoundsSize = State.model:GetBoundingBox()

    return BoundsCFrame.Position + Vector3.new(0, math.max(0.5, BoundsSize.Y * 0.2), 0)
end

local function Quadratic_Bezier(
    StartPosition: Vector3,
    ControlPosition: Vector3,
    EndPosition: Vector3,
    Alpha: number
): Vector3
    local First = StartPosition:Lerp(ControlPosition, Alpha)
    local Second = ControlPosition:Lerp(EndPosition, Alpha)

    return First:Lerp(Second, Alpha)
end

local function Play_Food_Toss(State: PlotSquishyState, FoodName: string, OnComplete: () -> ()): boolean
    local FoodsFolder = AssetsFolder:FindFirstChild("Foods")
    local Template = FoodsFolder and FoodsFolder:FindFirstChild(FoodName)

    if not Template or not Template:IsA("Model") then
        return false
    end

    local StartPosition = Get_Character_Hand_Position()

    if not StartPosition then
        return false
    end

    local EndPosition = Get_Squishy_Toss_Target(State)
    local Distance = (EndPosition - StartPosition).Magnitude
    local ArcHeight = math.max(Constants.FOOD_TOSS_MIN_ARC_HEIGHT, Distance * Constants.FOOD_TOSS_ARC_DISTANCE_SCALE)
    local ControlPosition = (StartPosition + EndPosition) * 0.5 + Vector3.yAxis * ArcHeight
    local TossModel = Template:Clone()
    local StartCFrame = CFrame.new(StartPosition, EndPosition)
    local Elapsed = 0
    local Connection: RBXScriptConnection? = nil
    local Completed = false

    local function Finish(ShouldFeed: boolean)
        if Completed then
            return
        end

        Completed = true

        if Connection then
            Connection:Disconnect()
            Connection = nil
        end

        if TossModel.Parent then
            TossModel:Destroy()
        end

        if ShouldFeed then
            OnComplete()
        end
    end

    Prepare_Food_Toss_Model(TossModel)
    TossModel:PivotTo(StartCFrame)
    TossModel.Parent = Get_Debris_Parent()

    Connection = RunService.RenderStepped:Connect(function(DeltaTime)
        if not TossModel.Parent or not State.model.Parent then
            Finish(false)
            return
        end

        Elapsed = math.min(Elapsed + DeltaTime, Constants.FOOD_TOSS_DURATION)
        local Alpha = TweenService:GetValue(
            Elapsed / Constants.FOOD_TOSS_DURATION,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )
        local Position = Quadratic_Bezier(StartPosition, ControlPosition, EndPosition, Alpha)
        local NextAlpha = math.min(1, Alpha + 0.03)
        local NextPosition = Quadratic_Bezier(StartPosition, ControlPosition, EndPosition, NextAlpha)
        local Rotation = CFrame.Angles(
            Elapsed * Constants.FOOD_TOSS_ROTATION_SPEED.X,
            Elapsed * Constants.FOOD_TOSS_ROTATION_SPEED.Y,
            Elapsed * Constants.FOOD_TOSS_ROTATION_SPEED.Z
        )
        local Direction = NextPosition - Position
        local CFrameValue = if Direction.Magnitude > 0.001
            then CFrame.lookAt(Position, NextPosition) * Rotation
            else CFrame.new(Position) * Rotation

        TossModel:PivotTo(CFrameValue)

        if Elapsed >= Constants.FOOD_TOSS_DURATION then
            Finish(true)
        end
    end)

    return true
end

local function Find_Gui_Object(Root: Instance, Names: { string }): GuiObject?
    for _, Name in Names do
        local Object = Root:FindFirstChild(Name, true)

        if Object and Object:IsA("GuiObject") then
            return Object
        end
    end

    return nil
end

local function Find_Field_Label(Root: Instance, Names: { string }): TextLabel?
    for _, Name in Names do
        local Object = Root:FindFirstChild(Name, true)

        if Object and Object:IsA("TextLabel") then
            return Object
        end

        if Object and Object:IsA("GuiObject") then
            for _, Descendant in Object:GetDescendants() do
                if Descendant:IsA("TextLabel") then
                    return Descendant
                end
            end
        end
    end

    return nil
end

local function Set_Field_Visible(Object: GuiObject?, Visible: boolean)
    if not Object then
        return
    end

    Object.Visible = Visible

    if not Visible then
        return
    end

    if Object:IsA("TextLabel") then
        Object.Visible = true
    end

    for _, Descendant in Object:GetDescendants() do
        if Descendant:IsA("TextLabel") then
            Descendant.Visible = true
        end
    end
end

local function Apply_Rarity_Gradient(Label: TextLabel, Rarity: string?)
    RarityGradients.ApplyToText(Label, Rarity)
end

local function Apply_Name_Mutation_Gradient(Label: TextLabel, Kind: string, Mutation: string?)
    if InventoryMath.NormalizeMutation(Mutation, Kind) == "Normal" then
        RarityGradients.ClearFromText(Label)
        return
    end

    RarityGradients.ApplyToText(Label, Mutation)
end

local function Format_Cash(Value: number): string
    return "$" .. Util.Abbreviate_Number(math.max(0, math.floor(Value + 0.5)), 1)
end

local function Get_Display_Money_Multiplier(State: PlotSquishyState): number
    if State.ownerUserId ~= LocalPlayer.UserId then
        return 1
    end

    return RobuxProducts.NormalizeMoneyMultiplier(peek(FusionValues.MoneyMultiplier))
end

local function Format_Level_Progress(State: PlotSquishyState): string
    if State.level >= SquishyLevels.MaxLevel then
        return "MAX XP"
    end

    local Required = SquishyLevels.GetRequiredXpForLevel(State.level, State.rarity)

    return `{Util.Abbreviate_Number(State.xp, 1)}/{Util.Abbreviate_Number(Required, 1)} XP`
end

local function Update_Level_Progress(LevelProgressObject: GuiObject?, State: PlotSquishyState)
    if not LevelProgressObject then
        return
    end

    local Progress = SquishyLevels.GetProgress(State.level, State.xp, State.rarity)
    local Fill = LevelProgressObject:FindFirstChild("LevelProgress")

    if Fill and Fill:IsA("GuiObject") then
        Fill.Size = UDim2.new(Progress, 0, Fill.Size.Y.Scale, Fill.Size.Y.Offset)
    end

    local ProgressLabel = Find_Field_Label(LevelProgressObject, { "Timer" })

    if ProgressLabel then
        ProgressLabel.Text = Format_Level_Progress(State)
    end
end

local function Get_Display_Cash(State: PlotSquishyState, Now: number?): number
    local CurrentTime = Now or workspace:GetServerTimeNow()
    local Delta = math.floor(math.max(0, CurrentTime - State.lastCashUpdate))
    local IncomePerSec = State.incomePerSec * Get_Display_Money_Multiplier(State)

    return math.max(0, State.storedCash + IncomePerSec * Delta)
end

local function Prepare_Model(Model: Model)
    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Descendant.Anchored = true
            Descendant.CanCollide = false
            Descendant.CanTouch = false
            Descendant.CanQuery = true
            Descendant.Massless = true
        elseif Descendant:IsA("ParticleEmitter") or Descendant:IsA("Trail") or Descendant:IsA("Beam") then
            Descendant.Enabled = false
        end
    end

    if not Model.PrimaryPart then
        local PrimaryPart = Model:FindFirstChildWhichIsA("BasePart", true)

        if PrimaryPart then
            Model.PrimaryPart = PrimaryPart
        end
    end
end

local function Get_Overhead_Attachment(Model: Model): Attachment?
    local ExistingAttachment = Model:FindFirstChild("SquishyOverheadAttachment", true)

    if ExistingAttachment and ExistingAttachment:IsA("Attachment") then
        return ExistingAttachment
    end

    local FallbackAttachment = Model:FindFirstChild(Constants.OVERHEAD_ATTACHMENT_FALLBACK_NAME, true)

    if FallbackAttachment and FallbackAttachment:IsA("Attachment") then
        return FallbackAttachment
    end

    local RootPart = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart", true)

    if not RootPart then
        return nil
    end

    FallbackAttachment = Instance.new("Attachment")
    FallbackAttachment.Name = Constants.OVERHEAD_ATTACHMENT_FALLBACK_NAME
    FallbackAttachment.Parent = RootPart

    return FallbackAttachment
end

local function Get_Or_Create_Overhead(Model: Model): BillboardGui?
    local Attachment = Get_Overhead_Attachment(Model)

    if not Attachment then
        return nil
    end

    local Billboard = Attachment:FindFirstChild(Constants.SQUISHY_OVERHEAD_NAME)

    if Billboard and Billboard:IsA("BillboardGui") then
        return Billboard
    end

    Billboard = SquishyOverheadTemplate:Clone()
    Billboard.Name = Constants.SQUISHY_OVERHEAD_NAME
    Billboard.Parent = Attachment

    return Billboard
end

local function Get_Or_Create_Overhead_Cache(Model: Model): OverheadCache?
    local Cache = OverheadCacheByModel[Model]

    if Cache and Cache.billboard.Parent then
        return Cache
    end

    local Billboard = Get_Or_Create_Overhead(Model)

    if not Billboard then
        return nil
    end

    local NameObject = Find_Gui_Object(Billboard, { "Name" })
    local RarityObject = Find_Gui_Object(Billboard, { "Rarity" })
    local CashObject = Find_Gui_Object(Billboard, { "Cash" })
    local IncomePerSecObject = Find_Gui_Object(Billboard, { "IncomePerSec", "Income Per Sec", "Income" })

    if not CashObject and IncomePerSecObject then
        CashObject = IncomePerSecObject:Clone()
        CashObject.Name = "Cash"
        CashObject.Parent = IncomePerSecObject.Parent
    end

    Cache = {
        billboard = Billboard,
        nameObject = NameObject,
        rarityObject = RarityObject,
        cashObject = CashObject,
        incomePerSecObject = IncomePerSecObject,
        strengthObject = Find_Gui_Object(Billboard, { "Strength" }),
        timerObject = Find_Gui_Object(Billboard, { "Timer" }),
        weightObject = Find_Gui_Object(Billboard, { "Weight" }),
        levelProgressObject = Find_Gui_Object(Billboard, { "LevelProgress", "Level Progress" }),
        levelObject = Find_Gui_Object(Billboard, { "Level" }),
        nameLabel = Find_Field_Label(Billboard, { "Name" }),
        rarityLabel = Find_Field_Label(Billboard, { "Rarity" }),
        cashLabel = Find_Field_Label(Billboard, { "Cash" }),
        levelLabel = Find_Field_Label(Billboard, { "Level" }),
        lastNameText = nil,
        lastRarity = nil,
        lastCashText = nil,
        lastLevelText = nil,
    }
    OverheadCacheByModel[Model] = Cache

    return Cache
end

local function Should_Show_Level_Overhead(State: PlotSquishyState, _Billboard: BillboardGui): boolean
    if State.ownerUserId ~= LocalPlayer.UserId then
        return false
    end

    if Is_Food_Equipped and Is_Food_Equipped() then
        if Is_Tutorial_Blocking_Feed_Target(State) then
            return false
        end

        return true
    end

    return false
end

local function Update_Overhead(State: PlotSquishyState, Now: number)
    local Cache = Get_Or_Create_Overhead_Cache(State.model)

    if not Cache then
        return
    end

    EventMutationVFX.Sync(State.model, State.eventMutations)

    local MaxDistance = if State.ownerUserId == LocalPlayer.UserId
        then Config.Overheads.PlotOwnMaxDistance
        else Config.Overheads.PlotOtherPlayerMaxDistance

    if Cache.billboard.MaxDistance ~= MaxDistance then
        Cache.billboard.MaxDistance = MaxDistance
    end

    local ShouldShowLevel = Should_Show_Level_Overhead(State, Cache.billboard)

    Set_Field_Visible(Cache.levelProgressObject, ShouldShowLevel)
    Set_Field_Visible(Cache.levelObject, ShouldShowLevel)

    if ShouldShowLevel then
        Set_Field_Visible(Cache.nameObject, false)
        Set_Field_Visible(Cache.rarityObject, false)
        Set_Field_Visible(Cache.cashObject, false)
        Set_Field_Visible(Cache.incomePerSecObject, false)
        Set_Field_Visible(Cache.strengthObject, false)
        Set_Field_Visible(Cache.timerObject, false)
        Set_Field_Visible(Cache.weightObject, false)

        local LevelText = `Level {State.level}`

        if Cache.levelLabel and Cache.lastLevelText ~= LevelText then
            Cache.levelLabel.Text = LevelText
            Cache.lastLevelText = LevelText
        end

        Update_Level_Progress(Cache.levelProgressObject, State)
        return
    end

    Set_Field_Visible(Cache.nameObject, true)
    Set_Field_Visible(Cache.rarityObject, true)
    Set_Field_Visible(Cache.cashObject, true)
    Set_Field_Visible(Cache.incomePerSecObject, false)
    Set_Field_Visible(Cache.strengthObject, false)
    Set_Field_Visible(Cache.timerObject, false)
    Set_Field_Visible(Cache.weightObject, false)

    if Cache.nameLabel then
        local NameText = InventoryMath.FormatSquishyDisplayName(State.kind, State.name, State.mutation)

        if Cache.lastNameText ~= NameText then
            Cache.nameLabel.Text = NameText
            Cache.lastNameText = NameText
        end

        Apply_Name_Mutation_Gradient(Cache.nameLabel, State.kind, State.mutation)
    end

    if Cache.rarityLabel and Cache.lastRarity ~= State.rarity then
        Cache.rarityLabel.Text = State.rarity
        Apply_Rarity_Gradient(Cache.rarityLabel, State.rarity)
        Cache.lastRarity = State.rarity
    end

    if Cache.cashLabel then
        local CashText = Format_Cash(Get_Display_Cash(State, Now))

        if Cache.lastCashText ~= CashText then
            Cache.cashLabel.Text = CashText
            Cache.lastCashText = CashText
        end
    end
end

local function Get_Model_Foot_Offset(Model: Model): number
    local Pivot = Model:GetPivot()
    local MinimumY = math.huge

    for _, Descendant in Model:GetDescendants() do
        if not Descendant:IsA("BasePart") then
            continue
        end

        local Part = Descendant :: BasePart
        local Size = Part.Size

        for _, Offset in
            {
                Vector3.new(-0.5, -0.5, -0.5),
                Vector3.new(0.5, -0.5, -0.5),
                Vector3.new(-0.5, -0.5, 0.5),
                Vector3.new(0.5, -0.5, 0.5),
            }
        do
            local Corner =
                Part.CFrame:PointToWorldSpace(Vector3.new(Size.X * Offset.X, Size.Y * Offset.Y, Size.Z * Offset.Z))
            MinimumY = math.min(MinimumY, Corner.Y)
        end
    end

    if MinimumY == math.huge then
        return 0
    end

    return math.max(0, Pivot.Position.Y - MinimumY)
end

local function Get_Model_Radius(Model: Model): number
    local _, Size = Model:GetBoundingBox()

    return math.max(2, math.max(Size.X, Size.Z) * 0.45)
end

local function Load_Animation(Animator: Animator, Kind: string, AnimationName: string): AnimationTrack?
    local Animation = AnimationsFolder:FindFirstChild(`{Kind} {AnimationName}`)

    if not Animation or not Animation:IsA("Animation") then
        return nil
    end

    local Track = Animator:LoadAnimation(Animation)
    Track.Looped = true

    return Track
end

local function Load_Animations(Model: Model, Kind: string): AnimationState
    local AnimationController = Model:FindFirstChildOfClass("AnimationController")

    if not AnimationController then
        return {}
    end

    local Animator = AnimationController:FindFirstChildOfClass("Animator")

    if not Animator then
        Animator = Instance.new("Animator")
        Animator.Parent = AnimationController
    end

    return {
        Idle = Load_Animation(Animator, Kind, "Idle"),
        Walk = Load_Animation(Animator, Kind, "Walk"),
        IsWalking = nil,
    }
end

local function Stop_Animations(Animations: AnimationState?)
    if not Animations then
        return
    end

    if Animations.Idle then
        Animations.Idle:Stop(Constants.ANIMATION_FADE_TIME)
        Animations.Idle:Destroy()
    end

    if Animations.Walk then
        Animations.Walk:Stop(Constants.ANIMATION_FADE_TIME)
        Animations.Walk:Destroy()
    end
end

local function Set_Animation_State(State: PlotSquishyState, IsWalking: boolean)
    local Animations = State.animations

    if Animations.IsWalking == IsWalking then
        return
    end

    Animations.IsWalking = IsWalking

    local TrackToPlay = if IsWalking then Animations.Walk else Animations.Idle
    local TrackToStop = if IsWalking then Animations.Idle else Animations.Walk

    if TrackToStop and TrackToStop.IsPlaying then
        TrackToStop:Stop(Constants.ANIMATION_FADE_TIME)
    end

    if TrackToPlay and not TrackToPlay.IsPlaying then
        TrackToPlay:Play(Constants.ANIMATION_FADE_TIME)
    end

    if Animations.Idle then
        Animations.Idle:AdjustSpeed(Constants.IDLE_ANIMATION_SPEED)
    end

    if Animations.Walk then
        Animations.Walk:AdjustSpeed(Constants.WALK_ANIMATION_SPEED)
    end
end

local function Get_Grounded_Position(Position: Vector3, FootOffset: number): Vector3
    local Ground = MapRaycast.GetGroundedPosition(
        Position,
        Constants.GROUND_FALLBACK_Y,
        Constants.GROUND_RAY_UP,
        Constants.GROUND_RAY_DOWN
    )

    return Ground + Vector3.yAxis * FootOffset
end

local function Look_At_Flat(Position: Vector3, Target: Vector3, Fallback: CFrame): CFrame
    local FlatTarget = Vector3.new(Target.X, Position.Y, Target.Z)

    if (FlatTarget - Position).Magnitude < 0.05 then
        return CFrame.new(Position) * Fallback.Rotation
    end

    return CFrame.lookAt(Position, FlatTarget)
end

local function Cleanup_State(State: PlotSquishyState)
    StateListDirty = true
    Stop_Animations(State.animations)
    OverheadCacheByModel[State.model] = nil

    if State.feedPromptConnection then
        State.feedPromptConnection:Disconnect()
        State.feedPromptConnection = nil
    end

    if State.feedPrompt then
        State.feedPrompt:Destroy()
        State.feedPrompt = nil
    end

    if State.feedPromptAttachment then
        State.feedPromptAttachment:Destroy()
        State.feedPromptAttachment = nil
    end

    if State.pickupPromptConnection then
        State.pickupPromptConnection:Disconnect()
        State.pickupPromptConnection = nil
    end

    if State.pickupPrompt then
        State.pickupPrompt:Destroy()
        State.pickupPrompt = nil
    end

    if State.pickupPromptAttachment then
        State.pickupPromptAttachment:Destroy()
        State.pickupPromptAttachment = nil
    end

    if HoveredState == State then
        HoveredState = nil

        if HoverHighlight then
            HoverHighlight.Parent = nil
        end
    end

    if State.model then
        State.model:Destroy()
    end
end

local function Get_Owner_States(UserId: number): { [string]: PlotSquishyState }
    local Existing = StatesByOwner[UserId]

    if Existing then
        return Existing
    end

    Existing = {}
    StatesByOwner[UserId] = Existing

    return Existing
end

local function Get_Hotbar_Slot_For_Item(ItemId: string): number?
    local HotbarSlots = peek(FusionValues.HotbarSlots)

    if type(HotbarSlots) ~= "table" then
        return nil
    end

    for Key, Assignment in HotbarSlots do
        if type(Assignment) ~= "table" or Assignment.ItemId ~= ItemId or Assignment.ItemType ~= "Squishy" then
            continue
        end

        local Slot = if type(Assignment.Slot) == "number" then Assignment.Slot else tonumber(Key)

        if Slot and Constants.CUSTOM_HOTBAR_SLOT_NAMES[Slot] then
            return Slot
        end
    end

    return nil
end

local function Get_Owned_Squishy(ItemId: string): any?
    local OwnedSquishies = peek(FusionValues.OwnedSquishies)

    if type(OwnedSquishies) ~= "table" then
        return nil
    end

    for _, Item in OwnedSquishies do
        if type(Item) == "table" and Item.Id == ItemId and Item.Type == "Squishy" then
            return Item
        end
    end

    return nil
end

local function Equip_Returned_Squishy_When_Ready()
    if not PendingReturnedEquipItemId then
        return
    end

    if os.clock() - PendingReturnedEquipStartedAt > RETURN_EQUIP_TIMEOUT then
        PendingReturnedEquipItemId = nil
        return
    end

    local Item = Get_Owned_Squishy(PendingReturnedEquipItemId)

    if not Item then
        return
    end

    local Slot = if type(Item.HotbarSlot) == "number"
        then Item.HotbarSlot
        else Get_Hotbar_Slot_For_Item(PendingReturnedEquipItemId)
    local SlotName = if Slot then Constants.CUSTOM_HOTBAR_SLOT_NAMES[Slot] else nil

    if SlotName then
        FusionValues.EquippedInventoryItemId:set(nil)
        FusionValues.EquippedInventorySlot:set(SlotName)
    else
        FusionValues.EquippedInventorySlot:set(nil)
        FusionValues.EquippedInventoryItemId:set(PendingReturnedEquipItemId)
    end

    PendingReturnedEquipItemId = nil
end

local function Get_Data_Final_Income_Per_Sec(Data: PlotSquishyData): number
    if
        type(Data.FinalIncomePerSec) == "number"
        and Data.FinalIncomePerSec == Data.FinalIncomePerSec
        and Data.FinalIncomePerSec > 0
    then
        return math.max(0, math.floor(Data.FinalIncomePerSec + 0.5))
    end

    local IncomeData = table.clone(Data)

    if type(IncomeData.BaseIncomePerSec) ~= "number" or IncomeData.BaseIncomePerSec <= 0 then
        local SquishyData = Squishies.GetData(Data.Kind :: any, Data.Name)

        if SquishyData and type(SquishyData.IncomePerSec) == "number" then
            IncomeData.BaseIncomePerSec = SquishyData.IncomePerSec
        end
    end

    local ComputedIncome = InventoryMath.GetFinalIncomePerSec(IncomeData)

    if ComputedIncome > 0 then
        return ComputedIncome
    end

    return ComputedIncome
end

local function Get_Data_Stored_Cash(Data: PlotSquishyData): number
    if type(Data.StoredCash) == "number" and Data.StoredCash == Data.StoredCash then
        return math.max(0, Data.StoredCash)
    end

    return 0
end

local function Get_Data_Last_Cash_Update(Data: PlotSquishyData): number
    if
        type(Data.LastCashUpdate) == "number"
        and Data.LastCashUpdate == Data.LastCashUpdate
        and Data.LastCashUpdate > 0
    then
        return Data.LastCashUpdate
    end

    return workspace:GetServerTimeNow()
end

local function Normalize_Move_State(Value: any): string
    return if Value == Constants.MOVE_STATE_MOVING then Constants.MOVE_STATE_MOVING else "Idle"
end

local function Normalize_Move_Vector(Data: PlotSquishyData, IsTarget: boolean): Vector3
    local Position = Vector3.new(Data.PositionX, Data.PositionY, Data.PositionZ)
    local X = if IsTarget then Data.MoveTargetX else Data.MoveStartX
    local Y = if IsTarget then Data.MoveTargetY else Data.MoveStartY
    local Z = if IsTarget then Data.MoveTargetZ else Data.MoveStartZ

    return Vector3.new(
        if type(X) == "number" and X == X then X else Position.X,
        if type(Y) == "number" and Y == Y then Y else Position.Y,
        if type(Z) == "number" and Z == Z then Z else Position.Z
    )
end

local function Normalize_Move_Number(Value: any, Fallback: number): number
    return if type(Value) == "number" and Value == Value then Value else Fallback
end

local function Ease_Alpha(Alpha: number): number
    local Clamped = math.clamp(Alpha, 0, 1)

    return Clamped * Clamped * (3 - 2 * Clamped)
end

local function Spawn_Or_Update(UserId: number, Data: PlotSquishyData, SuppressCollectBounce: boolean?)
    local OwnerStates = Get_Owner_States(UserId)
    local Existing = OwnerStates[Data.Id]
    local FinalIncome = Get_Data_Final_Income_Per_Sec(Data)
    local StoredCash = Get_Data_Stored_Cash(Data)
    local LastCashUpdate = Get_Data_Last_Cash_Update(Data)
    local Level = SquishyLevels.NormalizeLevel(Data.Level)
    local XP = if Level >= SquishyLevels.MaxLevel then 0 else SquishyLevels.NormalizeXp(Data.XP)
    local EventMutationList = EventMutations.NormalizeList(Data.EventMutations)
    local Scale = Get_Model_Scale(Data.Weight, Data.Rarity, Level)
    local MoveStart = Normalize_Move_Vector(Data, false)
    local MoveTarget = Normalize_Move_Vector(Data, true)

    if Existing and Existing.model.Parent then
        local PreviousLevel = Existing.level
        local PreviousLastCashUpdate = Existing.lastCashUpdate
        local PreviousDisplayedCash = Get_Display_Cash(Existing)
        local DidLevelUp = Level > PreviousLevel
        local DidCollectCash = LastCashUpdate > PreviousLastCashUpdate
            and PreviousDisplayedCash >= Constants.COLLECT_BOUNCE_MIN_CASH
            and StoredCash < 1
            and StoredCash < PreviousDisplayedCash

        Existing.name = Data.Name
        Existing.rarity = Data.Rarity
        Existing.weight = Data.Weight
        Existing.mutation = Data.Mutation
        Existing.eventMutations = EventMutationList
        Existing.level = Level
        Existing.xp = XP
        Existing.incomePerSec = FinalIncome
        Existing.storedCash = StoredCash
        Existing.lastCashUpdate = LastCashUpdate
        Existing.baseScale = Scale
        Existing.moveState = Normalize_Move_State(Data.MoveState)
        Existing.moveStart = MoveStart
        Existing.moveTarget = MoveTarget
        Existing.moveStartedAt = Normalize_Move_Number(Data.MoveStartedAt, workspace:GetServerTimeNow())
        Existing.moveDuration = math.max(0, Normalize_Move_Number(Data.MoveDuration, 0))
        Existing.idleUntil = Normalize_Move_Number(Data.IdleUntil, workspace:GetServerTimeNow())
        Existing.moveIndex = math.max(0, math.floor(Normalize_Move_Number(Data.MoveIndex, 0)))
        Existing.model:SetAttribute("Level", Level)
        Existing.model:SetAttribute("XP", XP)
        Existing.model:SetAttribute("EventMutations", EventMutations.EncodeAttribute(EventMutationList))
        Existing.model:SetAttribute("FinalIncomePerSec", FinalIncome)
        Existing.model:SetAttribute("StoredCash", StoredCash)
        Existing.model:SetAttribute("LastCashUpdate", LastCashUpdate)
        Existing.model:SetAttribute("PlotSquishyBaseScale", Scale)
        Existing.model:SetAttribute("TutorialRole", Data.TutorialRole)
        Existing.nextMovementUpdateAt = 0
        Existing.nextOverheadUpdateAt = 0
        Existing.nextFeedPromptUpdateAt = 0
        Existing.forceMovementUpdate = true
        Scale_Model(Existing.model, Scale)
        EventMutationVFX.Sync(Existing.model, EventMutationList)
        if DidCollectCash and not SuppressCollectBounce then
            Play_Squishy_Bounce(Existing)
        end
        if DidLevelUp then
            Play_Level_Up_Confetti(Existing.model)
        end
        Existing.modelRadius = Get_Model_Radius(Existing.model)
        return
    end

    local Template = Squishies.GetModel(Data.Kind :: any, Data.Name, Data.Mutation)

    if not Template then
        return
    end

    local Model = Template:Clone()
    Model.Name = `PlotSquishy_{UserId}_{Data.Id}`
    Model:SetAttribute("PlotSquishyOwnerUserId", UserId)
    Model:SetAttribute("PlotSquishyId", Data.Id)
    Model:SetAttribute("Name", Data.Name)
    Model:SetAttribute("Kind", Data.Kind)
    Model:SetAttribute("Rarity", Data.Rarity)
    Model:SetAttribute("TutorialRole", Data.TutorialRole)
    Model:SetAttribute("Weight", Data.Weight)
    Model:SetAttribute("Mutation", Data.Mutation)
    Model:SetAttribute("EventMutations", EventMutations.EncodeAttribute(EventMutationList))
    Model:SetAttribute("Level", Level)
    Model:SetAttribute("XP", XP)
    Model:SetAttribute("FinalIncomePerSec", FinalIncome)
    Model:SetAttribute("StoredCash", StoredCash)
    Model:SetAttribute("LastCashUpdate", LastCashUpdate)
    Model:SetAttribute("PlotSquishyBaseScale", Scale)

    Scale_Model(Model, Scale)

    Prepare_Model(Model)
    Model.Parent = Get_Folder()

    local FootOffset = Get_Model_Foot_Offset(Model)
    local ModelRadius = Get_Model_Radius(Model)
    local StartPosition = Get_Grounded_Position(Vector3.new(Data.PositionX, Data.PositionY, Data.PositionZ), FootOffset)
    Model:PivotTo(CFrame.new(StartPosition))

    OwnerStates[Data.Id] = {
        ownerUserId = UserId,
        id = Data.Id,
        kind = Data.Kind,
        name = Data.Name,
        rarity = Data.Rarity,
        weight = Data.Weight,
        mutation = Data.Mutation,
        eventMutations = EventMutationList,
        level = Level,
        xp = XP,
        incomePerSec = FinalIncome,
        storedCash = StoredCash,
        lastCashUpdate = LastCashUpdate,
        lastCollectRequestAt = 0,
        lastFeedRequestAt = 0,
        model = Model,
        baseScale = Scale,
        bounceSerial = 0,
        feedPrompt = nil,
        feedPromptAttachment = nil,
        feedPromptConnection = nil,
        pickupPrompt = nil,
        pickupPromptAttachment = nil,
        pickupPromptConnection = nil,
        modelRadius = ModelRadius,
        footOffset = FootOffset,
        moveState = Normalize_Move_State(Data.MoveState),
        moveStart = MoveStart,
        moveTarget = MoveTarget,
        moveStartedAt = Normalize_Move_Number(Data.MoveStartedAt, workspace:GetServerTimeNow()),
        moveDuration = math.max(0, Normalize_Move_Number(Data.MoveDuration, 0)),
        idleUntil = Normalize_Move_Number(Data.IdleUntil, workspace:GetServerTimeNow()),
        moveIndex = math.max(0, math.floor(Normalize_Move_Number(Data.MoveIndex, 0))),
        nextMovementUpdateAt = 0,
        nextOverheadUpdateAt = 0,
        nextCollectCheckAt = 0,
        nextFeedPromptUpdateAt = 0,
        forceMovementUpdate = true,
        animations = Load_Animations(Model, Data.Kind),
    }
    EventMutationVFX.Sync(Model, EventMutationList)
    StateListDirty = true
end

local function Reconcile_Owner(UserId: number, Items: { any }, ForceSuppressCollectBounce: boolean?)
    local OwnerStates = Get_Owner_States(UserId)
    local Seen = {}
    local CollectedCount = 0

    for _, Item in Items do
        if type(Item) ~= "table" or type(Item.Id) ~= "string" or Item.Id == "" then
            continue
        end

        local Existing = OwnerStates[Item.Id]

        if not Existing then
            continue
        end

        local LastCashUpdate = Get_Data_Last_Cash_Update(Item :: any)
        local StoredCash = Get_Data_Stored_Cash(Item :: any)
        local PreviousDisplayedCash = Get_Display_Cash(Existing)

        if
            LastCashUpdate > Existing.lastCashUpdate
            and PreviousDisplayedCash >= Constants.COLLECT_BOUNCE_MIN_CASH
            and StoredCash < 1
            and StoredCash < PreviousDisplayedCash
        then
            CollectedCount += 1
        end
    end

    local SuppressCollectBounce = ForceSuppressCollectBounce == true or CollectedCount > 1

    for _, Item in Items do
        if type(Item) ~= "table" or type(Item.Id) ~= "string" or Item.Id == "" then
            continue
        end

        Seen[Item.Id] = true
        Spawn_Or_Update(UserId, Item :: any, SuppressCollectBounce)
    end

    for ItemId, State in OwnerStates do
        if not Seen[ItemId] then
            Cleanup_State(State)
            OwnerStates[ItemId] = nil
        end
    end
end

local function Process_Network()
    for _, Payload in Network.PlotSquishiesChanged.Iter() do
        local UserId = Payload.PlayerUserId

        if type(UserId) ~= "number" then
            continue
        end

        Reconcile_Owner(UserId, Payload.Items, Payload.SuppressCollectBounce)

        if UserId == LocalPlayer.UserId then
            FusionValues.PlotSquishies:set(Payload.Items)
        end
    end
end

local function Request_Sync()
    if DidRequestSync then
        return
    end

    DidRequestSync = true
    Network.PlotSquishiesSyncRequest.Fire()
end

local function Get_Local_Root(): BasePart?
    local Character = LocalPlayer.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if Root and Root:IsA("BasePart") then
        return Root
    end

    return nil
end

local function Is_Root_Touching_State(Root: BasePart, State: PlotSquishyState): boolean
    local PivotPosition = State.model:GetPivot().Position
    local RootPosition = Root.Position
    local FlatOffset = Vector3.new(RootPosition.X - PivotPosition.X, 0, RootPosition.Z - PivotPosition.Z)
    local TouchRadius = State.modelRadius + Constants.COLLECT_TOUCH_PADDING_XZ
    local VerticalRadius = math.max(State.modelRadius, State.footOffset) + Constants.COLLECT_TOUCH_PADDING_Y

    return FlatOffset.Magnitude <= TouchRadius and math.abs(RootPosition.Y - PivotPosition.Y) <= VerticalRadius
end

local function Maybe_Request_Cash_Collect(State: PlotSquishyState, Now: number)
    if State.ownerUserId ~= LocalPlayer.UserId then
        return
    end

    if Get_Display_Cash(State, Now) < 1 then
        return
    end

    if Is_Food_Equipped and Is_Food_Equipped() then
        return
    end

    local Root = Get_Local_Root()

    if not Root then
        return
    end

    if not Is_Root_Touching_State(Root, State) then
        return
    end

    local ClockNow = os.clock()

    if ClockNow - State.lastCollectRequestAt < Constants.COLLECT_REQUEST_COOLDOWN then
        return
    end

    State.lastCollectRequestAt = ClockNow

    Network.CollectPlotSquishyCash.Fire({
        ItemId = State.id,
    })
end

local function Get_Render_Position(State: PlotSquishyState, Now: number): (Vector3, boolean)
    if State.moveState ~= Constants.MOVE_STATE_MOVING or State.moveDuration <= 0 then
        return State.moveTarget, false
    end

    local Alpha = (Now - State.moveStartedAt) / State.moveDuration

    if Alpha >= 1 then
        return State.moveTarget, false
    end

    return State.moveStart:Lerp(State.moveTarget, Ease_Alpha(Alpha)), true
end

local function Get_Movement_Update_Interval(RenderPosition: Vector3, IsMoving: boolean, RootPosition: Vector3?): number
    if not IsMoving then
        return Constants.IDLE_UPDATE_INTERVAL
    end

    if RootPosition and (RenderPosition - RootPosition).Magnitude <= Constants.SUPER_CLOSE_DISTANCE then
        return Constants.SUPER_CLOSE_MOVING_UPDATE_INTERVAL
    end

    return Constants.MOVING_UPDATE_INTERVAL
end

local function Update_State(State: PlotSquishyState, Now: number, RootPosition: Vector3?): boolean
    if not State.model.Parent then
        return false
    end

    if State.forceMovementUpdate or Now >= State.nextMovementUpdateAt then
        local RenderPosition, IsMoving = Get_Render_Position(State, Now)
        local MovementInterval = Get_Movement_Update_Interval(RenderPosition, IsMoving, RootPosition)
        local CurrentCFrame = State.model:GetPivot()
        local NewPosition = Get_Grounded_Position(RenderPosition, State.footOffset)
        local FlatMoveDistance = (Vector3.new(State.moveTarget.X, 0, State.moveTarget.Z) - Vector3.new(
            State.moveStart.X,
            0,
            State.moveStart.Z
        )).Magnitude
        local IsWalking = IsMoving and FlatMoveDistance > Constants.WALK_DISTANCE_THRESHOLD
        local LookTarget = if FlatMoveDistance > 0.05 then State.moveTarget else NewPosition + CurrentCFrame.LookVector
        local FinalCFrame = Look_At_Flat(NewPosition, LookTarget, CurrentCFrame)
        local SmoothedRotation = CurrentCFrame.Rotation:Lerp(FinalCFrame.Rotation, Constants.TURN_LERP_ALPHA)

        State.model:PivotTo(CFrame.new(NewPosition) * SmoothedRotation)
        Set_Animation_State(State, IsWalking)
        State.forceMovementUpdate = false
        State.nextMovementUpdateAt = Now + MovementInterval
    end

    if Now >= State.nextOverheadUpdateAt then
        State.nextOverheadUpdateAt = Now + Constants.OVERHEAD_UPDATE_INTERVAL
        Update_Overhead(State, Now)
    end

    if State.ownerUserId == LocalPlayer.UserId and Now >= State.nextFeedPromptUpdateAt then
        State.nextFeedPromptUpdateAt = Now + Constants.FEED_PROMPT_UPDATE_INTERVAL

        if Update_Feed_Prompt then
            Update_Feed_Prompt(State)
        end

        if Update_Pickup_Prompt then
            Update_Pickup_Prompt(State)
        end
    end

    if Now >= State.nextCollectCheckAt then
        State.nextCollectCheckAt = Now + Constants.COLLECT_CHECK_INTERVAL
        Maybe_Request_Cash_Collect(State, Now)
    end

    return true
end

local function Rebuild_State_Update_List(Now: number)
    table.clear(StateUpdateList)

    for _, OwnerStates in StatesByOwner do
        for _, State in OwnerStates do
            table.insert(StateUpdateList, State)
        end
    end

    StateListDirty = false
    LastStateListRebuildAt = Now

    if StateUpdateCursor > #StateUpdateList then
        StateUpdateCursor = 1
    end
end

local function Remove_State_If_Current(State: PlotSquishyState)
    local OwnerStates = StatesByOwner[State.ownerUserId]

    if not OwnerStates or OwnerStates[State.id] ~= State then
        return
    end

    Cleanup_State(State)
    OwnerStates[State.id] = nil

    if next(OwnerStates) == nil then
        StatesByOwner[State.ownerUserId] = nil
    end
end

local function Update_All()
    local Now = workspace:GetServerTimeNow()
    CurrentUpdateNow = Now

    if Get_Current_Feed_Prompt_Signature then
        local FeedPromptSignature = Get_Current_Feed_Prompt_Signature()

        if FeedPromptSignature ~= LastFeedPromptSignature then
            LastFeedPromptSignature = FeedPromptSignature

            local LocalOwnerStates = StatesByOwner[LocalPlayer.UserId]

            if LocalOwnerStates then
                for _, State in LocalOwnerStates do
                    State.nextFeedPromptUpdateAt = 0
                end
            end
        end
    end

    if StateListDirty or Now - LastStateListRebuildAt >= Constants.STATE_LIST_REBUILD_INTERVAL then
        Rebuild_State_Update_List(Now)
    end

    local StateCount = #StateUpdateList

    if StateCount == 0 then
        return
    end

    local Root = Get_Local_Root()
    local RootPosition = if Root then Root.Position else nil

    for _ = 1, math.min(Constants.MAX_STATE_UPDATES_PER_FRAME, StateCount) do
        if StateUpdateCursor > StateCount then
            StateUpdateCursor = 1
        end

        local State = StateUpdateList[StateUpdateCursor]
        StateUpdateCursor += 1

        if State and not Update_State(State, Now, RootPosition) then
            Remove_State_If_Current(State)
        end
    end
end

local function Is_Hammer_Equipped(): boolean
    return peek(FusionValues.EquippedInventorySlot) == "Hammer"
end

local function Get_Equipped_Custom_Slot(): number?
    local EquippedSlot = peek(FusionValues.EquippedInventorySlot)

    if type(EquippedSlot) ~= "string" then
        return nil
    end

    local Slot = tonumber(EquippedSlot) or tonumber(string.match(EquippedSlot, "^Item%s+(%d+)$"))

    if Slot and Constants.CUSTOM_HOTBAR_SLOT_NAMES[Slot] then
        return Slot
    end

    return nil
end

local function Get_Hotbar_Assignment_For_Slot(Slot: number): any?
    local HotbarSlots = peek(FusionValues.HotbarSlots)

    if type(HotbarSlots) ~= "table" then
        return nil
    end

    for Key, Assignment in HotbarSlots do
        if type(Assignment) ~= "table" then
            continue
        end

        local AssignmentSlot = if type(Assignment.Slot) == "number" then Assignment.Slot else tonumber(Key)

        if AssignmentSlot == Slot then
            return Assignment
        end
    end

    return nil
end

local function Get_Owned_Food_Amount(ItemId: any): number
    if type(ItemId) ~= "string" or ItemId == "" then
        return 0
    end

    local OwnedFood = peek(FusionValues.OwnedFood)

    if type(OwnedFood) ~= "table" then
        return 0
    end

    for _, Item in OwnedFood do
        if type(Item) == "table" and Item.Id == ItemId and Item.Type == "Food" then
            return if type(Item.Amount) == "number" then math.max(0, math.floor(Item.Amount)) else 0
        end
    end

    return 0
end

local function Owns_Food(ItemId: any): boolean
    return Get_Owned_Food_Amount(ItemId) > 0
end

local function Get_Equipped_Food_Item_Id(): string?
    local Slot = Get_Equipped_Custom_Slot()

    if not Slot then
        return nil
    end

    local Assignment = Get_Hotbar_Assignment_For_Slot(Slot)

    if type(Assignment) == "table" and Assignment.ItemType == "Food" and Owns_Food(Assignment.ItemId) then
        return Assignment.ItemId
    end

    return nil
end

local function Get_Selected_Feed_Amount(): number
    local RawAmount = HudPlaceButton.GetSelectedFeedAmount()
    local Amount = if type(RawAmount) == "number" then math.floor(RawAmount) else 1

    if Amount == 5 or Amount == 10 then
        return Amount
    end

    return 1
end

local function Get_Food_Display_Name(FoodName: string): string
    local FoodData = Foods.Get(FoodName)

    if FoodData and type(FoodData.DisplayName) == "string" and FoodData.DisplayName ~= "" then
        return FoodData.DisplayName
    end

    return FoodName
end

local function Refresh_Food_State_Cache()
    if CachedFoodStateAt == CurrentUpdateNow then
        return
    end

    CachedFoodStateAt = CurrentUpdateNow
    CachedEquippedFoodItemId = Get_Equipped_Food_Item_Id()
end

local function Get_Frame_Equipped_Food_Item_Id(): string?
    Refresh_Food_State_Cache()

    return CachedEquippedFoodItemId
end

Get_Current_Feed_Prompt_Signature = function(): string
    local FoodName = Get_Frame_Equipped_Food_Item_Id() or ""
    local FeedAmount = if FoodName ~= "" then Get_Selected_Feed_Amount() else 0
    local OwnedAmount = if FoodName ~= "" then Get_Owned_Food_Amount(FoodName) else 0
    local TutorialStep = Get_Tutorial_Step_From_Fusion() or 0
    local TutorialFeedAmount = Get_Owned_Food_Amount(TutorialSteps.FeedName)

    return `{FoodName}:{FeedAmount}:{OwnedAmount}:{TutorialStep}:{TutorialFeedAmount}`
end

Is_Food_Equipped = function(): boolean
    return Get_Frame_Equipped_Food_Item_Id() ~= nil
end

local function Get_Tutorial_Step(): number?
    return Get_Tutorial_Step_From_Fusion()
end

local function Can_Use_Feed_Prompt_During_Tutorial(State: PlotSquishyState, FoodName: string): boolean
    local Step = Get_Tutorial_Step()

    if not Step or TutorialSteps.Is_Complete(Step) then
        return true
    end

    return Step == TutorialSteps.FeedStrong
        and State.model:GetAttribute("TutorialRole") == TutorialSteps.StrongRole
        and FoodName == TutorialSteps.FeedName
end

local function Get_Feed_Prompt_Food_Name(): (string?, boolean)
    local EquippedFood = Get_Frame_Equipped_Food_Item_Id()

    if EquippedFood then
        return EquippedFood, true
    end

    return nil, false
end

local function Clear_Feed_Prompt(State: PlotSquishyState)
    if State.feedPromptConnection then
        State.feedPromptConnection:Disconnect()
        State.feedPromptConnection = nil
    end

    if State.feedPrompt then
        State.feedPrompt.Enabled = false
        State.feedPrompt = nil
    end

    State.feedPromptAttachment = nil
end

local function Destroy_Feed_Prompt(State: PlotSquishyState)
    if State.feedPromptConnection then
        State.feedPromptConnection:Disconnect()
        State.feedPromptConnection = nil
    end

    if State.feedPrompt then
        State.feedPrompt.Enabled = false
        State.feedPrompt:Destroy()
        State.feedPrompt = nil
    end

    State.feedPromptAttachment = nil
end

local function Is_Feed_Prompt_Attachment_Candidate(Attachment: Attachment): boolean
    if
        Attachment.Name == "SquishyOverheadAttachment"
        or Attachment.Name == Constants.OVERHEAD_ATTACHMENT_FALLBACK_NAME
    then
        return false
    end

    return true
end

local function Find_Existing_Feed_Prompt_Attachment(Model: Model): Attachment?
    for _, Descendant in Model:GetDescendants() do
        if not Descendant:IsA("Attachment") or not Is_Feed_Prompt_Attachment_Candidate(Descendant) then
            continue
        end

        if Descendant:FindFirstChildWhichIsA("ProximityPrompt") then
            return Descendant
        end
    end

    for _, Name in { "FeedPromptAttachment", "PromptAttachment", "Attachment" } do
        local Attachment = Model:FindFirstChild(Name, true)

        if Attachment and Attachment:IsA("Attachment") and Is_Feed_Prompt_Attachment_Candidate(Attachment) then
            return Attachment
        end
    end

    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("Attachment") and Is_Feed_Prompt_Attachment_Candidate(Descendant) then
            return Descendant
        end
    end

    return nil
end

local function Get_Or_Create_Feed_Prompt_Attachment(Model: Model): Attachment?
    local Existing = Model:FindFirstChild(Constants.FEED_PROMPT_ATTACHMENT_NAME, true)

    if Existing and Existing:IsA("Attachment") and Is_Feed_Prompt_Attachment_Candidate(Existing) then
        return Existing
    end

    local Part = Get_Model_Effect_Part(Model) or Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart", true)

    if not Part then
        return nil
    end

    local Attachment = Instance.new("Attachment")

    Attachment.Name = Constants.FEED_PROMPT_ATTACHMENT_NAME
    Attachment.Position = Vector3.new(0, math.max(0.5, Part.Size.Y * 0.5), 0)
    Attachment.Parent = Part

    return Attachment
end

local function Get_Reusable_Feed_Prompt(Attachment: Attachment): ProximityPrompt?
    local Prompt = Attachment:FindFirstChild(Constants.FEED_PROMPT_NAME)

    if not Prompt or not Prompt:IsA("ProximityPrompt") then
        Prompt = Attachment:FindFirstChildWhichIsA("ProximityPrompt")
    end

    for _, Child in Attachment:GetChildren() do
        if Child:IsA("ProximityPrompt") and Child ~= Prompt then
            Child:Destroy()
        end
    end

    if Prompt and Prompt:IsA("ProximityPrompt") then
        return Prompt
    end

    Prompt = Instance.new("ProximityPrompt")
    Prompt.Name = Constants.FEED_PROMPT_NAME
    Prompt.Parent = Attachment

    return Prompt
end

local function Get_Or_Create_Feed_Prompt(State: PlotSquishyState): ProximityPrompt?
    local Attachment = Find_Existing_Feed_Prompt_Attachment(State.model)
        or Get_Or_Create_Feed_Prompt_Attachment(State.model)

    if not Attachment then
        Clear_Feed_Prompt(State)
        return nil
    end

    if State.feedPromptAttachment ~= Attachment then
        Clear_Feed_Prompt(State)
    end

    State.feedPromptAttachment = Attachment

    local Prompt = State.feedPrompt

    if Prompt and Prompt.Parent == Attachment then
        return Prompt
    end

    if State.feedPromptConnection then
        State.feedPromptConnection:Disconnect()
        State.feedPromptConnection = nil
    end

    Prompt = Get_Reusable_Feed_Prompt(Attachment)

    if not Prompt then
        return nil
    end

    Prompt.ActionText = "Feed Squishy"
    Prompt.ClickablePrompt = true
    Prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
    Prompt.HoldDuration = Constants.FEED_PROMPT_HOLD_DURATION
    Prompt.MaxActivationDistance = Constants.FEED_PROMPT_MAX_DISTANCE
    Prompt.RequiresLineOfSight = false
    State.feedPrompt = Prompt

    State.feedPromptConnection = Prompt.Triggered:Connect(function()
        local FoodName, HasEquippedFood = Get_Feed_Prompt_Food_Name()
        local FeedAmount = if HasEquippedFood then Get_Selected_Feed_Amount() else 1

        if not FoodName then
            return
        end

        if not Can_Use_Feed_Prompt_During_Tutorial(State, FoodName) then
            LocalNotifications.Push(TutorialSteps.BlockedMessage, "Error", 3)
            return
        end

        local Now = os.clock()

        if Now - State.lastFeedRequestAt < Constants.FEED_REQUEST_COOLDOWN then
            return
        end

        State.lastFeedRequestAt = Now

        local function Feed()
            Network.FeedPlotSquishy.Fire({
                ItemId = State.id,
                Amount = FeedAmount,
            })
        end

        if Get_Owned_Food_Amount(FoodName) >= FeedAmount and Play_Food_Toss(State, FoodName, Feed) then
            return
        end

        Feed()
    end)

    return Prompt
end

Update_Feed_Prompt = function(State: PlotSquishyState)
    if State.ownerUserId ~= LocalPlayer.UserId or State.level >= SquishyLevels.MaxLevel then
        Clear_Feed_Prompt(State)
        return
    end

    if Is_Tutorial_Blocking_Feed_Target(State) then
        Clear_Feed_Prompt(State)
        return
    end

    local FoodName, HasEquippedFood = Get_Feed_Prompt_Food_Name()

    if not FoodName then
        Clear_Feed_Prompt(State)
        return
    end

    if not Can_Use_Feed_Prompt_During_Tutorial(State, FoodName) then
        Clear_Feed_Prompt(State)
        return
    end

    local FeedAmount = if HasEquippedFood then Get_Selected_Feed_Amount() else 1
    local Prompt = Get_Or_Create_Feed_Prompt(State)

    if not Prompt then
        return
    end

    local ActionText = "Feed Squishy"
    local ObjectText = `x{FeedAmount} {Get_Food_Display_Name(FoodName)}`
    local ShouldRefresh = Prompt.ActionText ~= ActionText
        or Prompt.ObjectText ~= ObjectText
        or Prompt.HoldDuration ~= Constants.FEED_PROMPT_HOLD_DURATION

    if ShouldRefresh then
        Destroy_Feed_Prompt(State)
        Prompt = Get_Or_Create_Feed_Prompt(State)

        if not Prompt then
            return
        end
    end

    Prompt.ActionText = ActionText
    Prompt.ObjectText = ObjectText
    Prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
    Prompt.HoldDuration = Constants.FEED_PROMPT_HOLD_DURATION
    Prompt.Enabled = true
end

local function Is_Plot_Hover_Equipped(): boolean
    return Is_Hammer_Equipped()
end

local function Request_Remove_State(State: PlotSquishyState)
    if State.ownerUserId ~= LocalPlayer.UserId or not Is_Hammer_Equipped() then
        return
    end

    PendingReturnedEquipItemId = State.id
    PendingReturnedEquipStartedAt = os.clock()

    Network.RemovePlotSquishy.Fire({
        ItemId = State.id,
    })
end

local function Clear_Pickup_Prompt(State: PlotSquishyState)
    if State.pickupPromptConnection then
        State.pickupPromptConnection:Disconnect()
        State.pickupPromptConnection = nil
    end

    if State.pickupPrompt then
        State.pickupPrompt.Enabled = false
    end
end

local function Get_Or_Create_Pickup_Prompt_Attachment(State: PlotSquishyState): Attachment?
    if State.pickupPromptAttachment and State.pickupPromptAttachment.Parent then
        return State.pickupPromptAttachment
    end

    local Part = Get_Model_Effect_Part(State.model)

    if not Part then
        return nil
    end

    local Attachment = Part:FindFirstChild(Constants.PICKUP_PROMPT_ATTACHMENT_NAME)

    if not Attachment or not Attachment:IsA("Attachment") then
        Attachment = Instance.new("Attachment")
        Attachment.Name = Constants.PICKUP_PROMPT_ATTACHMENT_NAME
        Attachment.Parent = Part
    end

    State.pickupPromptAttachment = Attachment

    return Attachment
end

local function Get_Or_Create_Pickup_Prompt(State: PlotSquishyState): ProximityPrompt?
    local Attachment = Get_Or_Create_Pickup_Prompt_Attachment(State)

    if not Attachment then
        Clear_Pickup_Prompt(State)
        return nil
    end

    local Prompt = State.pickupPrompt

    if not Prompt or Prompt.Parent ~= Attachment then
        if State.pickupPromptConnection then
            State.pickupPromptConnection:Disconnect()
            State.pickupPromptConnection = nil
        end

        Prompt = Attachment:FindFirstChild(Constants.PICKUP_PROMPT_NAME)

        if not Prompt or not Prompt:IsA("ProximityPrompt") then
            Prompt = Instance.new("ProximityPrompt")
            Prompt.Name = Constants.PICKUP_PROMPT_NAME
            Prompt.Parent = Attachment
        end

        State.pickupPrompt = Prompt
    end

    if not State.pickupPromptConnection then
        State.pickupPromptConnection = Prompt.Triggered:Connect(function()
            Request_Remove_State(State)
        end)
    end

    return Prompt
end

Update_Pickup_Prompt = function(State: PlotSquishyState)
    if State.ownerUserId ~= LocalPlayer.UserId or not Is_Hammer_Equipped() then
        Clear_Pickup_Prompt(State)
        return
    end

    local Prompt = Get_Or_Create_Pickup_Prompt(State)

    if not Prompt then
        return
    end

    Prompt.ActionText = "Remove Squishy"
    Prompt.ObjectText = ""
    Prompt.ClickablePrompt = true
    Prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
    Prompt.HoldDuration = Constants.PICKUP_PROMPT_HOLD_DURATION
    Prompt.MaxActivationDistance = Constants.PICKUP_PROMPT_MAX_DISTANCE
    Prompt.RequiresLineOfSight = false
    Prompt.Enabled = true
end

local function Get_Highlight(): Highlight
    if HoverHighlight then
        return HoverHighlight
    end

    local Highlight = Instance.new("Highlight")
    Highlight.Name = Constants.HIGHLIGHT_NAME
    Highlight.FillTransparency = 0.75
    Highlight.OutlineTransparency = 0
    Highlight.FillColor = Color3.fromRGB(255, 245, 145)
    Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    HoverHighlight = Highlight

    return Highlight
end

local function Get_State_From_Instance(InstanceHit: Instance?): PlotSquishyState?
    local Current = InstanceHit

    while Current and Current ~= workspace do
        if Current:IsA("Model") then
            local OwnerUserId = Current:GetAttribute("PlotSquishyOwnerUserId")
            local ItemId = Current:GetAttribute("PlotSquishyId")

            if type(OwnerUserId) == "number" and type(ItemId) == "string" then
                local OwnerStates = StatesByOwner[OwnerUserId]

                if OwnerStates then
                    return OwnerStates[ItemId]
                end
            end
        end

        Current = Current.Parent
    end

    return nil
end

local function Get_Hover_Raycast_Params(): RaycastParams
    local Folder = Get_Folder()

    if HoverRaycastParams and HoverRaycastFolder == Folder then
        return HoverRaycastParams
    end

    local Params = RaycastParams.new()

    Params.FilterType = Enum.RaycastFilterType.Include
    Params.FilterDescendantsInstances = { Folder }
    Params.IgnoreWater = true
    HoverRaycastParams = Params
    HoverRaycastFolder = Folder

    return Params
end

local function Update_Hover()
    if not Is_Plot_Hover_Equipped() then
        HoveredState = nil

        if HoverHighlight then
            HoverHighlight.Parent = nil
        end

        return
    end

    local Now = os.clock()

    if Now - LastHoverUpdateAt < Constants.HOVER_UPDATE_INTERVAL then
        return
    end

    LastHoverUpdateAt = Now

    local Camera = workspace.CurrentCamera

    if not Camera then
        return
    end

    local MouseLocation = UserInputService:GetMouseLocation()
    local Ray = Camera:ViewportPointToRay(MouseLocation.X, MouseLocation.Y)
    local Result = workspace:Raycast(Ray.Origin, Ray.Direction * 500, Get_Hover_Raycast_Params())
    local State = Get_State_From_Instance(Result and Result.Instance)

    if State and State.ownerUserId ~= LocalPlayer.UserId then
        State = nil
    end

    HoveredState = State

    if not State then
        if HoverHighlight then
            HoverHighlight.Parent = nil
        end

        return
    end

    local Highlight = Get_Highlight()
    Highlight.Parent = State.model
end

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if GameProcessed then
        return
    end

    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    if not HoveredState or HoveredState.ownerUserId ~= LocalPlayer.UserId then
        return
    end

    Request_Remove_State(HoveredState)
end)

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        Request_Sync()
        Process_Network()
        Equip_Returned_Squishy_When_Ready()
        Update_All()
        Update_Hover()
    end,
    runConditions = {},
}
