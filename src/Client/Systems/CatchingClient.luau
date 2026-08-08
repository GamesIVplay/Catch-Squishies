local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Network = require(ReplicatedFirst.Network)

local CatchConfig = require(ReplicatedStorage.Shared.Modules.CatchConfig)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local LassoRig = require(ReplicatedStorage.Shared.Modules.LassoRig)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local MinigameClickEffect = require(script.Parent.Parent.Modules.MinigameClickEffect)
local Phases = require(ReplicatedStorage.Shared.Phases)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local peek = Fusion.peek
local LocalPlayer = Players.LocalPlayer

type RopeConstraintState = {
    Rope: RopeConstraint,
    Attachment0: Attachment?,
    Attachment1: Attachment?,
    Length: number,
    Visible: boolean,
    Enabled: boolean,
}

type LassoPartState = {
    Part: BasePart,
    CFrame: CFrame,
    Anchored: boolean,
    Transparency: number,
    CanCollide: boolean,
    CanTouch: boolean,
    CanQuery: boolean,
    CastShadow: boolean,
    JointStates: { { Joint: JointInstance, Enabled: boolean } },
    VisualState: any,
}

type CatchStartedData = {
    CatchId: string,
    TargetEntity: number,
    TargetName: string,
    TargetKind: string,
    TargetImage: string,
    TargetRarity: string?,
    Strength: number,
    ClicksNeeded: number,
    LockProgress: number,
    Progress: number,
}

type LassoVisual = {
    Destroy: (self: LassoVisual) -> (),
    AttachToTarget: (self: LassoVisual, Target: Model?, TargetEntity: number?) -> (),
    PullToCharacter: (self: LassoVisual, Character: Model?, Duration: number) -> (),
}

type RemoteThrowVisual = {
    Destroy: (self: RemoteThrowVisual) -> (),
}

type RemoteHeldLassoHideState = {
    TopState: any,
    BottomState: any,
    Rope: RopeConstraint?,
    RopeVisible: boolean?,
    RopeEnabled: boolean?,
}

type SpectatorLassoVisual = {
    Target: Model,
    Puller: Player,
    LassoName: string,
    Model: Model?,
    Top: BasePart?,
    Bottom: BasePart?,
    Rope: RopeConstraint?,
    Update: (self: SpectatorLassoVisual) -> boolean,
    Destroy: (self: SpectatorLassoVisual) -> (),
}

type ThrowCallbacks = {
    OnHit: ((TargetEntity: number) -> ())?,
    OnMiss: (() -> ())?,
}

type MovementFreezeState = {
    Humanoid: Humanoid?,
    WalkSpeed: number,
    JumpPower: number,
    JumpHeight: number,
    AutoRotate: boolean,
    Controls: any?,
}

type GuiVisibilityState = {
    Object: Instance,
    Property: "Visible" | "Enabled",
    Value: boolean,
}

type GuiMotionState = {
    Object: GuiObject,
    Position: UDim2,
    Visible: boolean,
}

type DisclaimerTextState = {
    Text: string,
    TextColor3: Color3,
    TextTransparency: number,
    Visible: boolean,
    Gradients: { UIGradient },
}

local Constants = {
    HELD_LASSO_MODEL_NAME = "ClientHeldLasso",
    REPLICATED_HELD_LASSO_MODEL_NAME = "ReplicatedHeldLasso",
    THROW_SOUND_NAME = "Swoosh",
    PULL_SOUND_NAME = "Rope Pull",
    PULL_CLICK_SOUND_NAME = "Click",
    CATCH_CLICK_PROMPT_TEXT = "Click for Squishy",
    CATCH_TAP_PROMPT_TEXT = "Tap the Screen",
    TARGET_ANCHOR_OFFSET = Vector3.new(0, 1, 0),
    STEALABLE_LOCK_IMAGE = "rbxassetid://81943438936797",
    SAFE_LOCK_IMAGE = "rbxassetid://103148524962018",
    STEALABLE_DISCLAIMER_TEXT = "Squishy can be stolen.",
    SAFE_DISCLAIMER_TEXT = "Squishy is safe.",
    SPECTATOR_LASSO_FOLDER_NAME = "SpectatorLassoVisuals",
    PULL_TARGET_USER_ID_ATTRIBUTE = "PullTargetUserId",
    PULL_PROGRESS_ATTRIBUTE = "PullProgress",
    PULL_LASSO_NAME_ATTRIBUTE = "PullLassoName",
    CATCH_COMPLETE_ID_ATTRIBUTE = "CatchCompleteId",
    CANCEL_BUTTON_BOUND_ATTRIBUTE = "CatchCancelButtonBound",
    CATCH_MINIGAME_ACTIVE_ATTRIBUTE = "CatchMinigameActive",
    CATCH_LASSO_BUSY_ATTRIBUTE = "CatchLassoBusy",
    CATCH_LASSO_LOCKED_ATTRIBUTE = "CatchLassoLocked",
    UI_BLOCKS_LASSO_THROW_ATTRIBUTE = "UiBlocksLassoThrow",
    RAYCAST_DISTANCE = CatchConfig.ThrowDistance,
    CUSTOM_HOTBAR_SLOT_NAMES = {
        [3] = "3",
        [4] = "4",
        [5] = "5",
        [6] = "6",
        [7] = "7",
    },
    THROW_AUTO_AIM_DOT = math.cos(math.rad(CatchConfig.ThrowAutoAimAngleDegrees)),
    THROW_TOP_ROTATION = CFrame.Angles(
        math.rad(CatchConfig.ThrowTopPitchDegrees),
        math.rad(CatchConfig.ThrowTopYawDegrees),
        math.rad(CatchConfig.ThrowTopRollDegrees)
    ),
    RARITY_DISPLAY_COLORS = {
        Common = Color3.fromRGB(120, 255, 120),
        Rare = Color3.fromRGB(75, 155, 255),
        Epic = Color3.fromRGB(185, 90, 255),
        Legendary = Color3.fromRGB(255, 190, 65),
        Secret = Color3.fromRGB(35, 35, 45),
        Prismatic = Color3.fromRGB(255, 105, 210),
        Divine = Color3.fromRGB(255, 245, 120),
        Exotic = Color3.fromRGB(255, 95, 65),
        Transcended = Color3.fromRGB(70, 255, 235),
    },
    CANCEL_BUTTON_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    CANCEL_BUTTON_HOVER_SCALE = 1.06,
    CANCEL_BUTTON_PRESS_SCALE = 0.92,
}

local RuntimeState = {
    InputBound = false,
    ActiveCatchId = nil :: string?,
    PendingTargetEntity = nil :: number?,
    PendingCatchCancelled = false,
    ActiveTargetModel = nil :: Model?,
    CurrentVisual = nil :: LassoVisual?,
    StruggleTrack = nil :: AnimationTrack?,
    PullTrack = nil :: AnimationTrack?,
    ActiveLassoSounds = {} :: { [string]: Sound },
    FaceTargetTween = nil :: Tween?,
    FrozenMovementState = nil :: MovementFreezeState?,
    InventoryVisibilityStates = nil :: { GuiVisibilityState }?,
    CatchHudMotionStates = nil :: { [GuiObject]: GuiMotionState }?,
    CatchHudTweens = {} :: { [GuiObject]: Tween },
    CoreBackpackEnabledState = nil :: boolean?,
    DisclaimerOriginalState = nil :: DisclaimerTextState?,
    CurrentClickCount = 0,
    NextThrowAllowedTime = 0,
    NextClickAllowedTime = 0,
    LastPullFeedbackTime = 0,
    CatchEnding = false,
    ActiveLockProgress = CatchConfig.LockProgress,
    SpectatorLassoVisuals = {} :: { [Model]: SpectatorLassoVisual },
    RemoteThrowVisuals = {} :: { [number]: RemoteThrowVisual },
    RemoteHeldLassoHideStates = {} :: { [Player]: RemoteHeldLassoHideState },
    Create_Lasso_Visual = nil :: ((Model?, Vector3, Vector3, Model?, number?, ThrowCallbacks?) -> LassoVisual?)?,
    AimRaycastParams = nil :: RaycastParams?,
    AimRaycastMap = nil :: Instance?,
    AimRaycastTerrain = nil :: Terrain?,
    AimRaycastIncludeCount = 0,
}
local Confetti = {
    PlayedTargets = {},
    PlayedCatchIds = {},
    PlayedPullSounds = {},
    EffectLifetime = 5,
    PullArcHeight = 5,
    EquipDelaySeconds = 0.2,
    EffectTemplate = nil,
    SoundTemplate = nil,
}

local MinigameGui: ScreenGui? = nil
local MinigameFrameObject: GuiObject? = nil
local MinigameFrameBasePosition: UDim2? = nil
local MinigameDisplay: GuiObject? = nil
local MinigameDisplayImage: GuiObject? = nil
local GreenBar: GuiObject? = nil
local GreenBarBaseSize: UDim2? = nil
local GreenBarProgressTween: Tween? = nil
local StrengthLabel: TextLabel? = nil
local TargetIcon: ImageLabel? = nil
local TotalClicksLabel: TextLabel? = nil
local LockIconImages: { GuiObject } = {}
local MinigameCancelButton: GuiButton? = nil
local MinigameIntroPositionTween: Tween? = nil
local MinigameIntroScaleTween: Tween? = nil
local MinigameIntroGeneration = 0

local function Is_Lasso_Equipped(): boolean
    return peek(FusionValues.EquippedInventorySlot) == "Lasso"
end

local function Is_Lasso_Throw_Blocked_By_Ui(): boolean
    return LocalPlayer:GetAttribute(Constants.UI_BLOCKS_LASSO_THROW_ATTRIBUTE) == true
end

local function Is_Tutorial_Active(): boolean
    if peek(FusionValues.TutorialStepReceived) ~= true then
        return false
    end

    return not TutorialSteps.Is_Complete(TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep)))
end

local function Equip_Caught_Squishy(ItemId: any, HotbarSlot: any)
    local SlotName = if type(HotbarSlot) == "number" then Constants.CUSTOM_HOTBAR_SLOT_NAMES[HotbarSlot] else nil

    if SlotName then
        FusionValues.EquippedInventoryItemId:set(nil)
        FusionValues.EquippedInventorySlot:set(SlotName)
        return
    end

    if type(ItemId) == "string" and ItemId ~= "" then
        FusionValues.EquippedInventorySlot:set(nil)
        FusionValues.EquippedInventoryItemId:set(ItemId)
    end
end

local function Get_Player_Controls(): any?
    local PlayerScripts = LocalPlayer:FindFirstChildOfClass("PlayerScripts")

    if not PlayerScripts then
        return nil
    end

    local PlayerModule = PlayerScripts:FindFirstChild("PlayerModule")

    if not PlayerModule or not PlayerModule:IsA("ModuleScript") then
        return nil
    end

    local Success, PlayerModuleResult = pcall(require, PlayerModule)

    if not Success or type(PlayerModuleResult) ~= "table" then
        return nil
    end

    local GetControls = PlayerModuleResult.GetControls

    if type(GetControls) ~= "function" then
        return nil
    end

    local ControlsSuccess, Controls = pcall(GetControls, PlayerModuleResult)

    if not ControlsSuccess then
        return nil
    end

    return Controls
end

local function Freeze_Player_For_Catch()
    if RuntimeState.FrozenMovementState then
        return
    end

    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local Controls = Get_Player_Controls()

    RuntimeState.FrozenMovementState = {
        Humanoid = Humanoid,
        WalkSpeed = if Humanoid then Humanoid.WalkSpeed else 16,
        JumpPower = if Humanoid then Humanoid.JumpPower else 50,
        JumpHeight = if Humanoid then Humanoid.JumpHeight else 7.2,
        AutoRotate = if Humanoid then Humanoid.AutoRotate else true,
        Controls = Controls,
    }

    if Controls and type(Controls.Disable) == "function" then
        pcall(Controls.Disable, Controls)
    end

    if not Humanoid then
        return
    end

    Humanoid.WalkSpeed = 0
    Humanoid.JumpPower = 0
    Humanoid.JumpHeight = 0
    Humanoid.AutoRotate = false
end

local function Unfreeze_Player_From_Catch()
    local State = RuntimeState.FrozenMovementState

    if not State then
        return
    end

    RuntimeState.FrozenMovementState = nil

    if State.Controls and type(State.Controls.Enable) == "function" then
        pcall(State.Controls.Enable, State.Controls)
    end

    local Humanoid = State.Humanoid

    if not Humanoid or not Humanoid.Parent then
        return
    end

    Humanoid.WalkSpeed = State.WalkSpeed
    Humanoid.JumpPower = State.JumpPower
    Humanoid.JumpHeight = State.JumpHeight
    Humanoid.AutoRotate = State.AutoRotate
end

local function Get_Roaming_Folder(): Folder?
    local Folder = workspace:FindFirstChild("RoamingSquishies")

    if Folder and Folder:IsA("Folder") then
        return Folder
    end

    return nil
end

local function Find_Target_Model_By_Entity(TargetEntity: number): Model?
    local Folder = Get_Roaming_Folder()

    if not Folder then
        return nil
    end

    for _, Child in Folder:GetChildren() do
        if Child:IsA("Model") and Child:GetAttribute("ServerEntity") == TargetEntity then
            return Child
        end
    end

    return nil
end

local function Is_Target_Locked_By_Another_Player(TargetModel: Model): boolean
    local LockedBy = TargetModel:GetAttribute("LockedBy")

    return type(LockedBy) == "number" and LockedBy ~= LocalPlayer.UserId
end

local function Get_Tutorial_Step(): number?
    if peek(FusionValues.TutorialStepReceived) ~= true then
        return nil
    end

    return TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep))
end

local function Is_Local_Target_Selectable(TargetModel: Model): boolean
    if Is_Target_Locked_By_Another_Player(TargetModel) then
        return false
    end

    local TargetUserId = TargetModel:GetAttribute(TutorialSteps.TargetUserIdAttribute)
    local TargetStep = TargetModel:GetAttribute(TutorialSteps.TargetStepAttribute)

    if type(TargetUserId) == "number" and TargetUserId ~= LocalPlayer.UserId then
        return false
    end

    local Step = Get_Tutorial_Step()

    if not Step then
        return type(TargetStep) ~= "number"
    end

    if TutorialSteps.Is_Complete(Step) then
        return true
    end

    if not TutorialSteps.Is_Catch_Step(Step) then
        return false
    end

    if type(TargetStep) == "number" and TargetStep ~= Step then
        return false
    end

    return TutorialSteps.Is_Catch_Rarity_Allowed(Step, TargetModel:GetAttribute("Rarity"))
end

local function Get_Local_Targets(): { Model }
    local Folder = Get_Roaming_Folder()
    local Targets = {}

    if not Folder then
        return Targets
    end

    for _, Child in Folder:GetChildren() do
        if
            Child:IsA("Model")
            and type(Child:GetAttribute("ServerEntity")) == "number"
            and Is_Local_Target_Selectable(Child)
        then
            table.insert(Targets, Child)
        end
    end

    return Targets
end

local function Get_Animations_Folder(): Folder?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Animations = Assets and Assets:FindFirstChild("Animations")

    if Animations and Animations:IsA("Folder") then
        return Animations
    end

    return nil
end

local function Find_Animation(AnimationName: string): Animation?
    local Animations = Get_Animations_Folder()
    local Animation = Animations and Animations:FindFirstChild(AnimationName)

    if Animation and Animation:IsA("Animation") then
        return Animation
    end

    return nil
end

local function Get_Animator(Character: Model?): Animator?
    if not Character then
        return nil
    end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")

    if not Humanoid then
        return nil
    end

    local Animator = Humanoid:FindFirstChildOfClass("Animator")

    if Animator then
        return Animator
    end

    Animator = Instance.new("Animator")
    Animator.Parent = Humanoid

    return Animator
end

local function Normalize_Name(Name: string): string
    return string.lower(string.gsub(Name, "%W", ""))
end

local function Find_Sound_Template(SoundName: string): Sound?
    local NormalizedTarget = Normalize_Name(SoundName)
    local Roots = { SoundService }
    local Assets = ReplicatedStorage:FindFirstChild("Assets")

    if Assets then
        table.insert(Roots, Assets)
    end

    for _, Root in Roots do
        local DirectSound = Root:FindFirstChild(SoundName, true)

        if DirectSound and DirectSound:IsA("Sound") then
            return DirectSound
        end

        for _, Descendant in Root:GetDescendants() do
            if Descendant:IsA("Sound") and Normalize_Name(Descendant.Name) == NormalizedTarget then
                return Descendant
            end
        end
    end

    return nil
end

local function Play_Interface_Sound(SoundName: string)
    local Template = Find_Sound_Template(SoundName)

    if not Template then
        return
    end

    local Sound = Template:Clone()

    Sound.Parent = SoundService
    Sound.TimePosition = 0
    Sound:Play()

    Debris:AddItem(Sound, math.max(3, Sound.TimeLength + 1))
end

local function Find_Player_Held_Lasso_Part(Player: Player, PartName: string): BasePart?
    local Character = Player.Character
    local HeldLasso = Character and Character:FindFirstChild(Constants.HELD_LASSO_MODEL_NAME)
    local Part = HeldLasso and HeldLasso:FindFirstChild(PartName, true)

    if Part and Part:IsA("BasePart") then
        return Part
    end

    return nil
end

local function Find_Player_Character_Sound_Part(Player: Player): BasePart?
    local Character = Player.Character

    if not Character then
        return nil
    end

    local Root = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart

    if Root and Root:IsA("BasePart") then
        return Root
    end

    local Hand = Character:FindFirstChild("RightHand") or Character:FindFirstChild("Right Arm")

    if Hand and Hand:IsA("BasePart") then
        return Hand
    end

    return nil
end

local function Find_Player_Lasso_Sound_Parent(Player: Player, PartName: string): BasePart?
    return Find_Player_Held_Lasso_Part(Player, PartName) or Find_Player_Character_Sound_Part(Player)
end

local function Find_Lasso_Sound_Parent(PartName: string): BasePart?
    return Find_Player_Lasso_Sound_Parent(LocalPlayer, PartName)
end

local function Play_Lasso_Sound(SoundName: string, PartName: string, InstanceName: string)
    local ParentPart = Find_Lasso_Sound_Parent(PartName)
    local Template = Find_Sound_Template(SoundName)

    if not ParentPart or not Template then
        return
    end

    local ExistingSound = RuntimeState.ActiveLassoSounds[InstanceName]

    if ExistingSound and ExistingSound.Parent then
        ExistingSound:Stop()
        ExistingSound:Destroy()
    end

    local Sound = Template:Clone()

    Sound.Name = InstanceName
    Sound.Parent = ParentPart
    Sound.TimePosition = 0
    Sound:Play()

    RuntimeState.ActiveLassoSounds[InstanceName] = Sound

    Sound.Ended:Once(function()
        if RuntimeState.ActiveLassoSounds[InstanceName] == Sound then
            RuntimeState.ActiveLassoSounds[InstanceName] = nil
        end

        Sound:Destroy()
    end)

    Debris:AddItem(Sound, 8)
end

local function Play_One_Shot_Lasso_Sound(SoundName: string, PartName: string, InstanceName: string): boolean
    local ParentPart = Find_Lasso_Sound_Parent(PartName)
    local Template = Find_Sound_Template(SoundName)

    if not ParentPart or not Template then
        return false
    end

    local Sound = Template:Clone()

    Sound.Name = InstanceName
    Sound.Parent = ParentPart
    Sound.TimePosition = 0
    Sound:Play()

    Sound.Ended:Once(function()
        Sound:Destroy()
    end)

    Debris:AddItem(Sound, math.max(3, Sound.TimeLength + 1))

    return true
end

local function Play_One_Shot_Lasso_Sound_For_Player(
    Player: Player,
    SoundName: string,
    PartName: string,
    InstanceName: string
): boolean
    local ParentPart = Find_Player_Lasso_Sound_Parent(Player, PartName)
    local Template = Find_Sound_Template(SoundName)

    if not ParentPart or not Template then
        return false
    end

    local Sound = Template:Clone()

    Sound.Name = InstanceName
    Sound.Parent = ParentPart
    Sound.TimePosition = 0
    Sound:Play()

    Sound.Ended:Once(function()
        Sound:Destroy()
    end)

    Debris:AddItem(Sound, math.max(3, Sound.TimeLength + 1))

    return true
end

local function Play_Character_Animation(
    AnimationName: string,
    Looped: boolean,
    Priority: Enum.AnimationPriority?
): AnimationTrack?
    local Animator = Get_Animator(LocalPlayer.Character)
    local Animation = Find_Animation(AnimationName)

    if not Animator or not Animation then
        return nil
    end

    local Track = Animator:LoadAnimation(Animation)
    Track.Looped = Looped
    Track.Priority = Priority or Enum.AnimationPriority.Action
    Track:Play(0.08)

    if not Looped then
        Track.Stopped:Once(function()
            Track:Destroy()
        end)
    end

    return Track
end

local function Stop_Struggle()
    if not RuntimeState.StruggleTrack then
        return
    end

    RuntimeState.StruggleTrack:Stop(0.1)
    RuntimeState.StruggleTrack:Destroy()
    RuntimeState.StruggleTrack = nil
end

local function Stop_Pull()
    if not RuntimeState.PullTrack then
        return
    end

    RuntimeState.PullTrack:Stop(0.05)
    RuntimeState.PullTrack:Destroy()
    RuntimeState.PullTrack = nil
end

local function Play_Pull_Track(PlaySound: boolean?)
    Stop_Pull()

    if PlaySound ~= false then
        Play_Lasso_Sound(Constants.PULL_SOUND_NAME, "Bottom", "CatchRopePullSound")
    end

    RuntimeState.PullTrack = Play_Character_Animation("Lasso Pull", false, Enum.AnimationPriority.Action4)

    if RuntimeState.PullTrack then
        local Track = RuntimeState.PullTrack

        Track.Stopped:Once(function()
            if RuntimeState.PullTrack == Track then
                RuntimeState.PullTrack = nil
            end
        end)
    end
end

local function Play_Throw()
    Play_Lasso_Sound(Constants.THROW_SOUND_NAME, "Top", "CatchThrowSwooshSound")
    Play_Character_Animation("Lasso Throw", false, Enum.AnimationPriority.Action)
end

local function Play_Struggle()
    Stop_Struggle()
    RuntimeState.StruggleTrack = Play_Character_Animation("Lasso Struggle", true, Enum.AnimationPriority.Action)
end

local function Play_Click_Pull()
    local Now = os.clock()

    if not Play_One_Shot_Lasso_Sound(Constants.PULL_CLICK_SOUND_NAME, "Bottom", "CatchPullClickSound") then
        Play_One_Shot_Lasso_Sound(Constants.PULL_SOUND_NAME, "Bottom", "CatchPullClickSound")
    end

    if Now - RuntimeState.LastPullFeedbackTime < CatchConfig.ClickFeedbackCooldownSeconds then
        return
    end

    RuntimeState.LastPullFeedbackTime = Now
    Play_Pull_Track()
end

local function Play_Pull()
    RuntimeState.LastPullFeedbackTime = os.clock()
    Stop_Struggle()
    Play_Pull_Track()
end

local function Get_Held_Lasso_Model(Character: Model?): Model?
    if not Character then
        return nil
    end

    local HeldLasso = Character:FindFirstChild(Constants.HELD_LASSO_MODEL_NAME)

    if HeldLasso and HeldLasso:IsA("Model") then
        return HeldLasso
    end

    HeldLasso = Character:FindFirstChild(Constants.REPLICATED_HELD_LASSO_MODEL_NAME)

    return if HeldLasso and HeldLasso:IsA("Model") then HeldLasso else nil
end

local function Get_Held_Lasso_Top(Character: Model?): BasePart?
    local HeldLasso = Get_Held_Lasso_Model(Character)
    local LassoTop = HeldLasso and HeldLasso:FindFirstChild("Top", true)

    if LassoTop and LassoTop:IsA("BasePart") then
        return LassoTop
    end

    return nil
end

local function Get_Held_Lasso_Bottom(Character: Model?): BasePart?
    local HeldLasso = Get_Held_Lasso_Model(Character)
    local LassoBottom = HeldLasso and HeldLasso:FindFirstChild("Bottom", true)

    if LassoBottom and LassoBottom:IsA("BasePart") then
        return LassoBottom
    end

    return nil
end

local function Get_Held_Lasso_Rope(HeldLasso: Model): RopeConstraint?
    local Bottom = HeldLasso:FindFirstChild("Bottom", true)
    local BottomAttachment = Bottom and Bottom:FindFirstChildWhichIsA("Attachment", true)
    local Rope = BottomAttachment and BottomAttachment:FindFirstChildWhichIsA("RopeConstraint")

    if Rope then
        return Rope
    end

    return HeldLasso:FindFirstChildWhichIsA("RopeConstraint", true)
end

local function Get_Rope_Attachment(Part: BasePart?): Attachment?
    if not Part then
        return nil
    end

    local Attachment = Part:FindFirstChild("RopeAttachment") or Part:FindFirstChildWhichIsA("Attachment")

    if Attachment and Attachment:IsA("Attachment") then
        return Attachment
    end

    return nil
end

local function Get_Hand_Source_Part(Character: Model?): BasePart?
    if not Character then
        return nil
    end

    local Source = Character:FindFirstChild("RightHand")
        or Character:FindFirstChild("Right Arm")
        or Character:FindFirstChild("HumanoidRootPart")
        or Character.PrimaryPart

    if Source and Source:IsA("BasePart") then
        return Source
    end

    return nil
end

local function Get_Source_Part(Character: Model?): BasePart?
    return Get_Held_Lasso_Top(Character) or Get_Hand_Source_Part(Character)
end

local function Get_Target_Part(Target: Instance?): BasePart?
    if not Target then
        return nil
    end

    if Target:IsA("BasePart") then
        return Target
    end

    if not Target:IsA("Model") then
        return nil
    end

    local PrimaryPart = Target.PrimaryPart

    if PrimaryPart then
        return PrimaryPart
    end

    local Root = Target:FindFirstChild("HumanoidRootPart")
        or Target:FindFirstChild("Root")
        or Target:FindFirstChildWhichIsA("BasePart", true)

    if Root and Root:IsA("BasePart") then
        return Root
    end

    return nil
end

local function Get_Target_Position(Target: Instance?): Vector3?
    local TargetPart = Get_Target_Part(Target)

    if TargetPart then
        return TargetPart.Position + Constants.TARGET_ANCHOR_OFFSET
    end

    if Target and Target:IsA("Model") then
        return Target:GetPivot().Position + Constants.TARGET_ANCHOR_OFFSET
    end

    return nil
end

local function Face_Target(Target: Instance?)
    local TargetPosition = Get_Target_Position(Target)
    local Character = LocalPlayer.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if not TargetPosition or not Root or not Root:IsA("BasePart") then
        return
    end

    local RootPosition = Root.Position
    local LookAtPosition = Vector3.new(TargetPosition.X, RootPosition.Y, TargetPosition.Z)

    if (LookAtPosition - RootPosition).Magnitude < 0.05 then
        return
    end

    if RuntimeState.FaceTargetTween then
        RuntimeState.FaceTargetTween:Cancel()
    end

    RuntimeState.FaceTargetTween =
        TweenService:Create(Root, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CFrame = CFrame.lookAt(RootPosition, LookAtPosition),
        })
    RuntimeState.FaceTargetTween:Play()
end

local function Is_Point_In_Model_Box(Point: Vector3, Model: Model): boolean
    local BoxCFrame, BoxSize = Model:GetBoundingBox()
    local Padding = CatchConfig.ThrowHitPadding
    local HalfSize = (BoxSize + Vector3.new(Padding * 2, Padding * 2, Padding * 2)) * 0.5
    local LocalPoint = BoxCFrame:PointToObjectSpace(Point)

    return math.abs(LocalPoint.X) <= HalfSize.X and math.abs(LocalPoint.Z) <= HalfSize.Z
end

local function Get_Model_Aim_Radius(Model: Model): number
    local _, BoxSize = Model:GetBoundingBox()

    return math.max(BoxSize.X, BoxSize.Y, BoxSize.Z) * 0.5 + CatchConfig.ThrowAutoAimRadius
end

local function Get_Auto_Aimed_Direction(Origin: Vector3, Direction: Vector3): Vector3?
    local BestDirection: Vector3? = nil
    local BestScore = math.huge

    for _, TargetModel in Get_Local_Targets() do
        if not TargetModel.Parent then
            continue
        end

        local TargetEntity = TargetModel:GetAttribute("ServerEntity")

        if type(TargetEntity) ~= "number" then
            continue
        end

        local TargetPosition = Get_Target_Position(TargetModel)

        if not TargetPosition then
            continue
        end

        TargetPosition = Vector3.new(TargetPosition.X, Origin.Y, TargetPosition.Z)

        local Offset = TargetPosition - Origin
        local Distance = Offset.Magnitude

        if Distance < 0.001 or Distance > Constants.RAYCAST_DISTANCE then
            continue
        end

        local TargetDirection = Offset.Unit

        if TargetDirection:Dot(Direction) < Constants.THROW_AUTO_AIM_DOT then
            continue
        end

        local DistanceAlongRay = math.clamp(Offset:Dot(Direction), 0, Constants.RAYCAST_DISTANCE)
        local ClosestPoint = Origin + Direction * DistanceAlongRay
        local MissDistance = (TargetPosition - ClosestPoint).Magnitude

        if MissDistance > Get_Model_Aim_Radius(TargetModel) then
            continue
        end

        local Score = MissDistance + Distance * 0.03

        if Score < BestScore then
            BestScore = Score
            BestDirection = TargetDirection
        end
    end

    return BestDirection
end

local function Find_Local_Hit_Target(Point: Vector3): (number?, Model?)
    local BestTargetEntity: number? = nil
    local BestTargetModel: Model? = nil
    local BestDistance = math.huge

    for _, TargetModel in Get_Local_Targets() do
        if not TargetModel.Parent then
            continue
        end

        if not Is_Point_In_Model_Box(Point, TargetModel) then
            continue
        end

        local TargetEntity = TargetModel:GetAttribute("ServerEntity")

        if type(TargetEntity) ~= "number" then
            continue
        end

        local TargetPivotPosition = TargetModel:GetPivot().Position
        local Distance = (Vector3.new(TargetPivotPosition.X, Point.Y, TargetPivotPosition.Z) - Point).Magnitude

        if Distance < BestDistance then
            BestDistance = Distance
            BestTargetEntity = TargetEntity
            BestTargetModel = TargetModel
        end
    end

    return BestTargetEntity, BestTargetModel
end

local function Find_Local_Hit_Target_On_Segment(From: Vector3, To: Vector3): (number?, Model?)
    local Delta = To - From
    local Distance = Delta.Magnitude
    local Steps = math.max(1, math.ceil(Distance / CatchConfig.ThrowLocalHitStep))

    for Step = 0, Steps do
        local Alpha = Step / Steps
        local TargetEntity, TargetModel = Find_Local_Hit_Target(From:Lerp(To, Alpha))

        if TargetEntity and TargetModel then
            return TargetEntity, TargetModel
        end
    end

    return nil, nil
end

local function Get_Throw_Duration(From: Vector3, To: Vector3): number
    local Distance = (To - From).Magnitude

    return math.clamp(
        Distance / CatchConfig.ThrowTravelSpeed,
        CatchConfig.MinThrowDuration,
        CatchConfig.MaxThrowDuration
    )
end

local function Get_Attachment_Position(Part: BasePart?): Vector3?
    if not Part then
        return nil
    end

    local Attachment = Part:FindFirstChild("RightGripAttachment") or Get_Rope_Attachment(Part)

    if Attachment and Attachment:IsA("Attachment") then
        return Attachment.WorldPosition
    end

    return Part.Position
end

local function Get_Player_Rope_Position(Character: Model?): Vector3?
    return Get_Attachment_Position(Get_Held_Lasso_Bottom(Character))
        or Get_Attachment_Position(Get_Held_Lasso_Top(Character))
        or Get_Attachment_Position(Get_Hand_Source_Part(Character))
end

local function Make_Hidden_Rope_Anchor(Name: string, StartPosition: Vector3): (Part, Attachment)
    local Anchor = Instance.new("Part")

    Anchor.Name = Name
    Anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    Anchor.Transparency = 1
    Anchor.Anchored = true
    Anchor.CanCollide = false
    Anchor.CanTouch = false
    Anchor.CanQuery = false
    Anchor.CastShadow = false
    Anchor.Position = StartPosition
    Anchor.Parent = workspace

    local Attachment = Instance.new("Attachment")

    Attachment.Name = "LassoAttachment"
    Attachment.Parent = Anchor

    return Anchor, Attachment
end

local function Update_Rope_Length(Rope: RopeConstraint)
    if not Rope.Parent or not Rope.Attachment0 or not Rope.Attachment1 then
        return
    end

    Rope.Length = (Rope.Attachment0.WorldPosition - Rope.Attachment1.WorldPosition).Magnitude
        + CatchConfig.RopeExtraLength
end

function Confetti.Get_Effect_Template(): Attachment?
    if Confetti.EffectTemplate and Confetti.EffectTemplate.Parent then
        return Confetti.EffectTemplate
    end

    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Effects = Assets and Assets:FindFirstChild("Effects")
    local VFX = Assets and Assets:FindFirstChild("VFX")
    local Effect = (Effects and Effects:FindFirstChild("Confetti")) or (VFX and VFX:FindFirstChild("Confetti"))

    if Effect and Effect:IsA("Attachment") then
        Confetti.EffectTemplate = Effect
        return Effect
    end

    return nil
end

function Confetti.Get_Sound_Template(): Sound?
    if Confetti.SoundTemplate and Confetti.SoundTemplate.Parent then
        return Confetti.SoundTemplate
    end

    local WorldSounds = SoundService:FindFirstChild("World")
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local AssetSounds = Assets and Assets:FindFirstChild("Sounds")
    local AssetWorldSounds = AssetSounds and AssetSounds:FindFirstChild("World")
    local Sound = (WorldSounds and WorldSounds:FindFirstChild("Confetti"))
        or (AssetWorldSounds and AssetWorldSounds:FindFirstChild("Confetti"))

    if Sound and Sound:IsA("Sound") then
        Confetti.SoundTemplate = Sound
        return Sound
    end

    return nil
end

function Confetti.Get_Puller_Character(TargetModel: Model?): Model?
    if TargetModel then
        local PullerUserId = TargetModel:GetAttribute(Constants.PULL_TARGET_USER_ID_ATTRIBUTE)
        local Puller = if type(PullerUserId) == "number" then Players:GetPlayerByUserId(PullerUserId) else nil

        if Puller and Puller.Character then
            return Puller.Character
        end
    end

    return LocalPlayer.Character
end

function Confetti.Play_For_Character(Character: Model?)
    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")

    if not RootPart or not RootPart:IsA("BasePart") then
        return
    end

    local SoundTemplate = Confetti.Get_Sound_Template()

    if SoundTemplate then
        local Sound = SoundTemplate:Clone()

        Sound.Parent = RootPart
        Sound.PlayOnRemove = true
        Sound:Destroy()
    end

    local EffectTemplate = Confetti.Get_Effect_Template()

    if not EffectTemplate then
        return
    end

    local Effect = EffectTemplate:Clone()

    Effect.Parent = RootPart

    for _, Inst in Effect:GetDescendants() do
        if Inst:IsA("ParticleEmitter") then
            local EmitCount = Inst:GetAttribute("EmitCount")

            Inst:Emit(if type(EmitCount) == "number" then EmitCount else 1)
        end
    end

    Debris:AddItem(Effect, Confetti.EffectLifetime)
end

function Confetti.Play_For_Target(TargetModel: Model?)
    Confetti.Play_For_Character(Confetti.Get_Puller_Character(TargetModel))
end

function Confetti.Get_Debris_Parent(): Instance
    return workspace:FindFirstChild("Debris") or workspace
end

function Confetti.Prepare_Pull_Model(Model: Model)
    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Descendant.Anchored = true
            Descendant.CanCollide = false
            Descendant.CanTouch = false
            Descendant.CanQuery = false
            Descendant.Massless = true
            Descendant.AssemblyLinearVelocity = Vector3.zero
            Descendant.AssemblyAngularVelocity = Vector3.zero
        elseif Descendant:IsA("Script") or Descendant:IsA("LocalScript") then
            Descendant:Destroy()
        end
    end
end

function Confetti.Hide_Source_Model(TargetModel: Model)
    LassoRig.Set_Visual_Instance_Visible(TargetModel, false)

    for _, Descendant in TargetModel:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Descendant.LocalTransparencyModifier = 1
        end
    end
end

function Confetti.Get_Completion_CFrame(TargetModel: Model): CFrame
    local CompletionCFrame = TargetModel:GetAttribute("CatchCompleteCFrame")

    if typeof(CompletionCFrame) == "CFrame" then
        return CompletionCFrame
    end

    return TargetModel:GetPivot()
end

function Confetti.Normalize_Catch_Id(CatchId: any): string?
    return if type(CatchId) == "string" and CatchId ~= "" then CatchId else nil
end

function Confetti.Has_Played_Catch(CatchId: any): boolean
    local NormalizedCatchId = Confetti.Normalize_Catch_Id(CatchId)

    return NormalizedCatchId ~= nil and Confetti.PlayedCatchIds[NormalizedCatchId] == true
end

function Confetti.Mark_Catch_Played(CatchId: any): boolean
    local NormalizedCatchId = Confetti.Normalize_Catch_Id(CatchId)

    if not NormalizedCatchId then
        return true
    end

    if Confetti.PlayedCatchIds[NormalizedCatchId] then
        return false
    end

    Confetti.PlayedCatchIds[NormalizedCatchId] = true

    task.delay(CatchConfig.PullDurationSeconds + 5, function()
        Confetti.PlayedCatchIds[NormalizedCatchId] = nil
    end)

    return true
end

function Confetti.Play_Pull_To_Character(
    TargetModel: Model?,
    Character: Model?,
    Duration: number,
    OnComplete: (() -> ())?
): boolean
    local DidComplete = false

    local function Complete()
        if DidComplete then
            return
        end

        DidComplete = true
        Confetti.Play_For_Character(Character)

        if OnComplete then
            task.defer(OnComplete)
        end
    end

    if not TargetModel or not TargetModel.Parent or not Character then
        Complete()
        return false
    end

    local RootPart = Character:FindFirstChild("HumanoidRootPart")

    if not RootPart or not RootPart:IsA("BasePart") then
        Complete()
        return false
    end

    local StartCFrame = Confetti.Get_Completion_CFrame(TargetModel)
    local StartPosition = StartCFrame.Position
    local EndPosition = RootPart.Position
    local MidPosition = (StartPosition + EndPosition) / 2 + Vector3.new(0, Confetti.PullArcHeight, 0)
    local SafeDuration = math.max(Duration, 0.05)
    local Elapsed = 0
    local Rotation = StartCFrame.Rotation
    local Connection: RBXScriptConnection? = nil
    local WasArchivable = TargetModel.Archivable

    TargetModel.Archivable = true

    local PullModel = TargetModel:Clone()

    TargetModel.Archivable = WasArchivable

    if not PullModel then
        Complete()
        return false
    end

    Confetti.Prepare_Pull_Model(PullModel)
    PullModel:PivotTo(StartCFrame)
    PullModel.Parent = Confetti.Get_Debris_Parent()
    Confetti.Hide_Source_Model(TargetModel)

    Connection = RunService.RenderStepped:Connect(function(DeltaTime)
        if not PullModel.Parent then
            if Connection then
                Connection:Disconnect()
            end

            Complete()
            return
        end

        Elapsed += DeltaTime

        local Alpha = math.clamp(Elapsed / SafeDuration, 0, 1)
        local T = Alpha
        local Position = (1 - T) ^ 2 * StartPosition + 2 * (1 - T) * T * MidPosition + T ^ 2 * EndPosition

        PullModel:PivotTo(CFrame.new(Position) * Rotation)

        if Alpha < 1 then
            return
        end

        if Connection then
            Connection:Disconnect()
            Connection = nil
        end

        PullModel:Destroy()
        Complete()
    end)

    return true
end

function Confetti.Play_Success_Once(TargetModel: Model?, OnComplete: (() -> ())?, CatchId: string?)
    local EffectiveCatchId = CatchId

    if not EffectiveCatchId and TargetModel then
        EffectiveCatchId = Confetti.Normalize_Catch_Id(TargetModel:GetAttribute(Constants.CATCH_COMPLETE_ID_ATTRIBUTE))
    end

    if EffectiveCatchId and not Confetti.Mark_Catch_Played(EffectiveCatchId) then
        if OnComplete then
            task.delay(CatchConfig.PullDurationSeconds, OnComplete)
        end

        return
    end

    if TargetModel then
        if Confetti.PlayedTargets[TargetModel] then
            if OnComplete then
                task.delay(CatchConfig.PullDurationSeconds, OnComplete)
            end

            return
        end

        Confetti.PlayedTargets[TargetModel] = true
    end

    Confetti.Play_Pull_To_Character(
        TargetModel,
        Confetti.Get_Puller_Character(TargetModel),
        CatchConfig.PullDurationSeconds,
        OnComplete
    )
end

function Confetti.Play_Replicated_Pull_Effect(PlayerUserId: number, CatchId: string?)
    if PlayerUserId == LocalPlayer.UserId then
        return
    end

    local Player = Players:GetPlayerByUserId(PlayerUserId)

    if not Player then
        return
    end

    if CatchId and not Confetti.PlayedPullSounds[CatchId] then
        Confetti.PlayedPullSounds[CatchId] = true
        task.delay(CatchConfig.PullDurationSeconds + 5, function()
            Confetti.PlayedPullSounds[CatchId] = nil
        end)
        Play_One_Shot_Lasso_Sound_For_Player(
            Player,
            Constants.PULL_SOUND_NAME,
            "Bottom",
            "CatchReplicatedRopePullSound"
        )
    elseif not CatchId then
        Play_One_Shot_Lasso_Sound_For_Player(
            Player,
            Constants.PULL_SOUND_NAME,
            "Bottom",
            "CatchReplicatedRopePullSound"
        )
    end
end

local function Get_Spectator_Lasso_Folder(): Folder
    local Folder = workspace:FindFirstChild(Constants.SPECTATOR_LASSO_FOLDER_NAME)

    if Folder and Folder:IsA("Folder") then
        return Folder
    end

    Folder = Instance.new("Folder")
    Folder.Name = Constants.SPECTATOR_LASSO_FOLDER_NAME
    Folder.Parent = workspace

    return Folder
end

local function Get_Or_Create_Attachment(Part: BasePart, Name: string): Attachment
    local Attachment = Part:FindFirstChild(Name) or Part:FindFirstChildWhichIsA("Attachment")

    if Attachment and Attachment:IsA("Attachment") then
        return Attachment
    end

    local NewAttachment = Instance.new("Attachment")

    NewAttachment.Name = Name
    NewAttachment.Parent = Part

    return NewAttachment
end

local function Prepare_Spectator_Lasso_Part(Part: BasePart)
    Part.Anchored = true
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.CastShadow = false
    Part.Massless = true
    Part.AssemblyLinearVelocity = Vector3.zero
    Part.AssemblyAngularVelocity = Vector3.zero
end

local function Get_Target_Lasso_Name(TargetModel: Model): string
    local LassoName = TargetModel:GetAttribute(Constants.PULL_LASSO_NAME_ATTRIBUTE)

    if type(LassoName) == "string" and Lassos.Get(LassoName) then
        return LassoName
    end

    return Lassos.Default
end

local function Create_Spectator_Lasso_Visual(
    TargetModel: Model,
    Puller: Player,
    LassoName: string
): SpectatorLassoVisual?
    local Template = LassoRig.Find_Template(LassoName) or LassoRig.Find_Template(Lassos.Default)

    if not Template then
        return nil
    end

    local Model = Template:Clone()

    Model.Name = `SpectatorLasso_{Puller.UserId}_{TargetModel.Name}`
    Model:SetAttribute("LassoName", LassoName)
    Model.Parent = Get_Spectator_Lasso_Folder()

    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Prepare_Spectator_Lasso_Part(Descendant)
        end
    end

    local Top = LassoRig.Get_Top(Model)
    local Bottom = LassoRig.Get_Bottom(Model)

    if not Top or not Bottom then
        Model:Destroy()
        return nil
    end

    LassoRig.Set_Visual_Instance_Visible(Top, false)
    LassoRig.Set_Visual_Instance_Visible(Bottom, false)

    local TopAttachment = Get_Or_Create_Attachment(Top, "RopeAttachment")
    local BottomAttachment = Get_Or_Create_Attachment(Bottom, "RopeAttachment")
    local Rope = LassoRig.Get_Rope(Model)

    if not Rope then
        Rope = Instance.new("RopeConstraint")
        Rope.Name = "SpectatorLassoRope"
        Rope.Thickness = 0.08
        Rope.Parent = Model
    end

    local function Configure_Rope(): boolean
        if not Model.Parent or not Top.Parent or not Bottom.Parent then
            return false
        end

        if not TopAttachment.Parent then
            TopAttachment = Get_Or_Create_Attachment(Top, "RopeAttachment")
        end

        if not BottomAttachment.Parent then
            BottomAttachment = Get_Or_Create_Attachment(Bottom, "RopeAttachment")
        end

        if not Rope or not Rope.Parent then
            Rope = Instance.new("RopeConstraint")
            Rope.Name = "SpectatorLassoRope"
            Rope.Thickness = 0.08
        end

        if Rope.Parent ~= Model then
            Rope.Parent = Model
        end

        Rope.Attachment0 = BottomAttachment
        Rope.Attachment1 = TopAttachment
        Rope.Visible = true
        Rope.Enabled = true

        return true
    end

    if not Configure_Rope() then
        Model:Destroy()
        return nil
    end

    local Visual = {
        Target = TargetModel,
        Puller = Puller,
        LassoName = LassoName,
        Model = Model,
        Top = Top,
        Bottom = Bottom,
        Rope = Rope,
    } :: SpectatorLassoVisual

    function Visual:Update(): boolean
        if not self.Target.Parent or not self.Puller.Parent or not self.Model or not self.Model.Parent then
            return false
        end

        if not self.Top or not self.Top.Parent or not self.Bottom or not self.Bottom.Parent then
            return false
        end

        if not Configure_Rope() then
            return false
        end

        self.Rope = Rope

        local PullerPosition = Get_Player_Rope_Position(self.Puller.Character)
        local TargetPosition = Get_Target_Position(self.Target)

        if not PullerPosition or not TargetPosition then
            LassoRig.Set_Visual_Instance_Visible(self.Top, false)
            LassoRig.Set_Visual_Instance_Visible(self.Bottom, false)
            return false
        end

        if self.Bottom and self.Bottom.Parent then
            self.Bottom.CFrame = CFrame.new(PullerPosition)
            LassoRig.Set_Visual_Instance_Visible(self.Bottom, true, 0)
        end

        if self.Top and self.Top.Parent then
            local FlatToPuller =
                Vector3.new(PullerPosition.X - TargetPosition.X, 0, PullerPosition.Z - TargetPosition.Z)

            self.Top.CFrame = if FlatToPuller.Magnitude > 0.001
                then CFrame.lookAt(TargetPosition, TargetPosition + FlatToPuller.Unit)
                else CFrame.new(TargetPosition)
            LassoRig.Set_Visual_Instance_Visible(self.Top, true, 0)
        end

        if self.Rope then
            Update_Rope_Length(self.Rope)
        end

        return true
    end

    function Visual:Destroy()
        if self.Model and self.Model.Parent then
            self.Model:Destroy()
        end

        self.Model = nil
        self.Top = nil
        self.Bottom = nil
        self.Rope = nil
    end

    if not Visual:Update() then
        Visual:Destroy()
        return nil
    end

    return Visual
end

local function Destroy_Spectator_Lasso_Visual(TargetModel: Model)
    local Visual = RuntimeState.SpectatorLassoVisuals[TargetModel]

    if not Visual then
        return
    end

    RuntimeState.SpectatorLassoVisuals[TargetModel] = nil
    Visual:Destroy()
end

local function Restore_Remote_Held_Lasso_State(Player: Player)
    local State = RuntimeState.RemoteHeldLassoHideStates[Player]

    if not State then
        return
    end

    RuntimeState.RemoteHeldLassoHideStates[Player] = nil

    LassoRig.Restore_Visual_State(State.TopState)
    LassoRig.Restore_Visual_State(State.BottomState)

    if State.Rope and State.Rope.Parent then
        if State.RopeVisible ~= nil then
            State.Rope.Visible = State.RopeVisible
        end

        if State.RopeEnabled ~= nil then
            State.Rope.Enabled = State.RopeEnabled
        end
    end
end

local function Set_Remote_Held_Lasso_Hidden(Player: Player, Hidden: boolean)
    if Player == LocalPlayer then
        return
    end

    if not Hidden then
        Restore_Remote_Held_Lasso_State(Player)
        return
    end

    if RuntimeState.RemoteHeldLassoHideStates[Player] then
        return
    end

    local HeldLasso = Get_Held_Lasso_Model(Player.Character)

    if not HeldLasso then
        return
    end

    local Top = LassoRig.Get_Top(HeldLasso)
    local Bottom = LassoRig.Get_Bottom(HeldLasso)
    local Rope = LassoRig.Get_Rope(HeldLasso)
    local State = {
        TopState = LassoRig.Capture_Visual_State(Top),
        BottomState = LassoRig.Capture_Visual_State(Bottom),
        Rope = Rope,
        RopeVisible = if Rope then Rope.Visible else nil,
        RopeEnabled = if Rope then Rope.Enabled else nil,
    }

    RuntimeState.RemoteHeldLassoHideStates[Player] = State

    LassoRig.Set_Visual_State_Visible(State.TopState, false)
    LassoRig.Set_Visual_State_Visible(State.BottomState, false)

    if Rope then
        Rope.Visible = false
        Rope.Enabled = false
    end
end

local function Update_Spectator_Lasso_Visuals()
    local Folder = Get_Roaming_Folder()
    local SeenTargets: { [Model]: boolean } = {}
    local ActivePullers: { [Player]: boolean } = {}

    if Folder then
        for _, Child in Folder:GetChildren() do
            if not Child:IsA("Model") then
                continue
            end

            local PullerUserId = Child:GetAttribute(Constants.PULL_TARGET_USER_ID_ATTRIBUTE)
            local PullProgress = Child:GetAttribute(Constants.PULL_PROGRESS_ATTRIBUTE)

            if type(PullProgress) == "number" and PullProgress >= 1 then
                local CatchId = Confetti.Normalize_Catch_Id(Child:GetAttribute(Constants.CATCH_COMPLETE_ID_ATTRIBUTE))

                Confetti.Play_Success_Once(Child, nil, CatchId)
            end

            if type(PullerUserId) ~= "number" or type(PullProgress) ~= "number" then
                continue
            end

            if PullerUserId == LocalPlayer.UserId then
                continue
            end

            local Puller = Players:GetPlayerByUserId(PullerUserId)

            if not Puller then
                continue
            end

            local ThrowVisual = RuntimeState.RemoteThrowVisuals[Puller.UserId]

            if ThrowVisual then
                ThrowVisual:Destroy()
                RuntimeState.RemoteThrowVisuals[Puller.UserId] = nil
            end

            ActivePullers[Puller] = true

            local LassoName = Get_Target_Lasso_Name(Child)
            local ExistingVisual = RuntimeState.SpectatorLassoVisuals[Child]

            if ExistingVisual and (ExistingVisual.Puller ~= Puller or ExistingVisual.LassoName ~= LassoName) then
                Destroy_Spectator_Lasso_Visual(Child)
                ExistingVisual = nil
            end

            if not ExistingVisual then
                local NewVisual = Create_Spectator_Lasso_Visual(Child, Puller, LassoName)

                if NewVisual then
                    RuntimeState.SpectatorLassoVisuals[Child] = NewVisual
                    ExistingVisual = NewVisual
                end
            end

            if ExistingVisual then
                SeenTargets[Child] = true

                if not ExistingVisual:Update() then
                    Destroy_Spectator_Lasso_Visual(Child)
                end
            end
        end
    end

    for _, Player in Players:GetPlayers() do
        if Player ~= LocalPlayer then
            Set_Remote_Held_Lasso_Hidden(Player, ActivePullers[Player] == true)
        end
    end

    for TargetModel in RuntimeState.SpectatorLassoVisuals do
        if not SeenTargets[TargetModel] then
            Destroy_Spectator_Lasso_Visual(TargetModel)
        end
    end

    for TargetModel in Confetti.PlayedTargets do
        if not TargetModel.Parent then
            Confetti.PlayedTargets[TargetModel] = nil
        end
    end
end

local function Capture_Rope_Constraint(Rope: RopeConstraint): RopeConstraintState
    return {
        Rope = Rope,
        Attachment0 = Rope.Attachment0,
        Attachment1 = Rope.Attachment1,
        Length = Rope.Length,
        Visible = Rope.Visible,
        Enabled = Rope.Enabled,
    }
end

local function Restore_Rope_Constraint(State: RopeConstraintState)
    local Rope = State.Rope

    if not Rope.Parent then
        return
    end

    Rope.Attachment0 = State.Attachment0
    Rope.Attachment1 = State.Attachment1
    Rope.Length = State.Length
    Rope.Visible = State.Visible
    Rope.Enabled = State.Enabled
end

local function Capture_Lasso_Part_State(Part: BasePart, HeldLasso: Model): LassoPartState
    local JointStates = {}

    for _, Descendant in HeldLasso:GetDescendants() do
        if not Descendant:IsA("JointInstance") then
            continue
        end

        if Descendant.Part0 ~= Part and Descendant.Part1 ~= Part then
            continue
        end

        table.insert(JointStates, {
            Joint = Descendant,
            Enabled = Descendant.Enabled,
        })
    end

    return {
        Part = Part,
        CFrame = Part.CFrame,
        Anchored = Part.Anchored,
        Transparency = Part.Transparency,
        CanCollide = Part.CanCollide,
        CanTouch = Part.CanTouch,
        CanQuery = Part.CanQuery,
        CastShadow = Part.CastShadow,
        JointStates = JointStates,
        VisualState = LassoRig.Capture_Visual_State(Part),
    }
end

local function Detach_Visible_Throw_Part(State: LassoPartState)
    for _, JointState in State.JointStates do
        if JointState.Joint.Parent then
            JointState.Joint.Enabled = false
        end
    end

    local Top = State.Part

    Top.Anchored = true
    LassoRig.Set_Visual_Instance_Visible(Top, true, 0)
    Top.CanCollide = false
    Top.CanTouch = false
    Top.CanQuery = false
    Top.CastShadow = false
    Top.Massless = true
    Top.AssemblyLinearVelocity = Vector3.zero
    Top.AssemblyAngularVelocity = Vector3.zero
end

local function Hide_Lasso_Part(State: LassoPartState)
    local Part = State.Part

    if not Part.Parent then
        return
    end

    Part.Transparency = 1
    LassoRig.Set_Visual_State_Visible(State.VisualState, false)
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.CastShadow = false
    Part.Massless = true
end

local function Restore_Lasso_Part_State(State: LassoPartState, RestoreCFrame: boolean)
    local Part = State.Part

    if Part.Parent then
        Part.Anchored = false

        if RestoreCFrame then
            Part.CFrame = State.CFrame
            Part.AssemblyLinearVelocity = Vector3.zero
            Part.AssemblyAngularVelocity = Vector3.zero
        end

        LassoRig.Restore_Visual_State(State.VisualState)
        Part.CanCollide = false
        Part.CanTouch = false
        Part.CanQuery = false
        Part.CastShadow = State.CastShadow
        Part.Massless = true
    end

    for _, JointState in State.JointStates do
        if JointState.Joint.Parent then
            JointState.Joint.Enabled = JointState.Enabled
        end
    end
end

local function Force_Restored_Lasso_Part(Part: BasePart?)
    if not Part or not Part.Parent then
        return
    end

    Part.Anchored = false
    LassoRig.Set_Visual_Instance_Visible(Part, true, 0)
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.CastShadow = false
    Part.Massless = true
    Part.AssemblyLinearVelocity = Vector3.zero
    Part.AssemblyAngularVelocity = Vector3.zero
end

local function Set_Top_Throw_CFrame(Top: BasePart?, Position: Vector3, _Direction: Vector3)
    if not Top or not Top.Parent then
        return
    end

    Top.CFrame = CFrame.new(Position) * Constants.THROW_TOP_ROTATION
end

RuntimeState.Create_Lasso_Visual = function(
    Character: Model?,
    ThrowStartPosition: Vector3,
    ThrowTargetPosition: Vector3,
    Target: Model?,
    TargetEntity: number?,
    Callbacks: ThrowCallbacks?
): LassoVisual?
    local HeldLasso = Get_Held_Lasso_Model(Character)
    local HeldLassoTop = Get_Held_Lasso_Top(Character)
    local HeldLassoBottom = Get_Held_Lasso_Bottom(Character)
    local StartPosition = ThrowStartPosition

    if not HeldLasso or not HeldLassoTop or not HeldLassoBottom then
        return nil
    end

    local Rope = Get_Held_Lasso_Rope(HeldLasso)

    if not Rope then
        warn("[CatchingClient] Held lasso is missing its original RopeConstraint.")
        return nil
    end

    local Alive = true
    local CurrentTarget = Target
    local CurrentTargetEntity = TargetEntity
    local IsFollowingTarget = false
    local IsPulling = false
    local TargetFollowConnection: RBXScriptConnection? = nil
    local UpdateConnection: RBXScriptConnection? = nil
    local PullTween: Tween? = nil
    local ThrowStartTime = os.clock()
    local FlatThrowTargetPosition = Vector3.new(ThrowTargetPosition.X, StartPosition.Y, ThrowTargetPosition.Z)
    local ThrowDuration = Get_Throw_Duration(StartPosition, FlatThrowTargetPosition)
    local ThrowDirection = FlatThrowTargetPosition - StartPosition
    local LastThrowPosition = StartPosition
    local TopState = Capture_Lasso_Part_State(HeldLassoTop, HeldLasso)
    local BottomState = Capture_Lasso_Part_State(HeldLassoBottom, HeldLasso)
    local PlayerAnchor, PlayerAttachment = Make_Hidden_Rope_Anchor("LocalLassoPlayerAnchor", StartPosition)
    local TargetAnchor, TargetAttachment = Make_Hidden_Rope_Anchor("LocalLassoTargetAnchor", StartPosition)
    local ActiveRope = Instance.new("RopeConstraint")
    local OriginalRopeState = Capture_Rope_Constraint(Rope)
    local RestoredHeldLasso = false
    local LatchedLassoHidden = false
    local LocalHitReported = false
    local ThrowMissReported = false

    if ThrowDirection.Magnitude < 0.001 then
        ThrowDirection = Vector3.zAxis
    end

    Detach_Visible_Throw_Part(TopState)
    Set_Top_Throw_CFrame(HeldLassoTop, StartPosition, ThrowDirection)

    Rope.Visible = false
    Rope.Enabled = false
    Update_Rope_Length(Rope)

    ActiveRope.Name = "LocalLassoCatchRope"
    ActiveRope.Attachment0 = PlayerAttachment
    ActiveRope.Attachment1 = TargetAttachment
    ActiveRope.Visible = true
    ActiveRope.Enabled = true
    ActiveRope.Thickness = Rope.Thickness
    ActiveRope.Color = Rope.Color
    ActiveRope.Parent = PlayerAnchor
    Update_Rope_Length(ActiveRope)

    local function Hide_Latched_Lasso()
        if LatchedLassoHidden then
            return
        end

        LatchedLassoHidden = true
        Hide_Lasso_Part(TopState)
        Hide_Lasso_Part(BottomState)
        Rope.Visible = false
        Rope.Enabled = false
    end

    local function Restore_Held_Lasso()
        if RestoredHeldLasso then
            return
        end

        RestoredHeldLasso = true

        if Rope.Parent then
            Rope.Visible = false
            Rope.Enabled = false
        end

        if Character == LocalPlayer.Character and not Is_Lasso_Equipped() then
            Hide_Lasso_Part(TopState)
            Hide_Lasso_Part(BottomState)
            return
        end

        Restore_Lasso_Part_State(TopState, true)
        Restore_Lasso_Part_State(BottomState, false)
        Restore_Rope_Constraint(OriginalRopeState)
        Force_Restored_Lasso_Part(HeldLassoTop)
        Force_Restored_Lasso_Part(HeldLassoBottom)
    end

    local function Start_Target_Follow()
        IsFollowingTarget = true
        Hide_Latched_Lasso()

        if TargetFollowConnection then
            TargetFollowConnection:Disconnect()
            TargetFollowConnection = nil
        end

        TargetFollowConnection = RunService.RenderStepped:Connect(function()
            local TargetToFollow = CurrentTarget

            if CurrentTargetEntity then
                TargetToFollow = Find_Target_Model_By_Entity(CurrentTargetEntity) or TargetToFollow
            end

            local CurrentTargetPosition = Get_Target_Position(TargetToFollow)

            if CurrentTargetPosition then
                TargetAnchor.Position = CurrentTargetPosition
            end
        end)
    end

    UpdateConnection = RunService.RenderStepped:Connect(function()
        if not Alive then
            return
        end

        local PlayerPosition = Get_Player_Rope_Position(Character)

        if PlayerPosition then
            PlayerAnchor.Position = PlayerPosition
        end

        if not IsFollowingTarget and not IsPulling then
            local Alpha = math.clamp((os.clock() - ThrowStartTime) / ThrowDuration, 0, 1)
            local ThrowPosition = StartPosition:Lerp(FlatThrowTargetPosition, Alpha)

            if not LocalHitReported then
                local HitTargetEntity, HitTargetModel =
                    Find_Local_Hit_Target_On_Segment(LastThrowPosition, ThrowPosition)

                if HitTargetEntity and HitTargetModel then
                    LocalHitReported = true
                    CurrentTarget = HitTargetModel
                    CurrentTargetEntity = HitTargetEntity
                    Set_Top_Throw_CFrame(HeldLassoTop, ThrowPosition, ThrowDirection)
                    TargetAnchor.Position = Get_Target_Position(HitTargetModel) or ThrowPosition
                    Start_Target_Follow()

                    if Callbacks and Callbacks.OnHit then
                        task.defer(Callbacks.OnHit, HitTargetEntity)
                    end
                else
                    Set_Top_Throw_CFrame(HeldLassoTop, ThrowPosition, ThrowDirection)
                    TargetAnchor.Position = ThrowPosition
                end

                if Alpha >= 1 and not LocalHitReported and not ThrowMissReported then
                    ThrowMissReported = true

                    if Callbacks and Callbacks.OnMiss then
                        task.defer(Callbacks.OnMiss)
                    end
                end
            end

            LastThrowPosition = ThrowPosition
        end

        Update_Rope_Length(ActiveRope)
    end)

    local Visual = {} :: LassoVisual

    function Visual:Destroy()
        Alive = false

        if PullTween then
            PullTween:Cancel()
        end

        if TargetFollowConnection then
            TargetFollowConnection:Disconnect()
        end

        if UpdateConnection then
            UpdateConnection:Disconnect()
        end

        if ActiveRope.Parent then
            ActiveRope:Destroy()
        end

        if PlayerAnchor.Parent then
            PlayerAnchor:Destroy()
        end

        if TargetAnchor.Parent then
            TargetAnchor:Destroy()
        end

        Restore_Held_Lasso()
    end

    function Visual:AttachToTarget(NewTarget: Model?, NewTargetEntity: number?)
        if not Alive then
            return
        end

        CurrentTarget = NewTarget
        CurrentTargetEntity = NewTargetEntity

        local TargetPosition = Get_Target_Position(CurrentTarget)

        if NewTargetEntity then
            TargetPosition = TargetPosition or Get_Target_Position(Find_Target_Model_By_Entity(NewTargetEntity))
        end

        if TargetPosition then
            TargetAnchor.Position = TargetPosition
            Start_Target_Follow()
        else
            Start_Target_Follow()
        end
    end

    function Visual:PullToCharacter(PullCharacter: Model?, Duration: number)
        if not Alive then
            return
        end

        if TargetFollowConnection then
            TargetFollowConnection:Disconnect()
            TargetFollowConnection = nil
        end

        IsPulling = true

        local PullSource = Get_Hand_Source_Part(PullCharacter) or Get_Hand_Source_Part(Character)
        local PullPosition = Get_Attachment_Position(PullSource)

        if not PullPosition then
            self:Destroy()
            return
        end

        PullTween =
            TweenService:Create(TargetAnchor, TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = PullPosition,
            })
        PullTween.Completed:Connect(function()
            self:Destroy()
        end)
        PullTween:Play()
    end

    return Visual
end

local function Create_Remote_Throw_Visual(
    Player: Player,
    LassoName: string,
    AimOrigin: Vector3,
    AimDirection: Vector3
): RemoteThrowVisual?
    local Template = LassoRig.Find_Template(LassoName) or LassoRig.Find_Template(Lassos.Default)

    if not Template then
        return nil
    end

    local FlatDirection = Vector3.new(AimDirection.X, 0, AimDirection.Z)

    if FlatDirection.Magnitude < 0.001 then
        return nil
    end

    local Model = Template:Clone()

    Model.Name = `RemoteThrowLasso_{Player.UserId}`
    Model:SetAttribute("LassoName", LassoName)
    Model.Parent = Get_Spectator_Lasso_Folder()

    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Prepare_Spectator_Lasso_Part(Descendant)
        elseif Descendant:IsA("JointInstance") then
            Descendant.Enabled = false
        end
    end

    local Top = LassoRig.Get_Top(Model)
    local Bottom = LassoRig.Get_Bottom(Model)

    if not Top or not Bottom then
        Model:Destroy()
        return nil
    end

    local TopAttachment = Get_Or_Create_Attachment(Top, "RopeAttachment")
    local BottomAttachment = Get_Or_Create_Attachment(Bottom, "RopeAttachment")
    local Rope = LassoRig.Get_Rope(Model)

    if not Rope then
        Rope = Instance.new("RopeConstraint")
        Rope.Name = "RemoteThrowLassoRope"
        Rope.Thickness = 0.08
        Rope.Parent = Model
    end

    Rope.Attachment0 = BottomAttachment
    Rope.Attachment1 = TopAttachment
    Rope.Visible = true
    Rope.Enabled = true

    local ThrowTarget = AimOrigin + FlatDirection.Unit * Constants.RAYCAST_DISTANCE
    local ThrowDuration = Get_Throw_Duration(AimOrigin, ThrowTarget)
    local StartedAt = os.clock()
    local Alive = true
    local UpdateConnection: RBXScriptConnection? = nil
    local HeldLasso = Get_Held_Lasso_Model(Player.Character)
    local HeldTop = LassoRig.Get_Top(HeldLasso)
    local HeldTopVisualState = LassoRig.Capture_Visual_State(HeldTop)
    local HeldRope = LassoRig.Get_Rope(HeldLasso)
    local HeldRopeVisible = if HeldRope then HeldRope.Visible else nil
    local HeldRopeEnabled = if HeldRope then HeldRope.Enabled else nil

    LassoRig.Set_Visual_Instance_Visible(Top, true, 0)
    LassoRig.Set_Visual_Instance_Visible(Bottom, false)
    LassoRig.Set_Visual_State_Visible(HeldTopVisualState, false)

    if HeldRope then
        HeldRope.Visible = false
        HeldRope.Enabled = false
    end

    local function Restore_Held_Throw_State()
        LassoRig.Restore_Visual_State(HeldTopVisualState)

        if HeldRope and HeldRope.Parent then
            if HeldRopeVisible ~= nil then
                HeldRope.Visible = HeldRopeVisible
            end

            if HeldRopeEnabled ~= nil then
                HeldRope.Enabled = HeldRopeEnabled
            end
        end
    end

    UpdateConnection = RunService.RenderStepped:Connect(function()
        if not Alive then
            return
        end

        local PullerPosition = Get_Player_Rope_Position(Player.Character) or AimOrigin
        local Alpha = math.clamp((os.clock() - StartedAt) / ThrowDuration, 0, 1)
        local ThrowPosition = AimOrigin:Lerp(ThrowTarget, Alpha)

        if Bottom.Parent then
            Bottom.CFrame = CFrame.new(PullerPosition)
        end

        Set_Top_Throw_CFrame(Top, ThrowPosition, FlatDirection.Unit)
        Update_Rope_Length(Rope)

        if Alpha >= 1 then
            Alive = false
            Restore_Held_Throw_State()

            task.delay(0.1, function()
                if Model.Parent then
                    Model:Destroy()
                end
            end)

            if UpdateConnection then
                UpdateConnection:Disconnect()
                UpdateConnection = nil
            end
        end
    end)

    local Visual = {} :: RemoteThrowVisual

    function Visual:Destroy()
        Alive = false
        Restore_Held_Throw_State()

        if UpdateConnection then
            UpdateConnection:Disconnect()
            UpdateConnection = nil
        end

        if Model.Parent then
            Model:Destroy()
        end
    end

    return Visual
end

local function Start_Remote_Lasso_Throw(Data: {
    PlayerUserId: number,
    LassoName: string,
    AimOriginX: number,
    AimOriginY: number,
    AimOriginZ: number,
    AimDirectionX: number,
    AimDirectionY: number,
    AimDirectionZ: number,
})
    if Data.PlayerUserId == LocalPlayer.UserId then
        return
    end

    local Player = Players:GetPlayerByUserId(Data.PlayerUserId)

    if not Player then
        return
    end

    local ExistingVisual = RuntimeState.RemoteThrowVisuals[Data.PlayerUserId]

    if ExistingVisual then
        ExistingVisual:Destroy()
        RuntimeState.RemoteThrowVisuals[Data.PlayerUserId] = nil
    end

    local AimOrigin = Vector3.new(Data.AimOriginX, Data.AimOriginY, Data.AimOriginZ)
    local AimDirection = Vector3.new(Data.AimDirectionX, Data.AimDirectionY, Data.AimDirectionZ)
    local Visual = Create_Remote_Throw_Visual(Player, Data.LassoName, AimOrigin, AimDirection)

    if not Visual then
        return
    end

    RuntimeState.RemoteThrowVisuals[Data.PlayerUserId] = Visual
end

local function Is_Image_Gui(Object: Instance?): boolean
    return Object ~= nil and (Object:IsA("ImageLabel") or Object:IsA("ImageButton"))
end

local function Ancestor_Name_Contains(Object: Instance, Text: string): boolean
    local LowerText = string.lower(Text)
    local Current: Instance? = Object

    while Current do
        if string.find(string.lower(Current.Name), LowerText, 1, true) then
            return true
        end

        Current = Current.Parent
    end

    return false
end

local function Find_Display_Background_Image(Display: Instance?): GuiObject?
    if not Display then
        return nil
    end

    local DirectImage = Display:FindFirstChild("Image")

    if Is_Image_Gui(DirectImage) then
        return DirectImage :: GuiObject
    end

    for _, Descendant in Display:GetDescendants() do
        if Descendant.Name == "Image" and Is_Image_Gui(Descendant) then
            return Descendant :: GuiObject
        end
    end

    if Is_Image_Gui(Display) then
        return Display :: GuiObject
    end

    return nil
end

local function Apply_Display_Fallback_Style(Display: GuiObject, Rarity: string?)
    local DisplayColor = if Rarity then Constants.RARITY_DISPLAY_COLORS[Rarity] else nil

    if DisplayColor then
        Display.BackgroundColor3 = DisplayColor
        Display.BackgroundTransparency = math.min(Display.BackgroundTransparency, 0.2)
    end
end

local function Get_Disclaimer_Text_Label(): TextLabel?
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Main = PlayerGui and PlayerGui:FindFirstChild("Main")
    local EdgeLayer = Main and Main:FindFirstChild("EdgeLayer")
    local Disclaimer = EdgeLayer and EdgeLayer:FindFirstChild("Disclaimer")

    if Disclaimer and Disclaimer:IsA("TextLabel") then
        return Disclaimer
    end

    return nil
end

local function Clear_Text_Gradients(TextLabel: TextLabel)
    for _, Child in TextLabel:GetChildren() do
        if Child:IsA("UIGradient") then
            Child:Destroy()
        end
    end
end

local function Get_Notification_Gradient(GradientName: "Success" | "Error"): UIGradient?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Gradients = Assets and Assets:FindFirstChild("Gradients")
    local NotificationGradients = Gradients and Gradients:FindFirstChild("Notification")
    local Gradient = NotificationGradients and NotificationGradients:FindFirstChild(GradientName)

    if Gradient and Gradient:IsA("UIGradient") then
        return Gradient
    end

    return nil
end

local function Capture_Disclaimer_State(TextLabel: TextLabel)
    if RuntimeState.DisclaimerOriginalState then
        return
    end

    local Gradients = {}

    for _, Child in TextLabel:GetChildren() do
        if Child:IsA("UIGradient") then
            table.insert(Gradients, Child:Clone())
        end
    end

    RuntimeState.DisclaimerOriginalState = {
        Text = TextLabel.Text,
        TextColor3 = TextLabel.TextColor3,
        TextTransparency = TextLabel.TextTransparency,
        Visible = TextLabel.Visible,
        Gradients = Gradients,
    }
end

local function Restore_Disclaimer_State()
    local State = RuntimeState.DisclaimerOriginalState

    if not State then
        return
    end

    RuntimeState.DisclaimerOriginalState = nil

    local TextLabel = Get_Disclaimer_Text_Label()

    if not TextLabel then
        return
    end

    TextLabel.Text = State.Text
    TextLabel.TextColor3 = State.TextColor3
    TextLabel.TextTransparency = State.TextTransparency
    TextLabel.Visible = State.Visible
    Clear_Text_Gradients(TextLabel)

    for _, Gradient in State.Gradients do
        Gradient:Clone().Parent = TextLabel
    end
end

local function Set_Disclaimer_Safety(IsSafe: boolean)
    local TextLabel = Get_Disclaimer_Text_Label()

    if not TextLabel then
        return
    end

    Capture_Disclaimer_State(TextLabel)
    Clear_Text_Gradients(TextLabel)

    local Gradient = Get_Notification_Gradient(if IsSafe then "Success" else "Error")

    if Gradient then
        Gradient:Clone().Parent = TextLabel
    end

    TextLabel.Text = if IsSafe then Constants.SAFE_DISCLAIMER_TEXT else Constants.STEALABLE_DISCLAIMER_TEXT
    TextLabel.TextColor3 = Color3.new(1, 1, 1)
    TextLabel.TextTransparency = 0
    TextLabel.Visible = true
end

local function Set_Lock_Icons_Safety(IsSafe: boolean)
    local Image = if IsSafe then Constants.SAFE_LOCK_IMAGE else Constants.STEALABLE_LOCK_IMAGE

    for _, LockIcon in LockIconImages do
        if not LockIcon.Parent then
            continue
        end

        if LockIcon:IsA("ImageLabel") or LockIcon:IsA("ImageButton") then
            LockIcon.Image = Image
        end
    end
end

local function Set_Catch_Safety_UI(IsSafe: boolean)
    Set_Disclaimer_Safety(IsSafe)
    Set_Lock_Icons_Safety(IsSafe)
end

local function Configure_Display_Style(Data: CatchStartedData)
    if not MinigameDisplay then
        return
    end

    Apply_Display_Fallback_Style(MinigameDisplay, Data.TargetRarity)

    local DisplayImage = CatchConfig.Get_Display_Image(Data.TargetRarity)

    if not DisplayImage then
        return
    end

    if Is_Image_Gui(MinigameDisplay) then
        local DisplayImageObject = MinigameDisplay :: any

        DisplayImageObject.Image = DisplayImage
        DisplayImageObject.ImageColor3 = Color3.new(1, 1, 1)
        DisplayImageObject.ImageTransparency = 0
    end

    if MinigameDisplayImage and MinigameDisplayImage ~= MinigameDisplay and Is_Image_Gui(MinigameDisplayImage) then
        local DisplayImageObject = MinigameDisplayImage :: any

        DisplayImageObject.Image = DisplayImage
        DisplayImageObject.ImageColor3 = Color3.new(1, 1, 1)
        DisplayImageObject.ImageTransparency = 0
    end
end

local function Get_Minigame_Objects(): boolean
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")

    if not PlayerGui then
        return false
    end

    MinigameGui = PlayerGui:FindFirstChild("Minigame") :: ScreenGui?

    if not MinigameGui or not MinigameGui:IsA("ScreenGui") then
        return false
    end

    local BottomLayer = MinigameGui:FindFirstChild("BottomLayer")
    local MinigameFrame = BottomLayer and BottomLayer:FindFirstChild("Minigame Frame")
    local Minibar = MinigameFrame and MinigameFrame:FindFirstChild("Minibar")
    local Display = MinigameFrame and MinigameFrame:FindFirstChild("Display")
    local TextFrame = MinigameFrame and MinigameFrame:FindFirstChild("Text")
    local CandidateGreenBar = Minibar and Minibar:FindFirstChild("greenbar")
    local CandidateStrengthLabel = Display and Display:FindFirstChild("36")
    local CandidateTargetIcon = Display and Display:FindFirstChild("Icon")
    local CandidateTotalClicksLabel = TextFrame and TextFrame:FindFirstChild("Total Clicks(011)")

    if MinigameFrame and MinigameFrame:IsA("GuiObject") then
        if MinigameFrameObject ~= MinigameFrame then
            MinigameFrameObject = MinigameFrame
            MinigameFrameBasePosition = MinigameFrame.Position
        end
    end

    if Display and Display:IsA("GuiObject") then
        MinigameDisplay = Display
        MinigameDisplayImage = Find_Display_Background_Image(Display)
    else
        MinigameDisplay = nil
        MinigameDisplayImage = nil
    end

    if CandidateGreenBar and CandidateGreenBar:IsA("GuiObject") then
        CandidateGreenBar.AnchorPoint = Vector2.new(0.5, CandidateGreenBar.AnchorPoint.Y)
        CandidateGreenBar.Position =
            UDim2.new(0.5, 0, CandidateGreenBar.Position.Y.Scale, CandidateGreenBar.Position.Y.Offset)

        if GreenBar ~= CandidateGreenBar then
            GreenBar = CandidateGreenBar
        end

        GreenBarBaseSize = UDim2.new(1, 0, CandidateGreenBar.Size.Y.Scale, CandidateGreenBar.Size.Y.Offset)
    end

    if CandidateStrengthLabel and CandidateStrengthLabel:IsA("TextLabel") then
        StrengthLabel = CandidateStrengthLabel
    end

    if CandidateTargetIcon and CandidateTargetIcon:IsA("ImageLabel") then
        TargetIcon = CandidateTargetIcon
    end

    if CandidateTotalClicksLabel and CandidateTotalClicksLabel:IsA("TextLabel") then
        TotalClicksLabel = CandidateTotalClicksLabel
    end

    table.clear(LockIconImages)

    if TextFrame then
        for _, Descendant in TextFrame:GetDescendants() do
            if string.lower(Descendant.Name) ~= "lockicon" then
                continue
            end

            if Descendant:IsA("ImageLabel") or Descendant:IsA("ImageButton") then
                table.insert(LockIconImages, Descendant)
            end
        end
    end

    return GreenBar ~= nil and GreenBarBaseSize ~= nil
end

local function Offset_Position(
    Position: UDim2,
    XScaleOffset: number,
    YScaleOffset: number,
    XOffset: number?,
    YOffset: number?
): UDim2
    return UDim2.new(
        Position.X.Scale + XScaleOffset,
        Position.X.Offset + (XOffset or 0),
        Position.Y.Scale + YScaleOffset,
        Position.Y.Offset + (YOffset or 0)
    )
end

local function Get_Input_Click_Point(Input: InputObject): Vector2?
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        return UserInputService:GetMouseLocation()
    end

    if Input.UserInputType == Enum.UserInputType.Touch then
        return Vector2.new(Input.Position.X, Input.Position.Y)
    end

    return nil
end

local function Cancel_Hud_Tween(Object: GuiObject)
    local ExistingTween = RuntimeState.CatchHudTweens[Object]

    if not ExistingTween then
        return
    end

    ExistingTween:Cancel()
    RuntimeState.CatchHudTweens[Object] = nil
end

local function Tween_Gui_Position(Object: GuiObject, Position: UDim2, HideAfterTween: boolean?)
    Cancel_Hud_Tween(Object)

    Object.Visible = true

    local Tween = TweenService:Create(
        Object,
        TweenInfo.new(CatchConfig.CatchHudTransitionSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position = Position,
        }
    )

    RuntimeState.CatchHudTweens[Object] = Tween
    Tween.Completed:Connect(function(PlaybackState)
        if RuntimeState.CatchHudTweens[Object] ~= Tween then
            return
        end

        RuntimeState.CatchHudTweens[Object] = nil

        if HideAfterTween and PlaybackState == Enum.PlaybackState.Completed then
            Object.Visible = false
        end
    end)
    Tween:Play()
end

local function Stop_Minigame_Intro_Tweens()
    if MinigameIntroPositionTween then
        MinigameIntroPositionTween:Cancel()
        MinigameIntroPositionTween = nil
    end

    if MinigameIntroScaleTween then
        MinigameIntroScaleTween:Cancel()
        MinigameIntroScaleTween = nil
    end
end

local function Get_Minigame_Intro_Scale(Frame: GuiObject): UIScale
    local ExistingScale = Frame:FindFirstChild("CatchMinigameIntroScale")

    if ExistingScale and ExistingScale:IsA("UIScale") then
        return ExistingScale
    end

    local Scale = Instance.new("UIScale")
    Scale.Name = "CatchMinigameIntroScale"
    Scale.Scale = 1
    Scale.Parent = Frame

    return Scale
end

local function Set_Minigame_Visible(Visible: boolean, Animate: boolean?)
    if not Get_Minigame_Objects() or not MinigameGui then
        return
    end

    local Frame = MinigameFrameObject

    if not Visible then
        Stop_Minigame_Intro_Tweens()
        MinigameGui.Enabled = false

        if Frame and MinigameFrameBasePosition then
            Frame.Position = MinigameFrameBasePosition
            Get_Minigame_Intro_Scale(Frame).Scale = 1
        end

        return
    end

    MinigameGui.Enabled = true

    if not Animate or not Frame then
        return
    end

    Stop_Minigame_Intro_Tweens()

    local BasePosition = MinigameFrameBasePosition or Frame.Position
    local Scale = Get_Minigame_Intro_Scale(Frame)

    Frame.Position = Offset_Position(BasePosition, 0, 0.045)
    Scale.Scale = 0.9

    MinigameIntroPositionTween = TweenService:Create(
        Frame,
        TweenInfo.new(CatchConfig.CatchMinigameIntroSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Position = BasePosition,
        }
    )
    MinigameIntroScaleTween = TweenService:Create(
        Scale,
        TweenInfo.new(CatchConfig.CatchMinigameIntroSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Scale = 1,
        }
    )

    MinigameIntroPositionTween:Play()
    MinigameIntroScaleTween:Play()
end

local function Add_Gui_Visibility_State(States: { GuiVisibilityState }, Object: Instance?)
    if not Object or (MinigameGui and Object:IsDescendantOf(MinigameGui)) then
        return
    end

    for _, State in States do
        if State.Object == Object then
            return
        end
    end

    if Object:IsA("ScreenGui") then
        table.insert(States, {
            Object = Object,
            Property = "Enabled",
            Value = Object.Enabled,
        })
        Object.Enabled = false
    elseif Object:IsA("GuiObject") then
        table.insert(States, {
            Object = Object,
            Property = "Visible",
            Value = Object.Visible,
        })
        Object.Visible = false
    end
end

local function Add_Catch_Hud_Motion_Target(
    States: { [GuiObject]: GuiMotionState },
    Object: Instance?,
    HiddenPosition: UDim2
)
    if not Object or not Object:IsA("GuiObject") or (MinigameGui and Object:IsDescendantOf(MinigameGui)) then
        return
    end

    if not States[Object] then
        States[Object] = {
            Object = Object,
            Position = Object.Position,
            Visible = Object.Visible,
        }
    end

    if not Object.Visible then
        return
    end

    Tween_Gui_Position(Object, HiddenPosition)
end

local function Is_Catch_Hud_Motion_Target(Object: Instance): boolean
    local States = RuntimeState.CatchHudMotionStates

    if not States then
        return false
    end

    for MotionObject in States do
        if Object == MotionObject or Object:IsDescendantOf(MotionObject) then
            return true
        end
    end

    return false
end

local function Hide_Inventory_UI()
    if RuntimeState.InventoryVisibilityStates or RuntimeState.CatchHudMotionStates then
        return
    end

    local VisibilityStates: { GuiVisibilityState } = {}
    local MotionStates: { [GuiObject]: GuiMotionState } = {}
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")

    RuntimeState.InventoryVisibilityStates = VisibilityStates
    RuntimeState.CatchHudMotionStates = MotionStates

    local Ok, CoreBackpackEnabled = pcall(function()
        return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
    end)

    if Ok then
        RuntimeState.CoreBackpackEnabledState = CoreBackpackEnabled
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        end)
    end

    if not PlayerGui then
        return
    end

    local Main = PlayerGui:FindFirstChild("Main")
    local Hud = Main and Main:FindFirstChild("Hud Frame")
    local HudButtons = Hud and Hud:FindFirstChild("Buttons")
    local DoubleMoney = Hud and Hud:FindFirstChild("2x Money")
    local EventInfo = Hud and Hud:FindFirstChild("EventInfo")
    local EdgeLayer = Main and Main:FindFirstChild("EdgeLayer")
    local Plot = EdgeLayer and EdgeLayer:FindFirstChild("Plot")
    local CashBalance = EdgeLayer and EdgeLayer:FindFirstChild("Cash Balance")
    local FriendBoost = EdgeLayer and EdgeLayer:FindFirstChild("Friend Boost")
    local Frames = Main and Main:FindFirstChild("Frames")
    local Inventory = Frames and Frames:FindFirstChild("Inventory")

    local HudHiddenYOffset = -0.28
    local PlotHiddenPosition = if Plot and Plot:IsA("GuiObject")
        then Offset_Position(Plot.Position, 0, HudHiddenYOffset)
        else nil

    if Plot and Plot:IsA("GuiObject") then
        Add_Catch_Hud_Motion_Target(MotionStates, Plot, PlotHiddenPosition :: UDim2)
    end

    if EventInfo and EventInfo:IsA("GuiObject") then
        Add_Catch_Hud_Motion_Target(MotionStates, EventInfo, Offset_Position(EventInfo.Position, 0, HudHiddenYOffset))
    end

    if CashBalance and CashBalance:IsA("GuiObject") then
        Add_Gui_Visibility_State(VisibilityStates, CashBalance)
    end

    if FriendBoost and FriendBoost:IsA("GuiObject") then
        Add_Gui_Visibility_State(VisibilityStates, FriendBoost)
    end

    if DoubleMoney and DoubleMoney:IsA("GuiObject") then
        Add_Catch_Hud_Motion_Target(
            MotionStates,
            DoubleMoney,
            Offset_Position(DoubleMoney.Position, 0.25, 0, DoubleMoney.AbsoluteSize.X + 24, 0)
        )
    end

    if HudButtons and HudButtons:IsA("GuiObject") then
        Add_Catch_Hud_Motion_Target(
            MotionStates,
            HudButtons,
            Offset_Position(HudButtons.Position, -0.25, 0, -HudButtons.AbsoluteSize.X - 24, 0)
        )
    end

    if Inventory and Inventory:IsA("GuiObject") then
        Add_Catch_Hud_Motion_Target(
            MotionStates,
            Inventory,
            Offset_Position(Inventory.Position, 0, 0.18, 0, Inventory.AbsoluteSize.Y + 24)
        )
    end

    for _, Name in { "Backpack", "Backpack Button", "Item Buttons", "ToolBar", "Toolbar", "Hotbar", "HotBar" } do
        local Candidate = PlayerGui:FindFirstChild(Name, true)

        if Candidate and not Is_Catch_Hud_Motion_Target(Candidate) then
            Add_Gui_Visibility_State(VisibilityStates, Candidate)
        end
    end
end

local function Restore_Inventory_UI()
    local VisibilityStates = RuntimeState.InventoryVisibilityStates
    local MotionStates = RuntimeState.CatchHudMotionStates

    RuntimeState.InventoryVisibilityStates = nil
    RuntimeState.CatchHudMotionStates = nil

    if RuntimeState.CoreBackpackEnabledState ~= nil then
        local ShouldEnableBackpack = RuntimeState.CoreBackpackEnabledState
        RuntimeState.CoreBackpackEnabledState = nil

        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, ShouldEnableBackpack)
        end)
    end

    if MotionStates then
        for Object, State in MotionStates do
            if not Object.Parent then
                continue
            end

            if State.Visible then
                Tween_Gui_Position(Object, State.Position)
            else
                Cancel_Hud_Tween(Object)
                Object.Position = State.Position
                Object.Visible = false
            end
        end
    end

    if not VisibilityStates then
        return
    end

    for Index = #VisibilityStates, 1, -1 do
        local State = VisibilityStates[Index]

        if not State.Object.Parent then
            continue
        end

        if State.Property == "Enabled" and State.Object:IsA("ScreenGui") then
            State.Object.Enabled = State.Value
        elseif State.Property == "Visible" and State.Object:IsA("GuiObject") then
            State.Object.Visible = State.Value
        end
    end
end

local function Set_Progress(Progress: number, TweenTime: number?)
    if not Get_Minigame_Objects() or not GreenBar or not GreenBarBaseSize then
        return
    end

    if GreenBarProgressTween then
        GreenBarProgressTween:Cancel()
        GreenBarProgressTween = nil
    end

    local VisualProgress = CatchConfig.Get_Progress_Bar_Scale(Progress)
    local TargetSize = UDim2.new(
        GreenBarBaseSize.X.Scale * VisualProgress,
        math.floor(GreenBarBaseSize.X.Offset * VisualProgress),
        GreenBarBaseSize.Y.Scale,
        GreenBarBaseSize.Y.Offset
    )

    if type(TweenTime) == "number" and TweenTime > 0 then
        local Tween =
            TweenService:Create(GreenBar, TweenInfo.new(TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = TargetSize,
            })

        GreenBarProgressTween = Tween
        Tween.Completed:Connect(function()
            if GreenBarProgressTween == Tween then
                GreenBarProgressTween = nil
            end
        end)
        Tween:Play()
    else
        GreenBar.Size = TargetSize
    end
end

local function Format_Clicks(_Clicks: number): string
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        return Constants.CATCH_TAP_PROMPT_TEXT
    end

    return Constants.CATCH_CLICK_PROMPT_TEXT
end

local function Start_Throw_Cooldown()
    RuntimeState.NextThrowAllowedTime =
        math.max(RuntimeState.NextThrowAllowedTime, os.clock() + CatchConfig.ThrowCooldownSeconds)
end

local function Block_Throw_For(Duration: number)
    RuntimeState.NextThrowAllowedTime = math.max(RuntimeState.NextThrowAllowedTime, os.clock() + Duration)
end

local function Set_Catch_Minigame_Active(IsActive: boolean)
    LocalPlayer:SetAttribute(Constants.CATCH_MINIGAME_ACTIVE_ATTRIBUTE, IsActive)
end

local function Set_Lasso_Busy(IsBusy: boolean)
    LocalPlayer:SetAttribute(Constants.CATCH_LASSO_BUSY_ATTRIBUTE, IsBusy)
end

local function Set_Lasso_Locked(IsLocked: boolean)
    LocalPlayer:SetAttribute(Constants.CATCH_LASSO_LOCKED_ATTRIBUTE, IsLocked)
end

local function Configure_Minigame(Data: CatchStartedData)
    Set_Catch_Minigame_Active(true)
    Get_Minigame_Objects()
    Configure_Display_Style(Data)
    Hide_Inventory_UI()
    Set_Minigame_Visible(false)
    RuntimeState.ActiveLockProgress = Data.LockProgress

    if GreenBar and (GreenBar:IsA("ImageLabel") or GreenBar:IsA("ImageButton")) then
        local GreenBarImage = CatchConfig.Get_Green_Bar_Image(Data.TargetRarity)

        if GreenBarImage then
            (GreenBar :: any).Image = GreenBarImage
        end
    end

    if TargetIcon then
        TargetIcon.Image = Data.TargetImage
    end

    if StrengthLabel then
        StrengthLabel.Text = Util.Abbreviate_Number(math.max(0, math.floor(Data.Strength + 0.5)), 1)
    end

    RuntimeState.CurrentClickCount = 0

    if TotalClicksLabel then
        TotalClicksLabel.Text = Format_Clicks(RuntimeState.CurrentClickCount)
    end

    Set_Progress(Data.Progress)
    Set_Catch_Safety_UI(Data.Progress >= Data.LockProgress)

    MinigameIntroGeneration += 1

    local IntroGeneration = MinigameIntroGeneration

    task.delay(CatchConfig.CatchMinigameIntroDelaySeconds, function()
        if IntroGeneration ~= MinigameIntroGeneration or RuntimeState.ActiveCatchId ~= Data.CatchId then
            return
        end

        Set_Minigame_Visible(true, true)
    end)
end

local function Cleanup_Local_Catch()
    Start_Throw_Cooldown()
    MinigameIntroGeneration += 1
    Set_Catch_Minigame_Active(false)
    Set_Lasso_Busy(false)
    Set_Lasso_Locked(false)

    RuntimeState.ActiveCatchId = nil
    RuntimeState.PendingTargetEntity = nil
    RuntimeState.ActiveTargetModel = nil
    RuntimeState.CurrentClickCount = 0
    RuntimeState.NextClickAllowedTime = 0
    RuntimeState.CatchEnding = false
    RuntimeState.ActiveLockProgress = CatchConfig.LockProgress

    if RuntimeState.FaceTargetTween then
        RuntimeState.FaceTargetTween:Cancel()
        RuntimeState.FaceTargetTween = nil
    end

    Unfreeze_Player_From_Catch()
    Stop_Struggle()
    Stop_Pull()
    Set_Minigame_Visible(false)
    Set_Progress(0)
    Restore_Inventory_UI()
    Restore_Disclaimer_State()

    if RuntimeState.CurrentVisual then
        RuntimeState.CurrentVisual:Destroy()
        RuntimeState.CurrentVisual = nil
    end
end

local function Get_Aim_Raycast_Params(): (RaycastParams?, number)
    local Map = workspace:FindFirstChild("Map")
    local Terrain = workspace:FindFirstChildOfClass("Terrain")

    if
        RuntimeState.AimRaycastParams
        and RuntimeState.AimRaycastMap == Map
        and RuntimeState.AimRaycastTerrain == Terrain
    then
        return RuntimeState.AimRaycastParams, RuntimeState.AimRaycastIncludeCount
    end

    local Includes = {}

    if Map then
        table.insert(Includes, Map)
    end

    if Terrain then
        table.insert(Includes, Terrain)
    end

    RuntimeState.AimRaycastMap = Map
    RuntimeState.AimRaycastTerrain = Terrain
    RuntimeState.AimRaycastIncludeCount = #Includes

    if #Includes == 0 then
        RuntimeState.AimRaycastParams = nil
        return nil, 0
    end

    local Params = RaycastParams.new()

    Params.FilterType = Enum.RaycastFilterType.Include
    Params.FilterDescendantsInstances = Includes
    RuntimeState.AimRaycastParams = Params

    return Params, RuntimeState.AimRaycastIncludeCount
end

local function Get_Aim_Data(ScreenPosition: Vector2?, UseCameraAim: boolean?): (Vector3?, Vector3?, Vector3?)
    local Camera = workspace.CurrentCamera
    local Character = LocalPlayer.Character
    local SourcePart = Get_Source_Part(Character)

    if not Camera or not SourcePart then
        return nil
    end

    local ThrowOrigin = Get_Player_Rope_Position(Character) or Get_Attachment_Position(SourcePart)

    if not ThrowOrigin then
        return nil
    end

    local ThrowVector: Vector3

    if UseCameraAim then
        local CameraFrame = Camera.CFrame
        local CameraAimPoint = CameraFrame.Position
            + CameraFrame.LookVector * CatchConfig.AimRaycastDistance
            + CameraFrame.RightVector * CatchConfig.CameraAimRightOffset

        ThrowVector = Vector3.new(CameraAimPoint.X - ThrowOrigin.X, 0, CameraAimPoint.Z - ThrowOrigin.Z)
    else
        if not ScreenPosition then
            return nil
        end

        local Ray = Camera:ScreenPointToRay(ScreenPosition.X, ScreenPosition.Y)
        local ScreenDirection = Ray.Direction.Unit
        local AimParams, AimIncludeCount = Get_Aim_Raycast_Params()
        local Result = if AimParams and AimIncludeCount > 0
            then workspace:Raycast(Ray.Origin, ScreenDirection * CatchConfig.AimRaycastDistance, AimParams)
            else nil
        local MouseWorldPoint = if Result
            then Result.Position
            else Ray.Origin + ScreenDirection * CatchConfig.AimRaycastDistance

        ThrowVector = Vector3.new(MouseWorldPoint.X - ThrowOrigin.X, 0, MouseWorldPoint.Z - ThrowOrigin.Z)
    end

    if ThrowVector.Magnitude < 0.001 then
        local CameraDirection = Camera.CFrame.LookVector
        ThrowVector = Vector3.new(CameraDirection.X, 0, CameraDirection.Z)
    end

    if ThrowVector.Magnitude < 0.001 then
        ThrowVector = Vector3.zAxis
    end

    local ThrowDirection = ThrowVector.Unit
    local AutoAimDirection = Get_Auto_Aimed_Direction(ThrowOrigin, ThrowDirection)

    if AutoAimDirection then
        ThrowDirection = AutoAimDirection
    end

    local ThrowTargetPosition = ThrowOrigin + ThrowDirection * Constants.RAYCAST_DISTANCE

    return ThrowOrigin, ThrowDirection, ThrowTargetPosition
end

local function Start_Catch(ScreenPosition: Vector2?, UseCameraAim: boolean?)
    if RuntimeState.CatchEnding or os.clock() < RuntimeState.NextThrowAllowedTime then
        return
    end

    if RuntimeState.ActiveCatchId or RuntimeState.PendingTargetEntity then
        return
    end

    if Is_Lasso_Throw_Blocked_By_Ui() then
        return
    end

    local AimOrigin, AimDirection, AimPoint = Get_Aim_Data(ScreenPosition, UseCameraAim)

    if not AimOrigin or not AimDirection or not AimPoint then
        return
    end

    RuntimeState.PendingCatchCancelled = false
    RuntimeState.PendingTargetEntity = 0
    Set_Lasso_Busy(true)

    if RuntimeState.CurrentVisual then
        RuntimeState.CurrentVisual:Destroy()
    end

    RuntimeState.CurrentVisual =
        RuntimeState.Create_Lasso_Visual(LocalPlayer.Character, AimOrigin, AimPoint, nil, nil, {
            OnHit = function(TargetEntity: number)
                if RuntimeState.ActiveCatchId or RuntimeState.PendingTargetEntity ~= 0 then
                    return
                end

                RuntimeState.PendingTargetEntity = TargetEntity
                Freeze_Player_For_Catch()

                Network.StartCatch.Fire({
                    AimOriginX = AimOrigin.X,
                    AimOriginY = AimOrigin.Y,
                    AimOriginZ = AimOrigin.Z,
                    AimDirectionX = AimDirection.X,
                    AimDirectionY = AimDirection.Y,
                    AimDirectionZ = AimDirection.Z,
                })
            end,

            OnMiss = function()
                if RuntimeState.ActiveCatchId or RuntimeState.PendingTargetEntity ~= 0 then
                    return
                end

                Cleanup_Local_Catch()
            end,
        })

    if not RuntimeState.CurrentVisual then
        RuntimeState.PendingTargetEntity = nil
        Set_Lasso_Busy(false)
        return
    end

    Network.LassoThrowStarted.Fire({
        AimOriginX = AimOrigin.X,
        AimOriginY = AimOrigin.Y,
        AimOriginZ = AimOrigin.Z,
        AimDirectionX = AimDirection.X,
        AimDirectionY = AimDirection.Y,
        AimDirectionZ = AimDirection.Z,
    })

    Play_Throw()
end

local function Can_Show_Mobile_Throw_Button(): boolean
    return UserInputService.TouchEnabled
        and Is_Lasso_Equipped()
        and not RuntimeState.CatchEnding
        and RuntimeState.ActiveCatchId == nil
        and os.clock() >= RuntimeState.NextThrowAllowedTime
        and not Is_Lasso_Throw_Blocked_By_Ui()
end

local function Get_Hud_Throw_Button(): GuiButton?
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Main = PlayerGui and PlayerGui:FindFirstChild("Main")
    local Hud = Main and Main:FindFirstChild("Hud Frame")
    local Button = Hud and Hud:FindFirstChild("ThrowButton")

    return if Button and Button:IsA("GuiButton") then Button else nil
end

local function Get_Tutorial_Throw_Button(): GuiButton?
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local TutorialGui = PlayerGui and PlayerGui:FindFirstChild("Tutorial")
    local Button = TutorialGui and TutorialGui:FindFirstChild("ThrowButton")

    return if Button and Button:IsA("GuiButton") then Button else nil
end

local function Cleanup_Runtime_Mobile_Throw_Gui()
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Gui = PlayerGui and PlayerGui:FindFirstChild("CatchMobileThrowGui")

    if Gui then
        Gui:Destroy()
    end
end

local function Set_Throw_Button_State(Button: GuiButton?, BoundAttribute: string, Visible: boolean)
    if not Button then
        return
    end

    Button.Visible = Visible

    if Button:GetAttribute(BoundAttribute) then
        return
    end

    Button:SetAttribute(BoundAttribute, true)
    Button.Activated:Connect(function()
        if Can_Show_Mobile_Throw_Button() then
            Start_Catch(nil, true)
        end
    end)
end

local function Bind_Throw_Buttons()
    Cleanup_Runtime_Mobile_Throw_Gui()

    local ShowThrowButton = Can_Show_Mobile_Throw_Button()
    local TutorialActive = Is_Tutorial_Active()

    Set_Throw_Button_State(Get_Hud_Throw_Button(), "CatchHudThrowBound", ShowThrowButton and not TutorialActive)
    Set_Throw_Button_State(Get_Tutorial_Throw_Button(), "CatchTutorialThrowBound", ShowThrowButton and TutorialActive)
end

function Confetti.Receive_LassoThrowVisual()
    for _, Data in Network.LassoThrowVisual.Iter() do
        Start_Remote_Lasso_Throw(Data)
    end
end

function Confetti.Receive_CatchPullEffect()
    for _, Data in Network.CatchPullEffect.Iter() do
        local CatchId = Confetti.Normalize_Catch_Id(Data.CatchId)

        Confetti.Play_Replicated_Pull_Effect(Data.PlayerUserId, CatchId)
    end
end

local function Send_Catch_Click(ScreenPosition: Vector2?)
    if not RuntimeState.ActiveCatchId or RuntimeState.CatchEnding then
        return
    end

    local Now = os.clock()
    local ClickInterval = 1 / CatchConfig.MaxClicksPerSecond

    if Now < RuntimeState.NextClickAllowedTime then
        return
    end

    RuntimeState.NextClickAllowedTime = Now + ClickInterval

    MinigameClickEffect.Play(MinigameGui, MinigameFrameObject, ScreenPosition)
    Play_Click_Pull()

    RuntimeState.CurrentClickCount += 1

    if TotalClicksLabel then
        TotalClicksLabel.Text = Format_Clicks(RuntimeState.CurrentClickCount)
    end

    Network.CatchClick.Fire({
        CatchId = RuntimeState.ActiveCatchId,
    })
end

local function Cancel_Active_Catch()
    if not RuntimeState.ActiveCatchId then
        if RuntimeState.PendingTargetEntity and RuntimeState.PendingTargetEntity ~= 0 then
            RuntimeState.PendingCatchCancelled = true
        end

        Cleanup_Local_Catch()
        return
    end

    Network.CancelCatch.Fire({
        CatchId = RuntimeState.ActiveCatchId,
    })
    Cleanup_Local_Catch()
end

local function Find_Minigame_Cancel_Button(): GuiButton?
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")

    if not PlayerGui then
        return nil
    end

    local ScreenGui = PlayerGui:FindFirstChild("Minigame")

    if not ScreenGui then
        return nil
    end

    if not MinigameGui and ScreenGui:IsA("ScreenGui") then
        MinigameGui = ScreenGui
    end

    local CancelObject = ScreenGui:FindFirstChild("Cancel", true)

    if CancelObject then
        if CancelObject:IsA("GuiButton") then
            return CancelObject
        end

        local NestedButton = CancelObject:FindFirstChildWhichIsA("GuiButton", true)

        if NestedButton then
            return NestedButton
        end
    end

    for _, Descendant in ScreenGui:GetDescendants() do
        if not Descendant:IsA("GuiButton") then
            continue
        end

        if
            string.find(string.lower(Descendant.Name), "cancel", 1, true)
            or Ancestor_Name_Contains(Descendant, "cancel")
        then
            return Descendant
        end
    end

    return nil
end

local function Get_Cancel_Button_Scale(Button: GuiButton): UIScale
    local ExistingScale = Button:FindFirstChild("ButtonMotionScale") or Button:FindFirstChild("CatchCancelButtonScale")

    if ExistingScale and ExistingScale:IsA("UIScale") then
        return ExistingScale
    end

    local Scale = Instance.new("UIScale")

    Scale.Name = "CatchCancelButtonScale"
    Scale.Scale = 1
    Scale.Parent = Button

    return Scale
end

local function Tween_Cancel_Button_Scale(Button: GuiButton, ScaleValue: number)
    local Scale = Get_Cancel_Button_Scale(Button)

    TweenService:Create(Scale, Constants.CANCEL_BUTTON_TWEEN_INFO, {
        Scale = ScaleValue,
    }):Play()
end

local function Bind_Minigame_Cancel_Button()
    if MinigameCancelButton and MinigameCancelButton.Parent then
        return
    end

    local Button = Find_Minigame_Cancel_Button()

    if not Button then
        return
    end

    MinigameCancelButton = Button

    if Button:GetAttribute(Constants.CANCEL_BUTTON_BOUND_ATTRIBUTE) then
        return
    end

    Button:SetAttribute(Constants.CANCEL_BUTTON_BOUND_ATTRIBUTE, true)
    Button.Active = true

    local Hovering = false

    Button.MouseEnter:Connect(function()
        Hovering = true
        Play_Interface_Sound("Hover")
        Tween_Cancel_Button_Scale(Button, Constants.CANCEL_BUTTON_HOVER_SCALE)
    end)

    Button.MouseLeave:Connect(function()
        Hovering = false
        Tween_Cancel_Button_Scale(Button, 1)
    end)

    Button.MouseButton1Down:Connect(function()
        Play_Interface_Sound("Click")
        Tween_Cancel_Button_Scale(Button, Constants.CANCEL_BUTTON_PRESS_SCALE)
    end)

    Button.MouseButton1Up:Connect(function()
        Tween_Cancel_Button_Scale(Button, if Hovering then Constants.CANCEL_BUTTON_HOVER_SCALE else 1)
    end)

    Button.Activated:Connect(function()
        Tween_Cancel_Button_Scale(Button, if Hovering then Constants.CANCEL_BUTTON_HOVER_SCALE else 1)
        Cancel_Active_Catch()
    end)
end

local function Bind_Input()
    if RuntimeState.InputBound then
        return
    end

    RuntimeState.InputBound = true

    local function Is_Input_Over_Gui_Button(Input: InputObject): boolean
        if
            Input.UserInputType ~= Enum.UserInputType.MouseButton1
            and Input.UserInputType ~= Enum.UserInputType.Touch
        then
            return false
        end

        local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")

        if not PlayerGui then
            return false
        end

        local GuiObjects = PlayerGui:GetGuiObjectsAtPosition(Input.Position.X, Input.Position.Y)

        for _, GuiObject in GuiObjects do
            local Current: Instance? = GuiObject

            while Current do
                if Current:IsA("GuiButton") then
                    return true
                end

                Current = Current.Parent
            end
        end

        return false
    end

    UserInputService.InputBegan:Connect(function(Input: InputObject, _GameProcessedEvent: boolean)
        if UserInputService:GetFocusedTextBox() then
            return
        end

        if
            Input.UserInputType == Enum.UserInputType.MouseButton1
            or Input.UserInputType == Enum.UserInputType.Touch
        then
            local OverGuiButton = Is_Input_Over_Gui_Button(Input)

            if RuntimeState.ActiveCatchId then
                if OverGuiButton then
                    return
                end

                Send_Catch_Click(Get_Input_Click_Point(Input))
                return
            end

            if Input.UserInputType == Enum.UserInputType.Touch then
                return
            end

            if _GameProcessedEvent or OverGuiButton then
                return
            end

            if not Is_Lasso_Equipped() then
                return
            end

            Start_Catch(Vector2.new(Input.Position.X, Input.Position.Y), false)
            return
        end

        if
            Input.UserInputType == Enum.UserInputType.Gamepad1
            and Input.KeyCode == CatchConfig.ControllerThrowKeyCode
        then
            if _GameProcessedEvent then
                return
            end

            if RuntimeState.ActiveCatchId then
                Send_Catch_Click(nil)
                return
            end

            if not Is_Lasso_Equipped() then
                return
            end

            Start_Catch(nil, true)
            return
        end

        if Input.KeyCode == Enum.KeyCode.Q or Input.KeyCode == Enum.KeyCode.Escape then
            if RuntimeState.ActiveCatchId or RuntimeState.PendingTargetEntity then
                Cancel_Active_Catch()
            end

            return
        end
    end)

    LocalPlayer.CharacterRemoving:Connect(Cleanup_Local_Catch)

    Bind_Throw_Buttons()
end

function Confetti.Receive_CatchStarted()
    for _, Data in Network.CatchStarted.Iter() do
        if RuntimeState.PendingCatchCancelled then
            RuntimeState.PendingCatchCancelled = false
            Network.CancelCatch.Fire({
                CatchId = Data.CatchId,
            })
            Cleanup_Local_Catch()
            continue
        end

        RuntimeState.ActiveCatchId = Data.CatchId
        RuntimeState.PendingTargetEntity = nil
        RuntimeState.NextClickAllowedTime = 0
        RuntimeState.CatchEnding = false
        Set_Lasso_Locked(false)
        Freeze_Player_For_Catch()

        local TargetModel = Find_Target_Model_By_Entity(Data.TargetEntity)
        RuntimeState.ActiveTargetModel = TargetModel

        if TargetModel then
            Face_Target(TargetModel)
        end

        if RuntimeState.CurrentVisual then
            RuntimeState.CurrentVisual:AttachToTarget(TargetModel, Data.TargetEntity)
        elseif TargetModel then
            local TargetPosition = Get_Target_Position(TargetModel)
            local StartPosition = Get_Player_Rope_Position(LocalPlayer.Character) or TargetPosition

            if TargetPosition then
                RuntimeState.CurrentVisual = RuntimeState.Create_Lasso_Visual(
                    LocalPlayer.Character,
                    StartPosition,
                    TargetPosition,
                    nil,
                    nil,
                    nil
                )

                if RuntimeState.CurrentVisual then
                    RuntimeState.CurrentVisual:AttachToTarget(TargetModel, Data.TargetEntity)
                end
            end
        end

        Configure_Minigame(Data)
        Play_Struggle()
    end
end

function Confetti.Receive_CatchProgress()
    for _, Data in Network.CatchProgress.Iter() do
        if RuntimeState.ActiveCatchId == Data.CatchId then
            Set_Progress(Data.Progress, Data.TweenTime)
            Set_Catch_Safety_UI(Data.Progress >= RuntimeState.ActiveLockProgress)
            Face_Target(RuntimeState.ActiveTargetModel)
        end
    end
end

function Confetti.Receive_CatchCancelled()
    for _, Data in Network.CatchCancelled.Iter() do
        if Data.CatchId == "" then
            if RuntimeState.PendingTargetEntity and RuntimeState.PendingTargetEntity ~= 0 then
                Cleanup_Local_Catch()
            end

            continue
        end

        if Data.CatchId == RuntimeState.ActiveCatchId then
            Cleanup_Local_Catch()
        end
    end
end

function Confetti.Receive_CatchCompleted()
    for _, Data in Network.CatchCompleted.Iter() do
        if RuntimeState.ActiveCatchId ~= Data.CatchId then
            continue
        end

        local Visual = RuntimeState.CurrentVisual
        local CompletedTargetModel = RuntimeState.ActiveTargetModel
        local CompletedItemId = Data.ItemId
        local CompletedHotbarSlot = Data.HotbarSlot

        RuntimeState.CurrentVisual = nil
        RuntimeState.ActiveCatchId = nil
        RuntimeState.PendingTargetEntity = nil
        RuntimeState.ActiveTargetModel = nil
        RuntimeState.CatchEnding = true

        if RuntimeState.FaceTargetTween then
            RuntimeState.FaceTargetTween:Cancel()
            RuntimeState.FaceTargetTween = nil
        end

        Block_Throw_For(
            math.max(CatchConfig.PullDurationSeconds, CatchConfig.CatchCompleteUiHoldSeconds)
                + CatchConfig.ThrowCooldownSeconds
        )
        MinigameIntroGeneration += 1

        if Get_Minigame_Objects() and MinigameGui and not MinigameGui.Enabled then
            Set_Minigame_Visible(true, true)
        end

        local CompletionGeneration = MinigameIntroGeneration

        local function Equip_After_Success_Visual()
            if CompletionGeneration ~= MinigameIntroGeneration then
                return
            end

            if RuntimeState.ActiveCatchId or RuntimeState.PendingTargetEntity then
                return
            end

            task.delay(Confetti.EquipDelaySeconds, function()
                if CompletionGeneration ~= MinigameIntroGeneration then
                    return
                end

                if RuntimeState.ActiveCatchId or RuntimeState.PendingTargetEntity then
                    return
                end

                Equip_Caught_Squishy(CompletedItemId, CompletedHotbarSlot)
            end)
        end

        Set_Progress(1)
        Set_Catch_Safety_UI(true)
        Confetti.Play_Success_Once(CompletedTargetModel, Equip_After_Success_Visual, Data.CatchId)
        Play_Pull()

        if Visual then
            Visual:PullToCharacter(LocalPlayer.Character, CatchConfig.PullDurationSeconds)
        end

        task.delay(math.max(CatchConfig.CatchCompleteUiHoldSeconds, CatchConfig.PullDurationSeconds), function()
            if RuntimeState.ActiveCatchId or RuntimeState.PendingTargetEntity then
                return
            end

            Set_Minigame_Visible(false)
            Unfreeze_Player_From_Catch()
            Restore_Inventory_UI()
            Restore_Disclaimer_State()
            Set_Catch_Minigame_Active(false)
            Set_Lasso_Busy(false)
            Set_Lasso_Locked(false)
            RuntimeState.CatchEnding = false
        end)
    end
end

function Confetti.Receive_CatchLocked()
    for _, Data in Network.CatchLocked.Iter() do
        if RuntimeState.ActiveCatchId ~= Data.CatchId then
            continue
        end

        Set_Lasso_Locked(true)
        Set_Catch_Safety_UI(true)
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        Bind_Input()
        Bind_Minigame_Cancel_Button()
        Confetti.Receive_LassoThrowVisual()
        Confetti.Receive_CatchPullEffect()
        Confetti.Receive_CatchStarted()
        Confetti.Receive_CatchProgress()
        Confetti.Receive_CatchLocked()
        Confetti.Receive_CatchCancelled()
        Confetti.Receive_CatchCompleted()
        Update_Spectator_Lasso_Visuals()
        Bind_Throw_Buttons()

        if RuntimeState.ActiveCatchId and not Is_Lasso_Equipped() then
            Cancel_Active_Catch()
        end
    end,
    runConditions = {},
}
