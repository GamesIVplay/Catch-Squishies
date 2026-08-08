local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Network = require(ReplicatedFirst.Network)
local peek = Fusion.peek

local EventMutationVFX = require(script.Parent.Parent.Modules.EventMutationVFX)
local EventMutations = require(ReplicatedStorage.Shared.Modules.EventMutations)
local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local LassoRig = require(ReplicatedStorage.Shared.Modules.LassoRig)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local MapRaycast = require(ReplicatedStorage.Shared.Modules.MapRaycast)
local Phases = require(ReplicatedStorage.Shared.Phases)
local RarityGradients = require(script.Parent.Parent.Modules.RarityGradients)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local SquishyLevels = require(ReplicatedStorage.Shared.Modules.SquishyLevels)

type WalkingSquishyData = {
    PlayerUserId: number,
    Equipped: boolean,
    ItemId: string,
    Kind: string,
    Name: string,
    Rarity: string,
    Weight: number,
    Mutation: string,
    EventMutations: { string },
    Level: number,
    BaseIncomePerSec: number,
    FinalIncomePerSec: number,
    LassoName: string,
}

type AnimationState = {
    Idle: AnimationTrack?,
    Walk: AnimationTrack?,
    IsWalking: boolean?,
}

type WalkingSquishyState = {
    player: Player,
    guid: string,
    kind: string,
    name: string,
    rarity: string,
    mutation: string,
    eventMutations: { string },
    level: number,
    incomePerSec: number,
    model: Model,
    footOffset: number,
    ropeHeight: number,
    handAnchor: BasePart,
    squishyAnchor: BasePart,
    rope: RopeConstraint,
    animations: AnimationState,
    lassoName: string,
    appliedRopeStyleKey: string?,
}

local LocalPlayer = Players.LocalPlayer
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local AnimationsFolder = AssetsFolder:WaitForChild("Animations")
local BillboardsFolder = AssetsFolder:WaitForChild("Billboards")
local SquishyOverheadTemplate = BillboardsFolder:WaitForChild("SquishyOverhead") :: BillboardGui

local FOLLOW_FOLDER_NAME = "WalkingSquishies"
local HAND_ANCHOR_NAME = "WalkingSquishyHandAnchor"
local SQUISHY_ANCHOR_NAME = "WalkingSquishyAnchor"
local ROPE_NAME = "WalkingSquishyRope"
local SQUISHY_OVERHEAD_NAME = "SquishyOverhead"
local OVERHEAD_ATTACHMENT_FALLBACK_NAME = "WalkingSquishyOverheadAttachment"
local SLOT_BY_NAME = {
    ["3"] = 3,
    ["4"] = 4,
    ["5"] = 5,
    ["6"] = 6,
    ["7"] = 7,
}

local MIN_SCALE_WEIGHT = 8
local MAX_SCALE_WEIGHT = 100
local MIN_SQUISHY_SCALE = 1
local MAX_SQUISHY_SCALE = 5
local RARITY_SCALE_STEP = 0.1
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

local FOLLOW_BEHIND_DISTANCE = 4
local FOLLOW_SIDE_DISTANCE = 3
local FOLLOW_RESPONSIVENESS = 10
local ROTATION_RESPONSIVENESS = 12
local WALK_DISTANCE_THRESHOLD = 0.35
local TELEPORT_DISTANCE = 60
local ROPE_THICKNESS = 0.08
local ROPE_COLOR = BrickColor.new("Burlap")
local ROPE_EXTRA_LENGTH = 0.12
local GROUND_RAY_UP = 80
local GROUND_RAY_DOWN = 240
local ANIMATION_FADE_TIME = 0.12
local IDLE_ANIMATION_SPEED = 1
local WALK_ANIMATION_SPEED = 1.2

local WalkingSquishies: { [number]: WalkingSquishyState } = {}
local BoundPlayers: { [Player]: boolean } = {}
local LastRequestedSquishyId: string? = nil
local DidRequestInitialSync = false
local LastUpdateClock = os.clock()
local FollowFolder: Folder? = nil

local function Get_Follow_Folder(): Folder
    if FollowFolder and FollowFolder.Parent then
        return FollowFolder
    end

    local Existing = workspace:FindFirstChild(FOLLOW_FOLDER_NAME)

    if Existing and Existing:IsA("Folder") then
        FollowFolder = Existing
        return Existing
    end

    local Folder = Instance.new("Folder")
    Folder.Name = FOLLOW_FOLDER_NAME
    Folder.Parent = workspace
    FollowFolder = Folder

    return Folder
end

local function Is_Custom_Slot(Slot: any): boolean
    return type(Slot) == "number" and Slot >= 3 and Slot <= 7 and math.floor(Slot) == Slot
end

local function Get_Slot_From_Name(SlotName: any): number?
    if type(SlotName) ~= "string" then
        return nil
    end

    return SLOT_BY_NAME[SlotName]
end

local function Get_Assignment_For_Slot(Slot: number): any?
    local HotbarSlots = peek(FusionValues.HotbarSlots)

    if type(HotbarSlots) ~= "table" then
        return nil
    end

    for Key, Assignment in HotbarSlots do
        if type(Assignment) ~= "table" then
            continue
        end

        local AssignmentSlot = Assignment.Slot

        if not Is_Custom_Slot(AssignmentSlot) and type(Key) == "number" then
            AssignmentSlot = Key
        elseif not Is_Custom_Slot(AssignmentSlot) then
            AssignmentSlot = tonumber(Key)
        end

        if AssignmentSlot == Slot then
            return Assignment
        end
    end

    return nil
end

local function Find_Owned_Squishy(ItemId: string): any?
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

local function Normalize_Lasso_Name(LassoName: any): string
    if type(LassoName) == "string" and Lassos.Get(LassoName) then
        return LassoName
    end

    return Lassos.Default
end

local function Get_Local_Selected_Lasso_Name(): string
    return Normalize_Lasso_Name(peek(FusionValues.Lasso))
end

local function Get_Desired_Local_Squishy_Id(): string?
    local Character = LocalPlayer.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if not Root or not Root:IsA("BasePart") then
        return nil
    end

    local EquippedInventoryItemId = peek(FusionValues.EquippedInventoryItemId)

    if type(EquippedInventoryItemId) == "string" and Find_Owned_Squishy(EquippedInventoryItemId) then
        return EquippedInventoryItemId
    end

    local EquippedSlotName = peek(FusionValues.EquippedInventorySlot)
    local Slot = Get_Slot_From_Name(EquippedSlotName)

    if not Slot then
        return nil
    end

    local Assignment = Get_Assignment_For_Slot(Slot)

    if type(Assignment) ~= "table" or Assignment.ItemType ~= "Squishy" or type(Assignment.ItemId) ~= "string" then
        return nil
    end

    if not Find_Owned_Squishy(Assignment.ItemId) then
        return nil
    end

    return Assignment.ItemId
end

local function Sync_Local_Equipped_Squishy()
    local DesiredSquishyId = Get_Desired_Local_Squishy_Id()

    if DesiredSquishyId == LastRequestedSquishyId then
        return
    end

    if DesiredSquishyId then
        Network.WalkingSquishyRequest.Fire({
            ItemId = DesiredSquishyId,
            Equipped = true,
        })
    else
        Network.WalkingSquishyRequest.Fire({
            ItemId = LastRequestedSquishyId or "",
            Equipped = false,
        })
    end

    LastRequestedSquishyId = DesiredSquishyId
end

local function Request_Initial_Sync()
    if DidRequestInitialSync then
        return
    end

    DidRequestInitialSync = true
    Network.WalkingSquishySyncRequest.Fire()
end

local function Get_Scale_From_Weight(Weight: number): number
    local ClampedWeight = math.clamp(Weight, MIN_SCALE_WEIGHT, MAX_SCALE_WEIGHT)
    local Alpha = (ClampedWeight - MIN_SCALE_WEIGHT) / (MAX_SCALE_WEIGHT - MIN_SCALE_WEIGHT)

    return MIN_SQUISHY_SCALE + Alpha * (MAX_SQUISHY_SCALE - MIN_SQUISHY_SCALE)
end

local function Get_Rarity_Scale_Boost(Rarity: string): number
    return (RARITY_SCALE_INDEX[Rarity] or 0) * RARITY_SCALE_STEP
end

local function Get_Model_Scale(Weight: number, Rarity: string, Level: number): number
    return Get_Scale_From_Weight(Weight) + Get_Rarity_Scale_Boost(Rarity) + SquishyLevels.GetScaleBonus(Level)
end

local function Prepare_Model(Model: Model)
    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Descendant.Anchored = true
            Descendant.CanCollide = false
            Descendant.CanTouch = false
            Descendant.CanQuery = false
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

local function Find_Text_Label(Root: Instance, Names: { string }): TextLabel?
    for _, Name in Names do
        local DirectChild = Root:FindFirstChild(Name)

        if DirectChild and DirectChild:IsA("TextLabel") then
            return DirectChild
        end
    end

    for _, Descendant in Root:GetDescendants() do
        if not Descendant:IsA("TextLabel") then
            continue
        end

        for _, Name in Names do
            if Descendant.Name == Name then
                return Descendant
            end
        end
    end

    return nil
end

local function Find_Gui_Object(Root: Instance, Names: { string }): GuiObject?
    for _, Name in Names do
        local DirectChild = Root:FindFirstChild(Name)

        if DirectChild and DirectChild:IsA("GuiObject") then
            return DirectChild
        end
    end

    for _, Descendant in Root:GetDescendants() do
        if not Descendant:IsA("GuiObject") then
            continue
        end

        for _, Name in Names do
            if Descendant.Name == Name then
                return Descendant
            end
        end
    end

    return nil
end

local function Find_Field_Label(Root: Instance, Names: { string }): TextLabel?
    local FieldObject = Find_Gui_Object(Root, Names)

    if FieldObject then
        if FieldObject:IsA("TextLabel") then
            return FieldObject
        end

        local NestedLabel = FieldObject:FindFirstChildWhichIsA("TextLabel", true)

        if NestedLabel then
            return NestedLabel
        end
    end

    return Find_Text_Label(Root, Names)
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

local function Get_Overhead_Attachment(Model: Model): Attachment?
    local ExistingAttachment = Model:FindFirstChild("Attachment", true)

    if ExistingAttachment and ExistingAttachment:IsA("Attachment") then
        return ExistingAttachment
    end

    local RootPart = Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart", true)

    if not RootPart then
        return nil
    end

    local FallbackAttachment = RootPart:FindFirstChild(OVERHEAD_ATTACHMENT_FALLBACK_NAME)

    if FallbackAttachment and FallbackAttachment:IsA("Attachment") then
        return FallbackAttachment
    end

    FallbackAttachment = Instance.new("Attachment")
    FallbackAttachment.Name = OVERHEAD_ATTACHMENT_FALLBACK_NAME
    FallbackAttachment.Parent = RootPart

    return FallbackAttachment
end

local function Get_Or_Create_Overhead(Model: Model): BillboardGui?
    local Attachment = Get_Overhead_Attachment(Model)

    if not Attachment then
        return nil
    end

    local Billboard = Attachment:FindFirstChild(SQUISHY_OVERHEAD_NAME)

    if Billboard and Billboard:IsA("BillboardGui") then
        return Billboard
    end

    Billboard = SquishyOverheadTemplate:Clone()
    Billboard.Name = SQUISHY_OVERHEAD_NAME
    Billboard.Parent = Attachment

    return Billboard
end

local function Update_Walking_Overhead(State: WalkingSquishyState)
    local Billboard = Get_Or_Create_Overhead(State.model)

    if not Billboard then
        return
    end

    local NameObject = Find_Gui_Object(Billboard, { "Name" })
    local RarityObject = Find_Gui_Object(Billboard, { "Rarity" })
    local IncomePerSecObject = Find_Gui_Object(Billboard, { "IncomePerSec", "Income Per Sec", "Income" })
    local StrengthObject = Find_Gui_Object(Billboard, { "Strength" })
    local TimerObject = Find_Gui_Object(Billboard, { "Timer" })
    local WeightObject = Find_Gui_Object(Billboard, { "Weight" })
    local NameLabel = Find_Field_Label(Billboard, { "Name" })
    local RarityLabel = Find_Field_Label(Billboard, { "Rarity" })
    local IncomePerSecLabel = Find_Field_Label(Billboard, { "IncomePerSec", "Income Per Sec", "Income" })

    Set_Field_Visible(NameObject, true)
    Set_Field_Visible(RarityObject, true)
    Set_Field_Visible(IncomePerSecObject, true)
    Set_Field_Visible(StrengthObject, false)
    Set_Field_Visible(TimerObject, false)
    Set_Field_Visible(WeightObject, false)

    if NameLabel then
        NameLabel.Text = InventoryMath.FormatSquishyDisplayName(State.kind, State.name, State.mutation)
        Apply_Name_Mutation_Gradient(NameLabel, State.kind, State.mutation)
    end

    if RarityLabel then
        RarityLabel.Text = State.rarity
        Apply_Rarity_Gradient(RarityLabel, State.rarity)
    end

    if IncomePerSecLabel then
        IncomePerSecLabel.Text = InventoryMath.FormatIncome(State.incomePerSec)
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

local function Get_Model_Rope_Height(Model: Model): number
    local _, Size = Model:GetBoundingBox()

    return math.clamp(Size.Y * 0.35, 0.6, 5)
end

local function Get_Character_Root(Player: Player): BasePart?
    local Character = Player.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if Root and Root:IsA("BasePart") then
        return Root
    end

    return nil
end

local function Get_Hand_Position(Player: Player): Vector3?
    local Character = Player.Character

    if not Character then
        return nil
    end

    for _, PartName in { "RightHand", "Right Arm", "HumanoidRootPart" } do
        local Part = Character:FindFirstChild(PartName)

        if Part and Part:IsA("BasePart") then
            local GripAttachment = Part:FindFirstChild("RightGripAttachment")
                or Part:FindFirstChild("RightHandRigAttachment")

            if GripAttachment and GripAttachment:IsA("Attachment") then
                return GripAttachment.WorldPosition
            end

            return Part.Position
        end
    end

    return nil
end

local function Create_Hidden_Anchor(Name: string): (BasePart, Attachment)
    local Part = Instance.new("Part")
    Part.Name = Name
    Part.Size = Vector3.new(0.1, 0.1, 0.1)
    Part.Transparency = 1
    Part.Anchored = true
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.CastShadow = false
    Part.Parent = Get_Follow_Folder()

    local Attachment = Instance.new("Attachment")
    Attachment.Name = "RopeAttachment"
    Attachment.Parent = Part

    return Part, Attachment
end

local function Create_Rope(Attachment0: Attachment, Attachment1: Attachment): RopeConstraint
    local Rope = Instance.new("RopeConstraint")
    Rope.Name = ROPE_NAME
    Rope.Attachment0 = Attachment0
    Rope.Attachment1 = Attachment1
    Rope.Visible = true
    Rope.Thickness = ROPE_THICKNESS
    Rope.Color = ROPE_COLOR
    Rope.Parent = Attachment0.Parent

    return Rope
end

local function Get_Player_Held_Lasso_Rope(Player: Player, LassoName: string): RopeConstraint?
    local Character = Player.Character
    local HeldLasso = LassoRig.Get_Model(Character)

    if not HeldLasso then
        return nil
    end

    local HeldLassoName = HeldLasso:GetAttribute("LassoName")

    if type(HeldLassoName) == "string" and HeldLassoName ~= LassoName then
        return nil
    end

    return LassoRig.Get_Rope(HeldLasso)
end

local function Get_Template_Lasso_Rope(LassoName: string): RopeConstraint?
    local Template = LassoRig.Find_Template(LassoName)

    if Template then
        return LassoRig.Get_Rope(Template)
    end

    return nil
end

local function Get_Source_Lasso_Rope(Player: Player, LassoName: string): RopeConstraint?
    return Get_Player_Held_Lasso_Rope(Player, LassoName) or Get_Template_Lasso_Rope(LassoName)
end

local function Apply_Rope_Style_From_Source(Rope: RopeConstraint, SourceRope: RopeConstraint?)
    Rope.Visible = true
    Rope.Enabled = true

    if not SourceRope then
        Rope.Thickness = ROPE_THICKNESS
        Rope.Color = ROPE_COLOR
        Rope.Restitution = 0
        return
    end

    Rope.Thickness = SourceRope.Thickness
    Rope.Color = SourceRope.Color
    Rope.Restitution = SourceRope.Restitution

    pcall(function()
        Rope.WinchEnabled = SourceRope.WinchEnabled
        Rope.WinchForce = SourceRope.WinchForce
        Rope.WinchResponsiveness = SourceRope.WinchResponsiveness
        Rope.WinchSpeed = SourceRope.WinchSpeed
        Rope.WinchTarget = SourceRope.WinchTarget
    end)
end

local function Get_State_Lasso_Name(State: WalkingSquishyState): string
    if State.player == LocalPlayer then
        return Get_Local_Selected_Lasso_Name()
    end

    return Normalize_Lasso_Name(State.lassoName)
end

local function Refresh_Rope_Style(State: WalkingSquishyState, Force: boolean?)
    local LassoName = Get_State_Lasso_Name(State)
    local SourceRope = Get_Source_Lasso_Rope(State.player, LassoName)
    local SourceKey = if SourceRope then SourceRope:GetFullName() else "template-missing"
    local StyleKey = `{LassoName}:{SourceKey}`

    if not Force and State.appliedRopeStyleKey == StyleKey then
        return
    end

    State.lassoName = LassoName
    State.appliedRopeStyleKey = StyleKey
    Apply_Rope_Style_From_Source(State.rope, SourceRope)
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
        Animations.Idle:Stop(ANIMATION_FADE_TIME)
        Animations.Idle:Destroy()
    end

    if Animations.Walk then
        Animations.Walk:Stop(ANIMATION_FADE_TIME)
        Animations.Walk:Destroy()
    end
end

local function Set_Animation_State(State: WalkingSquishyState, IsWalking: boolean)
    local Animations = State.animations

    if Animations.IsWalking == IsWalking then
        return
    end

    Animations.IsWalking = IsWalking

    local TrackToPlay = if IsWalking then Animations.Walk else Animations.Idle
    local TrackToStop = if IsWalking then Animations.Idle else Animations.Walk

    if TrackToStop and TrackToStop.IsPlaying then
        TrackToStop:Stop(ANIMATION_FADE_TIME)
    end

    if TrackToPlay and not TrackToPlay.IsPlaying then
        TrackToPlay:Play(ANIMATION_FADE_TIME)
    end

    if Animations.Idle then
        Animations.Idle:AdjustSpeed(IDLE_ANIMATION_SPEED)
    end

    if Animations.Walk then
        Animations.Walk:AdjustSpeed(WALK_ANIMATION_SPEED)
    end
end

local function Get_Grounded_Position(Position: Vector3, FootOffset: number): Vector3
    local Result = MapRaycast.RaycastDown(Position, GROUND_RAY_UP, GROUND_RAY_DOWN)

    if Result then
        return Result.Position + Vector3.yAxis * FootOffset
    end

    return Position
end

local function Get_Follow_Target(State: WalkingSquishyState): Vector3?
    local Root = Get_Character_Root(State.player)

    if not Root then
        return nil
    end

    local RawTarget = Root.Position
        - Root.CFrame.LookVector * FOLLOW_BEHIND_DISTANCE
        + Root.CFrame.RightVector * FOLLOW_SIDE_DISTANCE

    return Get_Grounded_Position(RawTarget, State.footOffset)
end

local function Look_At_Flat(Position: Vector3, Target: Vector3, Fallback: CFrame): CFrame
    local FlatTarget = Vector3.new(Target.X, Position.Y, Target.Z)

    if (FlatTarget - Position).Magnitude < 0.05 then
        return CFrame.new(Position) * Fallback.Rotation
    end

    return CFrame.lookAt(Position, FlatTarget)
end

local function Cleanup_User_Id(UserId: number)
    local State = WalkingSquishies[UserId]

    if not State then
        return
    end

    WalkingSquishies[UserId] = nil
    Stop_Animations(State.animations)

    if State.rope then
        State.rope:Destroy()
    end

    if State.handAnchor then
        State.handAnchor:Destroy()
    end

    if State.squishyAnchor then
        State.squishyAnchor:Destroy()
    end

    if State.model then
        State.model:Destroy()
    end
end

local function Get_Data_Final_Income_Per_Sec(Data: WalkingSquishyData): number
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

local function Spawn_Walking_Squishy(Player: Player, Data: WalkingSquishyData)
    local Existing = WalkingSquishies[Player.UserId]
    local FinalIncomePerSec = Get_Data_Final_Income_Per_Sec(Data)
    local Level = SquishyLevels.NormalizeLevel(Data.Level)
    local EventMutationList = EventMutations.NormalizeList(Data.EventMutations)
    local Scale = Get_Model_Scale(Data.Weight, Data.Rarity, Level)

    if Existing and Existing.guid == Data.ItemId and Existing.model.Parent then
        Existing.name = Data.Name
        Existing.rarity = Data.Rarity
        Existing.mutation = Data.Mutation
        Existing.eventMutations = EventMutationList
        Existing.level = Level
        Existing.incomePerSec = FinalIncomePerSec
        Existing.lassoName = Normalize_Lasso_Name(Data.LassoName)
        Existing.model:SetAttribute("Name", Data.Name)
        Existing.model:SetAttribute("Rarity", Data.Rarity)
        Existing.model:SetAttribute("Weight", Data.Weight)
        Existing.model:SetAttribute("Mutation", Data.Mutation)
        Existing.model:SetAttribute("EventMutations", EventMutations.EncodeAttribute(EventMutationList))
        Existing.model:SetAttribute("Level", Level)
        Existing.model:SetAttribute("FinalIncomePerSec", FinalIncomePerSec)
        EventMutationVFX.Sync(Existing.model, EventMutationList)
        pcall(function()
            Existing.model:ScaleTo(Scale)
        end)
        Refresh_Rope_Style(Existing, true)
        Update_Walking_Overhead(Existing)
        return
    end

    Cleanup_User_Id(Player.UserId)

    local Template = Squishies.GetModel(Data.Kind :: any, Data.Name, Data.Mutation)

    if not Template then
        return
    end

    local Model = Template:Clone()
    Model.Name = `WalkingSquishy_{Player.UserId}_{Data.ItemId}`
    Model:SetAttribute("WalkingSquishyOwnerUserId", Player.UserId)
    Model:SetAttribute("Name", Data.Name)
    Model:SetAttribute("Kind", Data.Kind)
    Model:SetAttribute("Rarity", Data.Rarity)
    Model:SetAttribute("Weight", Data.Weight)
    Model:SetAttribute("Mutation", Data.Mutation)
    Model:SetAttribute("EventMutations", EventMutations.EncodeAttribute(EventMutationList))
    Model:SetAttribute("Level", Level)
    Model:SetAttribute("FinalIncomePerSec", FinalIncomePerSec)

    pcall(function()
        Model:ScaleTo(Scale)
    end)

    Prepare_Model(Model)

    local FootOffset = Get_Model_Foot_Offset(Model)
    local RopeHeight = Get_Model_Rope_Height(Model)
    local HandAnchor, HandAttachment = Create_Hidden_Anchor(HAND_ANCHOR_NAME)
    local SquishyAnchor, SquishyAttachment = Create_Hidden_Anchor(SQUISHY_ANCHOR_NAME)
    local Rope = Create_Rope(HandAttachment, SquishyAttachment)
    local LassoName = Normalize_Lasso_Name(Data.LassoName)

    Model.Parent = Get_Follow_Folder()

    local Animations = Load_Animations(Model, Data.Kind)
    local State: WalkingSquishyState = {
        player = Player,
        guid = Data.ItemId,
        kind = Data.Kind,
        name = Data.Name,
        rarity = Data.Rarity,
        mutation = Data.Mutation,
        eventMutations = EventMutationList,
        level = Level,
        incomePerSec = FinalIncomePerSec,
        model = Model,
        footOffset = FootOffset,
        ropeHeight = RopeHeight,
        handAnchor = HandAnchor,
        squishyAnchor = SquishyAnchor,
        rope = Rope,
        animations = Animations,
        lassoName = LassoName,
        appliedRopeStyleKey = nil,
    }

    WalkingSquishies[Player.UserId] = State
    Refresh_Rope_Style(State, true)
    Update_Walking_Overhead(State)
    EventMutationVFX.Sync(Model, EventMutationList)

    local Target = Get_Follow_Target(State)

    if Target then
        Model:PivotTo(CFrame.new(Target))
        HandAnchor.Position = Get_Hand_Position(Player) or Target
        SquishyAnchor.Position = Target + Vector3.yAxis * RopeHeight
        Rope.Length = (HandAnchor.Position - SquishyAnchor.Position).Magnitude + ROPE_EXTRA_LENGTH
    end

    Set_Animation_State(State, false)
end

local function Process_Network()
    for _, Data in Network.WalkingSquishyChanged.Iter() do
        local UserId = Data.PlayerUserId

        if type(UserId) ~= "number" then
            continue
        end

        if not Data.Equipped then
            Cleanup_User_Id(UserId)
            continue
        end

        local Player = Players:GetPlayerByUserId(UserId)

        if Player then
            Spawn_Walking_Squishy(Player, Data :: any)
        end
    end
end

local function Update_State(State: WalkingSquishyState, DeltaTime: number): boolean
    if not State.player.Parent or not State.model.Parent then
        return false
    end

    local Root = Get_Character_Root(State.player)
    local Target = Get_Follow_Target(State)
    local HandPosition = Get_Hand_Position(State.player)

    if not Root or not Target or not HandPosition then
        return false
    end

    local CurrentCFrame = State.model:GetPivot()
    local CurrentPosition = CurrentCFrame.Position
    local Distance = (Target - CurrentPosition).Magnitude
    local NewPosition = Target

    if Distance <= TELEPORT_DISTANCE then
        local Alpha = 1 - math.exp(-FOLLOW_RESPONSIVENESS * DeltaTime)
        NewPosition = CurrentPosition:Lerp(Target, math.clamp(Alpha, 0, 1))
    end

    local IsWalking = Distance > WALK_DISTANCE_THRESHOLD
    local LookTarget = if IsWalking then Target else Root.Position
    local TargetCFrame = Look_At_Flat(NewPosition, LookTarget, CurrentCFrame)
    local RotationAlpha = math.clamp(1 - math.exp(-ROTATION_RESPONSIVENESS * DeltaTime), 0, 1)
    local FinalCFrame = CurrentCFrame:Lerp(TargetCFrame, RotationAlpha)
    FinalCFrame = CFrame.new(NewPosition) * FinalCFrame.Rotation

    State.model:PivotTo(FinalCFrame)
    State.handAnchor.Position = HandPosition
    State.squishyAnchor.Position = FinalCFrame.Position + Vector3.yAxis * State.ropeHeight
    Refresh_Rope_Style(State)
    State.rope.Length = (State.handAnchor.Position - State.squishyAnchor.Position).Magnitude + ROPE_EXTRA_LENGTH

    Set_Animation_State(State, IsWalking)

    return true
end

local function Update_All(DeltaTime: number)
    for UserId, State in WalkingSquishies do
        if not Update_State(State, DeltaTime) then
            Cleanup_User_Id(UserId)
        end
    end
end

local function Bind_Player(Player: Player)
    if BoundPlayers[Player] then
        return
    end

    BoundPlayers[Player] = true

    Player.CharacterRemoving:Connect(function()
        Cleanup_User_Id(Player.UserId)
    end)
end

for _, Player in Players:GetPlayers() do
    Bind_Player(Player)
end

Players.PlayerAdded:Connect(Bind_Player)
Players.PlayerRemoving:Connect(function(Player)
    Cleanup_User_Id(Player.UserId)
    BoundPlayers[Player] = nil
end)

LocalPlayer.CharacterRemoving:Connect(function()
    LastRequestedSquishyId = nil
    Network.WalkingSquishyRequest.Fire({
        ItemId = "",
        Equipped = false,
    })
end)

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        local Now = os.clock()
        local DeltaTime = math.clamp(Now - LastUpdateClock, 0, 1 / 15)
        LastUpdateClock = Now

        Request_Initial_Sync()
        Sync_Local_Equipped_Squishy()
        Process_Network()
        Update_All(DeltaTime)
    end,
    runConditions = {},
}
