local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local TutorialProgress = require(ServerScriptService.Server.Modules.TutorialProgress)

local Components = require(ReplicatedStorage.Shared.Components)
local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local World = require(ReplicatedStorage.Shared.World)

type HammerState = {
    SelectedSlot: string?,
    Character: Model?,
    Model: Model?,
    Track: AnimationTrack?,
    TrackOwner: string?,
    FoodCharacter: Model?,
    FoodModel: Model?,
    FoodName: string?,
    LassoName: string?,
}

local HELD_HAMMER_MODEL_NAME = "ServerHeldHammer"
local HELD_FOOD_MODEL_NAME = "ServerHeldFood"
local HAMMER_SLOT_NAME = "Hammer"
local LASSO_SLOT_NAME = "Lasso"
local HAMMER_TEMPLATE_NAME = "Hammer"
local HAMMER_IDLE_ANIMATION_NAME = "Hammer Idle"
local HAMMER_MOTOR_NAME = "HeldHammerMotor"
local HAMMER_RIG_PART_NAME = "HammerRigPart"
local HAMMER_RIGHT_HAND_C0 = CFrame.new(0, -0.14972424507141113, 0)
local HAMMER_HANDLE_WORLD_OFFSET = Vector3.new(0, 0, 0.400055)
local FOOD_TEMPLATE_FOLDER_NAME = "Foods"
local FOOD_MOTOR_NAME = "HeldFoodMotor"
local FOOD_RIG_PART_NAME = "FoodRigPart"
local FOOD_RIGHT_HAND_C0 = CFrame.new(0, -0.28, -0.45) * CFrame.Angles(math.rad(-90), 0, 0)
local FOOD_R6_RIGHT_ARM_C0 = CFrame.new(0, -1, -0.55) * CFrame.Angles(math.rad(-90), 0, 0)
local SELECTED_INVENTORY_SLOT_ATTRIBUTE = "ServerEquippedInventorySlot"
local SELECTED_LASSO_ATTRIBUTE = "ServerEquippedLassoName"
local TRACK_OWNER_HAMMER = "Hammer"
local TRACK_OWNER_FOOD = "Food"

local SLOT_NAME_TO_NUMBER = {
    ["3"] = 3,
    ["4"] = 4,
    ["5"] = 5,
    ["6"] = 6,
    ["7"] = 7,
}

local PlayerStates: { [Player]: HammerState } = {}
local BoundPlayers: { [Player]: boolean } = {}

local function Get_State(Player: Player): HammerState
    local State = PlayerStates[Player]

    if State then
        return State
    end

    State = {}
    PlayerStates[Player] = State

    return State
end

local function Get_Assets_Folder(): Folder?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")

    if Assets and Assets:IsA("Folder") then
        return Assets
    end

    return nil
end

local function Find_Hammer_Template(): Model?
    local Assets = Get_Assets_Folder()
    local Template = Assets and Assets:FindFirstChild(HAMMER_TEMPLATE_NAME)

    if Template and Template:IsA("Model") then
        return Template
    end

    return nil
end

local function Find_Food_Template(FoodData: Foods.FoodData): Model?
    local Assets = Get_Assets_Folder()
    local FoodFolder = Assets and Assets:FindFirstChild(FOOD_TEMPLATE_FOLDER_NAME)
    local Template = FoodFolder and FoodFolder:FindFirstChild(FoodData.Name)

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

local function Prepare_Hammer_Part(Part: BasePart)
    Part.Anchored = false
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.Massless = true
end

local function Prepare_Hammer_Model(Model: Model)
    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Prepare_Hammer_Part(Descendant)
        end
    end
end

local function Get_Hammer_Base_Parts(Model: Model): { BasePart }
    local Parts = {}

    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") and Descendant.Name ~= HAMMER_RIG_PART_NAME then
            table.insert(Parts, Descendant)
        end
    end

    return Parts
end

local function Create_Hammer_Rig_Part(Model: Model): BasePart?
    local Parts = Get_Hammer_Base_Parts(Model)

    if #Parts == 0 then
        return nil
    end

    local ModelPivot = Model:GetPivot()
    local RigPart = Instance.new("Part")

    RigPart.Name = HAMMER_RIG_PART_NAME
    RigPart.Size = Vector3.new(0.5, 0.5, 0.5)
    RigPart.Transparency = 1
    RigPart.CFrame = CFrame.new(ModelPivot.Position + HAMMER_HANDLE_WORLD_OFFSET)
    RigPart.Parent = Model
    Prepare_Hammer_Part(RigPart)

    for _, Part in Parts do
        local Weld = Instance.new("Weld")

        Weld.Name = "HammerPartWeld"
        Weld.Part0 = RigPart
        Weld.Part1 = Part
        Weld.C0 = RigPart.CFrame:ToObjectSpace(Part.CFrame)
        Weld.C1 = CFrame.identity
        Weld.Parent = RigPart
    end

    return RigPart
end

local function Stop_Hammer_Track(State: HammerState, Owner: string?)
    if Owner and State.TrackOwner ~= Owner then
        return
    end

    if not State.Track then
        return
    end

    State.Track:Stop(0.12)
    State.Track:Destroy()
    State.Track = nil
    State.TrackOwner = nil
end

local function Clear_Hammer(Player: Player)
    local State = PlayerStates[Player]

    if not State then
        return
    end

    Stop_Hammer_Track(State, TRACK_OWNER_HAMMER)

    if State.Model then
        State.Model:Destroy()
        State.Model = nil
    end

    if State.Character then
        local RightHand = Find_Character_Part(State.Character, "RightHand", "Right Arm")
        local ExistingMotor = RightHand and RightHand:FindFirstChild(HAMMER_MOTOR_NAME)

        if ExistingMotor and ExistingMotor:IsA("Motor6D") then
            ExistingMotor:Destroy()
        end
    end

    State.Character = nil
end

local function Clear_Food(Player: Player)
    local State = PlayerStates[Player]

    if not State then
        return
    end

    Stop_Hammer_Track(State, TRACK_OWNER_FOOD)

    if State.FoodModel then
        State.FoodModel:Destroy()
        State.FoodModel = nil
    end

    if State.FoodCharacter then
        local RightHand = Find_Character_Part(State.FoodCharacter, "RightHand", "Right Arm")
        local ExistingMotor = RightHand and RightHand:FindFirstChild(FOOD_MOTOR_NAME)

        if ExistingMotor and ExistingMotor:IsA("Motor6D") then
            ExistingMotor:Destroy()
        end
    end

    State.FoodCharacter = nil
    State.FoodName = nil
end

local function Clear_Lasso(Player: Player)
    local State = PlayerStates[Player]

    if not State then
        return
    end

    State.LassoName = nil
    Player:SetAttribute(SELECTED_LASSO_ATTRIBUTE, "")
end

local function Play_Hammer_Idle(State: HammerState, Character: Model, Owner: string)
    if State.Track and State.TrackOwner == Owner then
        if not State.Track.IsPlaying then
            State.Track:Play(0.12)
        end

        return
    end

    Stop_Hammer_Track(State, nil)

    local Animator = Get_Animator(Character)
    local Animation = Find_Animation(HAMMER_IDLE_ANIMATION_NAME)

    if not Animator or not Animation then
        return
    end

    State.Track = Animator:LoadAnimation(Animation)
    State.TrackOwner = Owner
    State.Track.Looped = true
    State.Track.Priority = Enum.AnimationPriority.Action
    State.Track:Play(0.12)
end

local function Create_Hammer(Player: Player, Character: Model)
    Clear_Hammer(Player)

    local Template = Find_Hammer_Template()
    local RightHand = Find_Character_Part(Character, "RightHand", "Right Arm")

    if not Template or not RightHand then
        return
    end

    local Clone = Template:Clone()

    Clone.Name = HELD_HAMMER_MODEL_NAME
    Clone.Parent = Character
    Clone:SetAttribute("HeldByUserId", Player.UserId)
    Prepare_Hammer_Model(Clone)

    local RigPart = Create_Hammer_Rig_Part(Clone)

    if not RigPart then
        Clone:Destroy()
        return
    end

    RigPart.CFrame = RightHand.CFrame * HAMMER_RIGHT_HAND_C0

    local Motor = Instance.new("Motor6D")

    Motor.Name = HAMMER_MOTOR_NAME
    Motor.Part0 = RightHand
    Motor.Part1 = RigPart
    Motor.C0 = HAMMER_RIGHT_HAND_C0
    Motor.C1 = CFrame.identity
    Motor.Parent = RightHand

    local State = Get_State(Player)

    State.Character = Character
    State.Model = Clone
    Play_Hammer_Idle(State, Character, TRACK_OWNER_HAMMER)
end

local function Ensure_Hammer(Player: Player)
    local State = Get_State(Player)
    local Character = Player.Character

    if not Character or not Character.Parent then
        Clear_Hammer(Player)
        return
    end

    if State.Model and State.Model.Parent == Character and State.Character == Character then
        if State.TrackOwner ~= TRACK_OWNER_HAMMER then
            Play_Hammer_Idle(State, Character, TRACK_OWNER_HAMMER)
        elseif State.Track and not State.Track.IsPlaying then
            State.Track:Play(0.12)
        end

        return
    end

    Create_Hammer(Player, Character)
end

local function Get_Player_Entity(Player: Player): number?
    local Entity = Registry.Get("Players", Player)

    if Entity and World:contains(Entity) then
        return Entity
    end

    return nil
end

local function Get_Selected_Lasso_Name(Player: Player): string?
    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return nil
    end

    local OwnedLassos = Lassos.Normalize_Owned(World:get(PlayerEntity, Components.OwnedLassos))
    local SelectedLasso = World:get(PlayerEntity, Components.Lasso)

    return Lassos.Normalize_Selected(SelectedLasso, OwnedLassos)
end

local function Set_Lasso_Attribute(Player: Player, LassoName: string?)
    local State = Get_State(Player)

    State.LassoName = LassoName
    Player:SetAttribute(SELECTED_LASSO_ATTRIBUTE, LassoName or "")
end

local function Get_Assignment_For_Slot(PlayerEntity: number, Slot: number): any?
    local HotbarSlots = World:get(PlayerEntity, Components.HotbarSlots)

    if type(HotbarSlots) ~= "table" then
        return nil
    end

    local Direct = HotbarSlots[tostring(Slot)] or HotbarSlots[Slot]

    if type(Direct) == "table" then
        return Direct
    end

    for _, Assignment in HotbarSlots do
        if type(Assignment) == "table" and Assignment.Slot == Slot then
            return Assignment
        end
    end

    return nil
end

local function Owns_Food(PlayerEntity: number, FoodName: string): boolean
    local OwnedFood = World:get(PlayerEntity, Components.OwnedFood)

    if type(OwnedFood) ~= "table" then
        return false
    end

    for _, Entry in OwnedFood do
        if type(Entry) == "table" and Entry.Id == FoodName and type(Entry.Amount) == "number" and Entry.Amount > 0 then
            return true
        end
    end

    return false
end

local function Get_Selected_Food_Data(Player: Player): Foods.FoodData?
    local State = PlayerStates[Player]
    local Slot = State and State.SelectedSlot and SLOT_NAME_TO_NUMBER[State.SelectedSlot]

    if not Slot then
        return nil
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return nil
    end

    local Assignment = Get_Assignment_For_Slot(PlayerEntity, Slot)

    if type(Assignment) ~= "table" or Assignment.ItemType ~= "Food" or type(Assignment.ItemId) ~= "string" then
        return nil
    end

    if not Owns_Food(PlayerEntity, Assignment.ItemId) then
        return nil
    end

    return Foods.Get(Assignment.ItemId)
end

local function Prepare_Food_Part(Part: BasePart)
    Part.Anchored = false
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.Massless = true
end

local function Prepare_Food_Model(Model: Model)
    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Prepare_Food_Part(Descendant)
        end
    end
end

local function Get_Food_Base_Parts(Model: Model): { BasePart }
    local Parts = {}

    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") and Descendant.Name ~= FOOD_RIG_PART_NAME then
            table.insert(Parts, Descendant)
        end
    end

    return Parts
end

local function Create_Food_Rig_Part(Model: Model): BasePart?
    local Parts = Get_Food_Base_Parts(Model)

    if #Parts == 0 then
        return nil
    end

    local BoundsCFrame, BoundsSize = Model:GetBoundingBox()
    local RigPart = Instance.new("Part")

    RigPart.Name = FOOD_RIG_PART_NAME
    RigPart.Size = Vector3.new(
        math.max(0.2, math.min(BoundsSize.X, 1)),
        math.max(0.2, math.min(BoundsSize.Y, 1)),
        math.max(0.2, math.min(BoundsSize.Z, 1))
    )
    RigPart.Transparency = 1
    RigPart.CFrame = BoundsCFrame
    RigPart.Parent = Model
    Prepare_Food_Part(RigPart)

    for _, Part in Parts do
        local Weld = Instance.new("Weld")

        Weld.Name = "FoodPartWeld"
        Weld.Part0 = RigPart
        Weld.Part1 = Part
        Weld.C0 = RigPart.CFrame:ToObjectSpace(Part.CFrame)
        Weld.C1 = CFrame.identity
        Weld.Parent = RigPart
    end

    return RigPart
end

local function Create_Food(Player: Player, Character: Model, FoodData: Foods.FoodData)
    Clear_Food(Player)

    local Template = Find_Food_Template(FoodData)
    local RightHand = Find_Character_Part(Character, "RightHand", "Right Arm")

    if not Template or not RightHand then
        return
    end

    local Model = Template:Clone()

    Model.Name = HELD_FOOD_MODEL_NAME
    Model:SetAttribute("HeldByUserId", Player.UserId)
    Model:SetAttribute("FoodName", FoodData.Name)
    Model.Parent = Character
    Prepare_Food_Model(Model)

    local RigPart = Create_Food_Rig_Part(Model)

    if not RigPart then
        Model:Destroy()
        return
    end

    local FoodC0 = if RightHand.Name == "RightHand" then FOOD_RIGHT_HAND_C0 else FOOD_R6_RIGHT_ARM_C0

    RigPart.CFrame = RightHand.CFrame * FoodC0

    local Motor = Instance.new("Motor6D")

    Motor.Name = FOOD_MOTOR_NAME
    Motor.Part0 = RightHand
    Motor.Part1 = RigPart
    Motor.C0 = FoodC0
    Motor.C1 = CFrame.identity
    Motor.Parent = RightHand

    local State = Get_State(Player)

    State.FoodCharacter = Character
    State.FoodModel = Model
    State.FoodName = FoodData.Name
    Play_Hammer_Idle(State, Character, TRACK_OWNER_FOOD)
end

local function Ensure_Food(Player: Player, FoodData: Foods.FoodData)
    local State = Get_State(Player)
    local Character = Player.Character

    if not Character or not Character.Parent then
        Clear_Food(Player)
        return
    end

    if
        State.FoodModel
        and State.FoodModel.Parent == Character
        and State.FoodCharacter == Character
        and State.FoodName == FoodData.Name
    then
        if State.TrackOwner ~= TRACK_OWNER_FOOD then
            Play_Hammer_Idle(State, Character, TRACK_OWNER_FOOD)
        end

        return
    end

    Create_Food(Player, Character, FoodData)
end

local function Set_Selected_Slot(Player: Player, SlotName: string)
    local State = Get_State(Player)

    State.SelectedSlot = if SlotName == "" then nil else SlotName
    Player:SetAttribute(SELECTED_INVENTORY_SLOT_ATTRIBUTE, State.SelectedSlot or "")

    local PlayerEntity = Registry.Get("Players", Player)

    if PlayerEntity and World:contains(PlayerEntity) then
        if State.SelectedSlot == LASSO_SLOT_NAME then
            TutorialProgress.Complete_Step(PlayerEntity, TutorialSteps.EquipLasso, TutorialSteps.CatchFirst)
        elseif State.SelectedSlot == HAMMER_SLOT_NAME then
            TutorialProgress.Complete_Step(PlayerEntity, TutorialSteps.EquipHammer, TutorialSteps.PickupOld)
        end
    end

    if State.SelectedSlot ~= HAMMER_SLOT_NAME then
        Clear_Hammer(Player)
    end

    if not SLOT_NAME_TO_NUMBER[State.SelectedSlot or ""] then
        Clear_Food(Player)
    end

    if State.SelectedSlot ~= LASSO_SLOT_NAME then
        Clear_Lasso(Player)
    end
end

local function Reconcile_Player(Player: Player)
    local State = PlayerStates[Player]

    if not State then
        return
    end

    if State.SelectedSlot == HAMMER_SLOT_NAME then
        Ensure_Hammer(Player)
        Clear_Food(Player)
        Clear_Lasso(Player)
    elseif State.SelectedSlot == LASSO_SLOT_NAME then
        Clear_Hammer(Player)
        Clear_Food(Player)

        local LassoName = Get_Selected_Lasso_Name(Player)

        if LassoName then
            Set_Lasso_Attribute(Player, LassoName)
        else
            Clear_Lasso(Player)
        end
    else
        Clear_Hammer(Player)
        Clear_Lasso(Player)

        local FoodData = Get_Selected_Food_Data(Player)

        if FoodData then
            Ensure_Food(Player, FoodData)
        else
            Clear_Food(Player)
        end
    end
end

local function Cleanup_Player(Player: Player)
    Clear_Hammer(Player)
    Clear_Food(Player)
    Clear_Lasso(Player)
    Player:SetAttribute(SELECTED_INVENTORY_SLOT_ATTRIBUTE, nil)
    PlayerStates[Player] = nil
    BoundPlayers[Player] = nil
end

local function Bind_Player(Player: Player)
    if BoundPlayers[Player] then
        return
    end

    BoundPlayers[Player] = true

    Player.CharacterRemoving:Connect(function(Character)
        local State = PlayerStates[Player]

        if State and State.Character == Character then
            Clear_Hammer(Player)
        end

        if State and State.FoodCharacter == Character then
            Clear_Food(Player)
        end
    end)
end

for _, Player in Players:GetPlayers() do
    Bind_Player(Player)
end

Players.PlayerAdded:Connect(Bind_Player)
Players.PlayerRemoving:Connect(Cleanup_Player)

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        for _, Player, SlotName in Network.EquippedInventorySlotChanged.Iter() do
            if not RemoteCooldowns.Allow(Player, "EquippedInventorySlotChanged", 0) then
                continue
            end

            Set_Selected_Slot(Player, SlotName)
        end

        for _, Player in Players:GetPlayers() do
            Reconcile_Player(Player)
        end
    end,
    runConditions = {},
}
