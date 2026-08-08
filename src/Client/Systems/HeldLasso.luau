local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local peek = Fusion.peek

local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local Phases = require(ReplicatedStorage.Shared.Phases)

type HeldLassoState = {
    Model: Model?,
    Track: AnimationTrack?,
    LassoName: string?,
    Character: Model?,
}

local LocalPlayer = Players.LocalPlayer
local LocalHeldLassoState: HeldLassoState = {}
local RemoteHeldLassoStates: { [Player]: HeldLassoState } = {}
local BoundPlayers: { [Player]: boolean } = {}

local LASSO_IDLE_ANIMATION_NAME = "Lasso Idle"
local LOCAL_HELD_LASSO_MODEL_NAME = "ClientHeldLasso"
local REPLICATED_HELD_LASSO_MODEL_NAME = "ReplicatedHeldLasso"
local SELECTED_INVENTORY_SLOT_ATTRIBUTE = "ServerEquippedInventorySlot"
local SELECTED_LASSO_ATTRIBUTE = "ServerEquippedLassoName"

local RIGHT_HAND_PART_OFFSET = CFrame.new(0, -0.149724, 0)

local PART_TOP_C0 = CFrame.new(
    1.052666,
    0.033665,
    -0.63913,
    -0.00103,
    0.000625,
    0.999999,
    0,
    0.999999,
    -0.000625,
    -0.999999,
    0,
    -0.00103
)

local PART_TOP_C1 = CFrame.new(1.100008, -0.000006, -0.300011)

local LEFT_HAND_BOTTOM_OFFSET =
    CFrame.new(0.336723, -0.148689, -0.078094, 0, -0.112113, -0.993696, 1, 0, 0, 0, 0.993695, -0.112113)

local R6_RIGHT_ARM_TOP_OFFSET = CFrame.new(0, -1, -0.55) * CFrame.Angles(math.rad(90), 0, math.rad(90))
local R6_LEFT_ARM_BOTTOM_OFFSET = CFrame.new(0, -1, -0.15) * CFrame.Angles(math.rad(90), 0, 0)

local function Get_Assets_Folder(): Folder?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")

    if Assets and Assets:IsA("Folder") then
        return Assets
    end

    return nil
end

local function Find_Lasso_Template(LassoName: string): Model?
    local LassoData = Lassos.Get(LassoName)
    local Assets = Get_Assets_Folder()
    local LassoModels = Assets and Assets:FindFirstChild("Lassos")

    if not LassoData or not LassoModels then
        return nil
    end

    local Template = LassoModels:FindFirstChild(LassoData.ModelName)

    if Template and Template:IsA("Model") then
        return Template
    end

    return nil
end

local function Find_Animation(AnimationName: string): Animation?
    local Assets = Get_Assets_Folder()
    local Animations = Assets and Assets:FindFirstChild("Animations")
    local Animation = Animations and Animations:FindFirstChild(AnimationName)

    if Animation and Animation:IsA("Animation") then
        return Animation
    end

    return nil
end

local function Find_Character_Part(Character: Model, R15Name: string, R6Name: string): BasePart?
    local Part = Character:FindFirstChild(R15Name)

    if Part and Part:IsA("BasePart") then
        return Part
    end

    Part = Character:FindFirstChild(R6Name)

    if Part and Part:IsA("BasePart") then
        return Part
    end

    return nil
end

local function Get_Animator(Character: Model): Animator?
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

local function Prepare_Lasso_Part(Part: BasePart)
    Part.Anchored = false
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.Massless = true
end

local function Prepare_Lasso_Model(Model: Model)
    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Prepare_Lasso_Part(Descendant)
        end
    end
end

local function Create_Rig_Handle(Parent: Instance): Part
    local Handle = Instance.new("Part")

    Handle.Name = "Part"
    Handle.Size = Vector3.new(0.5, 0.5, 0.5)
    Handle.Transparency = 1
    Prepare_Lasso_Part(Handle)
    Handle.Parent = Parent

    return Handle
end

local function Attach_Motor(
    Part0: BasePart,
    Part1: BasePart,
    C0: CFrame,
    C1: CFrame,
    JointName: string,
    Parent: Instance
): Motor6D
    Prepare_Lasso_Part(Part1)
    Part1.CFrame = Part0.CFrame * C0 * C1:Inverse()

    local Joint = Instance.new("Motor6D")

    Joint.Name = JointName
    Joint.Part0 = Part0
    Joint.Part1 = Part1
    Joint.C0 = C0
    Joint.C1 = C1
    Joint.Parent = Parent

    return Joint
end

local function Attach_Weld(
    Part0: BasePart,
    Part1: BasePart,
    C0: CFrame,
    C1: CFrame,
    JointName: string,
    Parent: Instance
): Weld
    Prepare_Lasso_Part(Part1)
    Part1.CFrame = Part0.CFrame * C0 * C1:Inverse()

    local Joint = Instance.new("Weld")

    Joint.Name = JointName
    Joint.Part0 = Part0
    Joint.Part1 = Part1
    Joint.C0 = C0
    Joint.C1 = C1
    Joint.Parent = Parent

    return Joint
end

local function Clear_State(State: HeldLassoState)
    State.LassoName = nil
    State.Character = nil

    if State.Track then
        State.Track:Stop(0.12)
        State.Track:Destroy()
        State.Track = nil
    end

    if State.Model then
        State.Model:Destroy()
        State.Model = nil
    end
end

local function Play_Lasso_Idle(State: HeldLassoState, Character: Model)
    local Animator = Get_Animator(Character)
    local Animation = Find_Animation(LASSO_IDLE_ANIMATION_NAME)

    if not Animator or not Animation then
        return
    end

    State.Track = Animator:LoadAnimation(Animation)
    State.Track.Looped = true
    State.Track.Priority = Enum.AnimationPriority.Action
    State.Track:Play(0.12)
end

local function Create_Held_Lasso(
    State: HeldLassoState,
    Character: Model,
    LassoName: string,
    ModelName: string,
    OwnerUserId: number?
)
    Clear_State(State)

    local Template = Find_Lasso_Template(LassoName)

    if not Template then
        return
    end

    local RightHand = Find_Character_Part(Character, "RightHand", "Right Arm")
    local LeftHand = Find_Character_Part(Character, "LeftHand", "Left Arm")

    if not RightHand then
        return
    end

    local Clone = Template:Clone()

    Clone.Name = ModelName
    Clone:SetAttribute("LassoName", LassoName)

    if OwnerUserId then
        Clone:SetAttribute("HeldByUserId", OwnerUserId)
    end

    Clone.Parent = Character
    Prepare_Lasso_Model(Clone)

    local Top = Clone:FindFirstChild("Top")
    local Bottom = Clone:FindFirstChild("Bottom")

    if not Top or not Top:IsA("BasePart") or not Bottom or not Bottom:IsA("BasePart") then
        Clone:Destroy()
        return
    end

    if RightHand.Name == "RightHand" then
        local Handle = Create_Rig_Handle(Clone)

        Attach_Motor(RightHand, Handle, RIGHT_HAND_PART_OFFSET, CFrame.identity, "RightHandPartLasso", Handle)
        Attach_Motor(Handle, Top, PART_TOP_C0, PART_TOP_C1, "PartTopLasso", Top)
    else
        Attach_Motor(RightHand, Top, R6_RIGHT_ARM_TOP_OFFSET, CFrame.identity, "RightArmTopLasso", Top)
    end

    if LeftHand then
        if LeftHand.Name == "LeftHand" then
            Attach_Weld(LeftHand, Bottom, LEFT_HAND_BOTTOM_OFFSET, CFrame.identity, "LeftHandBottomLasso", Bottom)
        else
            Attach_Weld(LeftHand, Bottom, R6_LEFT_ARM_BOTTOM_OFFSET, CFrame.identity, "LeftArmBottomLasso", Bottom)
        end
    else
        Attach_Weld(RightHand, Bottom, RIGHT_HAND_PART_OFFSET, CFrame.identity, "RightHandBottomLasso", Bottom)
    end

    State.Model = Clone
    State.LassoName = LassoName
    State.Character = Character
    Play_Lasso_Idle(State, Character)
end

local function Ensure_Held_Lasso(
    State: HeldLassoState,
    Character: Model?,
    LassoName: string?,
    ModelName: string,
    OwnerUserId: number?
)
    if not Character or not LassoName then
        if State.Model or State.Track then
            Clear_State(State)
        end

        return
    end

    if
        State.Model
        and State.Model.Parent == Character
        and State.Character == Character
        and State.LassoName == LassoName
    then
        if State.Track and not State.Track.IsPlaying then
            State.Track:Play(0.12)
        end

        return
    end

    Create_Held_Lasso(State, Character, LassoName, ModelName, OwnerUserId)
end

local function Get_Local_Lasso_Name(): string?
    if peek(FusionValues.EquippedInventorySlot) ~= "Lasso" then
        return nil
    end

    local LassoName = peek(FusionValues.Lasso)

    if type(LassoName) ~= "string" or not Lassos.Get(LassoName) then
        return Lassos.Default
    end

    return LassoName
end

local function Get_Remote_Lasso_Name(Player: Player): string?
    if Player:GetAttribute(SELECTED_INVENTORY_SLOT_ATTRIBUTE) ~= "Lasso" then
        return nil
    end

    local LassoName = Player:GetAttribute(SELECTED_LASSO_ATTRIBUTE)

    if type(LassoName) ~= "string" or not Lassos.Get(LassoName) then
        return Lassos.Default
    end

    return LassoName
end

local function Get_Remote_State(Player: Player): HeldLassoState
    local State = RemoteHeldLassoStates[Player]

    if State then
        return State
    end

    State = {}
    RemoteHeldLassoStates[Player] = State

    return State
end

local function Update_Local_Held_Lasso()
    Ensure_Held_Lasso(
        LocalHeldLassoState,
        LocalPlayer.Character,
        Get_Local_Lasso_Name(),
        LOCAL_HELD_LASSO_MODEL_NAME,
        LocalPlayer.UserId
    )
end

local function Update_Remote_Held_Lasso(Player: Player)
    if Player == LocalPlayer then
        return
    end

    Ensure_Held_Lasso(
        Get_Remote_State(Player),
        Player.Character,
        Get_Remote_Lasso_Name(Player),
        REPLICATED_HELD_LASSO_MODEL_NAME,
        Player.UserId
    )
end

local function Clear_Remote_Player(Player: Player)
    local State = RemoteHeldLassoStates[Player]

    if State then
        Clear_State(State)
        RemoteHeldLassoStates[Player] = nil
    end

    BoundPlayers[Player] = nil
end

local function Bind_Player(Player: Player)
    if BoundPlayers[Player] then
        return
    end

    BoundPlayers[Player] = true

    Player.CharacterRemoving:Connect(function()
        if Player == LocalPlayer then
            Clear_State(LocalHeldLassoState)
        else
            local State = RemoteHeldLassoStates[Player]

            if State then
                Clear_State(State)
            end
        end
    end)
end

Players.PlayerRemoving:Connect(Clear_Remote_Player)

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        Update_Local_Held_Lasso()

        for _, Player in Players:GetPlayers() do
            Bind_Player(Player)
            Update_Remote_Held_Lasso(Player)
        end
    end,
    runConditions = {},
}
