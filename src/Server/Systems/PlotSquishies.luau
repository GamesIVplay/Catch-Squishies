local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local TutorialProgress = require(ServerScriptService.Server.Modules.TutorialProgress)

local Components = require(ReplicatedStorage.Shared.Components)
local EventMutations = require(ReplicatedStorage.Shared.Modules.EventMutations)
local EventService = require(script.Parent.Parent.Modules.EventService)
local Events = require(ReplicatedStorage.Shared.Modules.Events)
local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local InventoryCapacity = require(ReplicatedStorage.Shared.Modules.InventoryCapacity)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local Phases = require(ReplicatedStorage.Shared.Phases)
local PlotAreaMath = require(ReplicatedStorage.Shared.Modules.PlotAreaMath)
local Registry = require(ReplicatedStorage.Shared.Registry)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local SquishyLevels = require(ReplicatedStorage.Shared.Modules.SquishyLevels)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local World = require(ReplicatedStorage.Shared.World)

local NOTIFICATION_DURATION = 2
local CASH_COLLECT_MIN_AMOUNT = 1
local COLLECT_COOLDOWN_SECONDS = 1
local COLLECT_ALL_GROUP_NOTIFICATION = "Join the group and like the game!"
local COLLECT_ALL_MODEL_NAME = "CollectAllCash"
local COLLECT_ALL_ACTIVATE_PART_NAME = "Activate"
local COLLECT_ALL_ACTIVATE_PADDING_XZ = 2
local COLLECT_ALL_ACTIVATE_PADDING_Y = 5
local PLACEMENT_PADDING = 8
local PLACEMENT_MIN_DISTANCE = 3
local PLACEMENT_MAX_DISTANCE = 8
local PLACEMENT_ATTEMPTS = 18
local MOVEMENT_TICK_SECONDS = 0.5
local EVENT_MUTATION_ROLL_TICK_SECONDS = 0.5
local EVENT_MUTATION_ROLL_END_PADDING_SECONDS = 3
local MOVEMENT_PADDING = 8
local MOVEMENT_PATH_PADDING = 6
local MOVEMENT_MIN_DISTANCE = 1.5
local MOVEMENT_MAX_DISTANCE = 22
local MOVEMENT_LONG_DISTANCE = 44
local MOVEMENT_TARGET_ATTEMPTS = 32
local MOVEMENT_PATH_SAMPLE_STEPS = 8
local MOVEMENT_SPEED = 2
local MOVEMENT_MIN_DURATION = 1.8
local MOVEMENT_MAX_DURATION = 12
local MIN_IDLE_SECONDS = 3
local MAX_IDLE_SECONDS = 7
local TUTORIAL_LASSO_SHOP_NAME = "LassoShop"
local TUTORIAL_SHOP_TELEPORT_DISTANCE = 8
local TUTORIAL_SHOP_TELEPORT_HEIGHT = 3
local CROWDED_NEARBY_RADIUS = 14
local CROWDED_NEARBY_THRESHOLD = 2
local NORMAL_GLOBAL_TARGET_CHANCE = 0.35
local CROWDED_GLOBAL_TARGET_CHANCE = 0.78
local NORMAL_LONG_MOVE_CHANCE = 0.22
local CROWDED_LONG_MOVE_CHANCE = 0.7
local GATE_AVOIDANCE_RADIUS = 7
local GATE_AVOIDANCE_STRENGTH = 0.7
local MIN_TARGET_SEPARATION = 4.25
local MOVE_STATE_IDLE = "Idle"
local MOVE_STATE_MOVING = "Moving"
local SELECTED_INVENTORY_SLOT_ATTRIBUTE = "ServerEquippedInventorySlot"
local CUSTOM_SLOT_MIN = 3
local CUSTOM_SLOT_MAX = 7
local FEED_AMOUNTS = table.freeze({
    [1] = true,
    [5] = true,
    [10] = true,
})
local PlayerRemovingConnection: RBXScriptConnection? = nil
local PlayerAddedConnection: RBXScriptConnection? = nil
local LastCollectAtByKey: { [string]: number } = {}
local LastMoneyMultiplierByUserId: { [number]: number } = {}
local CollectAllGroupAccessByUserId: { [number]: boolean } = {}
local CollectAllGroupAccessPendingByUserId: { [number]: boolean } = {}
local PendingCollectAllRequestByUserId: { [number]: boolean } = {}
local InitialSpreadCheckedByUserId: { [number]: boolean } = {}
local LastMovementTick = 0
local LastEventMutationRollTick = 0
type EventMutationRollState = {
    StartedAt: number,
    RollAt: number,
    Rolled: boolean,
}
local EventMutationRollsByItemId: { [string]: { [string]: EventMutationRollState } } = {}
local GateAvoidancePartsByPlot = setmetatable({}, { __mode = "k" }) :: { [Instance]: { BasePart } }

local Broadcast_Player_State: (Player, number, boolean?) -> ()

local function Get_Now(): number
    return workspace:GetServerTimeNow()
end

local function Get_Collect_Key(Player: Player, ItemId: string): string
    return `{Player.UserId}:{ItemId}`
end

local function Get_Collect_All_Key(Player: Player): string
    return Get_Collect_Key(Player, "__all")
end

local function Clear_Player_Collect_Cooldowns(Player: Player)
    local Prefix = `{Player.UserId}:`

    for Key in LastCollectAtByKey do
        if string.sub(Key, 1, #Prefix) == Prefix then
            LastCollectAtByKey[Key] = nil
        end
    end
end

local Collect_All_Squishy_Cash: ((Player, boolean?) -> ())? = nil

local function Get_Stable_Seed(ItemId: string, UserId: number, MoveIndex: number?): number
    local Seed = math.floor(UserId) % 2_147_483_647

    for Index = 1, #ItemId do
        Seed = (Seed * 131 + string.byte(ItemId, Index) * Index) % 2_147_483_647
    end

    return (Seed + (MoveIndex or 0) * 9973) % 2_147_483_647
end

local function Ease_Alpha(Alpha: number): number
    local Clamped = math.clamp(Alpha, 0, 1)

    return Clamped * Clamped * (3 - 2 * Clamped)
end

local function Normalize_Number(Value: any, Fallback: number?): number
    if type(Value) ~= "number" or Value ~= Value then
        return Fallback or 0
    end

    return Value
end

local function Get_Money_Multiplier(PlayerEntity: number?): number
    if not PlayerEntity then
        return 1
    end

    return RobuxProducts.NormalizeMoneyMultiplier(World:get(PlayerEntity, Components.MoneyMultiplier))
end

local function Get_Final_Income_Per_Sec(Item: any, MoneyMultiplier: number?): number
    if type(Item) ~= "table" then
        return 0
    end

    local Income = if type(Item.BaseIncomePerSec) == "number" and Item.BaseIncomePerSec > 0
        then InventoryMath.GetFinalIncomePerSec(Item)
        elseif
            type(Item.FinalIncomePerSec) == "number"
            and Item.FinalIncomePerSec == Item.FinalIncomePerSec
            and Item.FinalIncomePerSec > 0
        then Item.FinalIncomePerSec
        else InventoryMath.GetFinalIncomePerSec(Item)

    return math.max(0, math.floor(Income * RobuxProducts.NormalizeMoneyMultiplier(MoneyMultiplier) + 0.5))
end

local function Get_Accrued_Cash(Item: any, Now: number, MoneyMultiplier: number?): number
    if type(Item) ~= "table" then
        return 0
    end

    local StoredCash = math.max(0, Normalize_Number(Item.StoredCash, 0))
    local LastCashUpdate = Normalize_Number(Item.LastCashUpdate, Now)
    local Delta = math.max(0, Now - LastCashUpdate)

    return StoredCash + Get_Final_Income_Per_Sec(Item, MoneyMultiplier) * Delta
end

local function Accrue_Item_Cash(Item: any, Now: number, MoneyMultiplier: number?): number
    local AccruedCash = Get_Accrued_Cash(Item, Now, MoneyMultiplier)
    Item.StoredCash = AccruedCash
    Item.LastCashUpdate = Now

    return AccruedCash
end

local function Get_Event_Roll_Record(ItemId: string): { [string]: EventMutationRollState }
    local Record = EventMutationRollsByItemId[ItemId]

    if not Record then
        Record = {}
        EventMutationRollsByItemId[ItemId] = Record
    end

    return Record
end

local function Get_Event_Mutation_Roll_Time(ActiveEvent: any, Rng: Random?, Now: number): number?
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

    return (Rng or Random.new()):NextNumber(Now, LatestRollAt)
end

local function Get_Or_Create_Event_Mutation_Roll(
    ItemId: string,
    EventName: string,
    ActiveEvent: any,
    Rng: Random?,
    Now: number
): EventMutationRollState?
    local StartedAt = if type(ActiveEvent) == "table" and type(ActiveEvent.StartedAt) == "number"
        then ActiveEvent.StartedAt
        else 0
    local RollRecord = Get_Event_Roll_Record(ItemId)
    local ExistingRoll = RollRecord[EventName]

    if type(ExistingRoll) == "table" and ExistingRoll.StartedAt == StartedAt then
        return ExistingRoll
    end

    local RollAt = Get_Event_Mutation_Roll_Time(ActiveEvent, Rng, Now)

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

local function Apply_Event_Mutation_Rolls_To_Item(
    Item: any,
    ActiveEvents: any,
    Rng: Random?,
    Now: number,
    MoneyMultiplier: number?
): (boolean, { string })
    if type(Item) ~= "table" or type(Item.Id) ~= "string" or Item.Id == "" or type(ActiveEvents) ~= "table" then
        return false, {}
    end

    local CurrentEventMutations = EventMutations.NormalizeList(Item.EventMutations)
    local AddedEvents = {}
    local DidChange = false
    local DidAccrue = false

    for EventName, ActiveEvent in ActiveEvents do
        if EventMutations.Has(CurrentEventMutations, EventName) then
            continue
        end

        local EventRoll = Get_Or_Create_Event_Mutation_Roll(Item.Id, EventName, ActiveEvent, Rng, Now)

        if
            not EventRoll
            or EventRoll.Rolled == true
            or type(EventRoll.RollAt) ~= "number"
            or Now < EventRoll.RollAt
        then
            continue
        end

        EventRoll.Rolled = true

        if not EventMutations.RollForEvent(EventName, Rng) then
            continue
        end

        if not DidAccrue then
            Accrue_Item_Cash(Item, Now, MoneyMultiplier)
            DidAccrue = true
        end

        CurrentEventMutations = EventMutations.Add(CurrentEventMutations, EventName)
        table.insert(AddedEvents, EventName)
        DidChange = true
    end

    if DidChange then
        Item.EventMutations = CurrentEventMutations
        Item.FinalIncomePerSec = math.max(0, math.floor(InventoryMath.GetFinalIncomePerSec(Item) + 0.5))
    end

    return DidChange, AddedEvents
end

local function Add_Cash(PlayerEntity: number, Amount: number)
    if Amount <= 0 then
        return
    end

    local CurrentCash = Normalize_Number(World:get(PlayerEntity, Components.Cash), 0)
    local NewCash = math.max(0, math.floor(CurrentCash + Amount))

    World:set(PlayerEntity, Components.Cash, NewCash)
end

local function Get_Player_Entity(Player: Player): number?
    local Entity = Registry.Get("Players", Player)

    if Entity and World:contains(Entity) then
        return Entity
    end

    return nil
end

local function Get_Player_Plot(PlayerEntity: number): Model?
    local PlotEntity = World:target(PlayerEntity, Components.Relationships.Plot)
    local Plot = PlotEntity and World:get(PlotEntity, Components.Renderable)

    if Plot and Plot:IsA("Model") then
        return Plot
    end

    return nil
end

local function Get_Target_CFrame(Target: Instance?): CFrame?
    if not Target then
        return nil
    end

    if Target:IsA("BasePart") then
        return Target.CFrame
    end

    if Target:IsA("Model") then
        return Target:GetPivot()
    end

    local Part = Target:FindFirstChildWhichIsA("BasePart", true)

    return if Part then Part.CFrame else nil
end

local function Get_Plot_Target_CFrame(Plot: Instance, TargetName: string): CFrame?
    local Target = Plot:FindFirstChild(TargetName, true)

    if not Target then
        return nil
    end

    local Rig = Target:FindFirstChild("Rig", true)

    if Rig and Rig:IsA("Model") then
        for _, RootName in { "HumanoidRootPart", "RootPart", "Root" } do
            local Root = Rig:FindFirstChild(RootName, true)

            if Root and Root:IsA("BasePart") then
                return Root.CFrame
            end
        end

        if Rig.PrimaryPart then
            return Rig.PrimaryPart.CFrame
        end
    end

    for _, RootName in { "HumanoidRootPart", "RootPart", "Root" } do
        local Root = Target:FindFirstChild(RootName, true)

        if Root and Root:IsA("BasePart") then
            return Root.CFrame
        end
    end

    return Get_Target_CFrame(Target)
end

local function Teleport_Player_In_Front_Of_Plot_Target(Player: Player, PlayerEntity: number, TargetName: string)
    local Plot = Get_Player_Plot(PlayerEntity)
    local Character = Player.Character
    local TargetCFrame = Plot and Get_Plot_Target_CFrame(Plot, TargetName)

    if not Character or not TargetCFrame then
        return
    end

    local TargetPosition = TargetCFrame.Position
    local TeleportPosition = TargetPosition
        + TargetCFrame.LookVector * TUTORIAL_SHOP_TELEPORT_DISTANCE
        + Vector3.yAxis * TUTORIAL_SHOP_TELEPORT_HEIGHT
    local LookAtPosition = Vector3.new(TargetPosition.X, TeleportPosition.Y, TargetPosition.Z)

    Character:PivotTo(CFrame.lookAt(TeleportPosition, LookAtPosition))
end

local function Copy_Array(Value): { any }
    local Result = {}

    if type(Value) ~= "table" then
        return Result
    end

    for _, Entry in Value do
        if type(Entry) == "table" then
            table.insert(Result, table.clone(Entry))
        end
    end

    return Result
end

local function Copy_Hotbar(Value): { [string]: any }
    local Result = {}

    if type(Value) ~= "table" then
        return Result
    end

    for Key, Entry in Value do
        if type(Entry) == "table" then
            local Slot = if type(Entry.Slot) == "number" then Entry.Slot else tonumber(Key)

            if Slot then
                Result[tostring(Slot)] = {
                    Slot = Slot,
                    ItemId = Entry.ItemId,
                    ItemType = Entry.ItemType,
                }
            end
        end
    end

    return Result
end

local function Get_Slot_Number_From_Name(SlotName: any): number?
    if type(SlotName) ~= "string" then
        return nil
    end

    local Slot = tonumber(SlotName) or tonumber(string.match(SlotName, "^Item%s+(%d+)$"))

    if Slot and Slot >= CUSTOM_SLOT_MIN and Slot <= CUSTOM_SLOT_MAX and math.floor(Slot) == Slot then
        return Slot
    end

    return nil
end

local function Get_Hotbar_Assignment_For_Slot(HotbarSlots: { [string]: any }, Slot: number): any?
    local Direct = HotbarSlots[tostring(Slot)]

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

local function Find_Food_Entry(OwnedFood: { any }, FoodName: string): (any?, number?)
    for Index, Entry in OwnedFood do
        if type(Entry) == "table" and Entry.Id == FoodName and Entry.Type == "Food" then
            return Entry, Index
        end
    end

    return nil, nil
end

local function Remove_Food_From_Hotbar(HotbarSlots: { [string]: any }, FoodName: string)
    for Key, Assignment in HotbarSlots do
        if type(Assignment) == "table" and Assignment.ItemType == "Food" and Assignment.ItemId == FoodName then
            HotbarSlots[Key] = nil
        end
    end
end

local function Get_Tutorial_Collect_Shortfall(PlayerEntity: number): number
    local Step = TutorialProgress.Get(PlayerEntity)

    if Step ~= TutorialSteps.CollectCash then
        return 0
    end

    local TargetPrice = 0

    local LassoData = Lassos.Get(TutorialSteps.NextLasso)

    TargetPrice = if LassoData then LassoData.Price else 0

    local Cash = tonumber(World:get(PlayerEntity, Components.Cash)) or 0

    return math.max(0, math.floor(TargetPrice - Cash))
end

local function Get_Selected_Food_Data(Player: Player, PlayerEntity: number): Foods.FoodData?
    local Slot = Get_Slot_Number_From_Name(Player:GetAttribute(SELECTED_INVENTORY_SLOT_ATTRIBUTE))

    if not Slot then
        return nil
    end

    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))
    local Assignment = Get_Hotbar_Assignment_For_Slot(HotbarSlots, Slot)

    if type(Assignment) ~= "table" or Assignment.ItemType ~= "Food" or type(Assignment.ItemId) ~= "string" then
        return nil
    end

    local OwnedFood = World:get(PlayerEntity, Components.OwnedFood)

    if type(OwnedFood) ~= "table" then
        return nil
    end

    local Entry = Find_Food_Entry(OwnedFood, Assignment.ItemId)
    local Amount = if type(Entry) == "table" and type(Entry.Amount) == "number" then Entry.Amount else 0

    if Amount <= 0 then
        return nil
    end

    return Foods.Get(Assignment.ItemId)
end

local function Find_And_Remove_Squishy(Items: { any }, ItemId: string): any?
    for Index, Entry in Items do
        if type(Entry) == "table" and Entry.Id == ItemId and Entry.Type == "Squishy" then
            table.remove(Items, Index)
            return Entry
        end
    end

    return nil
end

local function Find_Squishy(Items: { any }, ItemId: string): any?
    for _, Entry in Items do
        if type(Entry) == "table" and Entry.Id == ItemId and Entry.Type == "Squishy" then
            return Entry
        end
    end

    return nil
end

local function Find_Placed_Squishy(Items: { any }, ItemId: string): any?
    for _, Entry in Items do
        if type(Entry) == "table" and Entry.Id == ItemId and Entry.Type == "Squishy" then
            return Entry
        end
    end

    return nil
end

local function Remove_From_Hotbar(HotbarSlots: { [string]: any }, ItemId: string)
    for Key, Assignment in HotbarSlots do
        if type(Assignment) == "table" and Assignment.ItemId == ItemId and Assignment.ItemType == "Squishy" then
            HotbarSlots[Key] = nil
        end
    end
end

local function Get_First_Open_Hotbar_Slot(HotbarSlots: { [string]: any }): number?
    for Slot = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
        if HotbarSlots[tostring(Slot)] == nil then
            return Slot
        end
    end

    return nil
end

local function Get_Placement_Position(Plot: Instance, RootPosition: Vector3): Vector3?
    local RandomGenerator = Random.new()

    for _ = 1, PLACEMENT_ATTEMPTS do
        local Angle = RandomGenerator:NextNumber(0, math.pi * 2)
        local Distance = RandomGenerator:NextNumber(PLACEMENT_MIN_DISTANCE, PLACEMENT_MAX_DISTANCE)
        local Candidate = RootPosition + Vector3.new(math.cos(Angle) * Distance, 0, math.sin(Angle) * Distance)

        if PlotAreaMath.IsPositionInUnlockedAreaWithClearance(Plot, Candidate, PLACEMENT_PADDING) then
            return Candidate
        end
    end

    local RandomPosition = PlotAreaMath.GetRandomPositionInUnlockedArea(Plot, RandomGenerator, PLACEMENT_PADDING)

    if RandomPosition then
        return Vector3.new(RandomPosition.X, RootPosition.Y, RandomPosition.Z)
    end

    local NearestPosition =
        PlotAreaMath.GetNearestPositionInUnlockedAreaWithClearance(Plot, RootPosition, PLACEMENT_PADDING)

    if NearestPosition then
        return Vector3.new(NearestPosition.X, RootPosition.Y, NearestPosition.Z)
    end

    return nil
end

local function Get_Item_Position(Item: any): Vector3
    return Vector3.new(
        Normalize_Number(Item.PositionX, 0),
        Normalize_Number(Item.PositionY, 0),
        Normalize_Number(Item.PositionZ, 0)
    )
end

local function Get_Item_Move_Start(Item: any): Vector3
    local Position = Get_Item_Position(Item)

    return Vector3.new(
        Normalize_Number(Item.MoveStartX, Position.X),
        Normalize_Number(Item.MoveStartY, Position.Y),
        Normalize_Number(Item.MoveStartZ, Position.Z)
    )
end

local function Get_Item_Move_Target(Item: any): Vector3
    local Position = Get_Item_Position(Item)

    return Vector3.new(
        Normalize_Number(Item.MoveTargetX, Position.X),
        Normalize_Number(Item.MoveTargetY, Position.Y),
        Normalize_Number(Item.MoveTargetZ, Position.Z)
    )
end

local function Get_Item_Effective_Position(Item: any, Now: number): Vector3
    if Item.MoveState ~= MOVE_STATE_MOVING then
        return Get_Item_Position(Item)
    end

    local Duration = math.max(0.001, Normalize_Number(Item.MoveDuration, 0))
    local StartedAt = Normalize_Number(Item.MoveStartedAt, Now)
    local Alpha = Ease_Alpha((Now - StartedAt) / Duration)

    return Get_Item_Move_Start(Item):Lerp(Get_Item_Move_Target(Item), Alpha)
end

local function Clamp_Position_To_Plot(Plot: Instance, Position: Vector3, Padding: number?): Vector3
    local NearestPosition =
        PlotAreaMath.GetNearestPositionInUnlockedAreaWithClearance(Plot, Position, Padding or MOVEMENT_PADDING)

    if not NearestPosition then
        return Position
    end

    return Vector3.new(NearestPosition.X, Position.Y, NearestPosition.Z)
end

local function Is_Position_Outside_Plot_Clearance(Plot: Instance, Position: Vector3, Padding: number?): boolean
    return not PlotAreaMath.IsPositionInUnlockedAreaWithClearance(Plot, Position, Padding or MOVEMENT_PADDING)
end

local function Is_Item_Outside_Plot_Clearance(Plot: Instance, Item: any, Now: number): boolean
    if type(Item) ~= "table" then
        return false
    end

    return Is_Position_Outside_Plot_Clearance(Plot, Get_Item_Effective_Position(Item, Now), MOVEMENT_PADDING)
end

local function Set_Item_Position(Item: any, Position: Vector3)
    Item.PositionX = Position.X
    Item.PositionY = Position.Y
    Item.PositionZ = Position.Z
end

local function Is_Gate_Avoidance_Name(Name: string): boolean
    local LowerName = string.lower(Name)

    return string.find(LowerName, "gate", 1, true) ~= nil or string.find(LowerName, "entrance", 1, true) ~= nil
end

local function Is_In_Gate_Avoidance_Container(InstanceToCheck: Instance, Plot: Instance): boolean
    local Current: Instance? = InstanceToCheck

    while Current and Current ~= Plot do
        if Is_Gate_Avoidance_Name(Current.Name) then
            return true
        end

        Current = Current.Parent
    end

    return false
end

local function Get_Gate_Avoidance_Parts(Plot: Instance): { BasePart }
    local Cached = GateAvoidancePartsByPlot[Plot]

    if Cached then
        return Cached
    end

    local Parts = {}

    for _, Descendant in Plot:GetDescendants() do
        if Descendant:IsA("BasePart") and Is_In_Gate_Avoidance_Container(Descendant, Plot) then
            table.insert(Parts, Descendant)
        end
    end

    GateAvoidancePartsByPlot[Plot] = Parts

    return Parts
end

local function Get_Gate_Avoidance_Push(Plot: Instance, Position: Vector3): Vector3
    local Push = Vector3.zero

    for _, Part in Get_Gate_Avoidance_Parts(Plot) do
        local PartPosition = Part.Position
        local Offset = Vector3.new(Position.X - PartPosition.X, 0, Position.Z - PartPosition.Z)
        local Distance = Offset.Magnitude
        local Radius = GATE_AVOIDANCE_RADIUS + math.max(Part.Size.X, Part.Size.Z) * 0.5

        if Distance > 0.05 and Distance < Radius then
            Push += Offset.Unit * (Radius - Distance)
        elseif Distance <= 0.05 then
            Push += Vector3.xAxis * Radius
        end
    end

    return Push
end

local function Is_Position_Near_Gate(Plot: Instance, Position: Vector3): boolean
    return Get_Gate_Avoidance_Push(Plot, Position).Magnitude > 0
end

local function Apply_Gate_Avoidance(Plot: Instance, Position: Vector3): Vector3
    local Push = Get_Gate_Avoidance_Push(Plot, Position)

    if Push.Magnitude <= 0 then
        return Position
    end

    local Candidate = Position + Push * GATE_AVOIDANCE_STRENGTH

    if not PlotAreaMath.IsPositionInUnlockedAreaWithClearance(Plot, Candidate, MOVEMENT_PADDING) then
        return Position
    end

    return Candidate
end

local function Is_Path_In_Unlocked_Area(Plot: Instance, From: Vector3, To: Vector3): boolean
    for Step = 0, MOVEMENT_PATH_SAMPLE_STEPS do
        local Alpha = Step / MOVEMENT_PATH_SAMPLE_STEPS
        local Position = From:Lerp(To, Alpha)

        if not PlotAreaMath.IsPositionInUnlockedAreaWithClearance(Plot, Position, MOVEMENT_PATH_PADDING) then
            return false
        end
    end

    return true
end

local function Count_Nearby_Items(Items: { any }, Item: any, Position: Vector3, Now: number): number
    local Count = 0

    for _, OtherItem in Items do
        if OtherItem == Item or type(OtherItem) ~= "table" then
            continue
        end

        local OtherPosition = Get_Item_Effective_Position(OtherItem, Now)
        local Offset = Vector3.new(Position.X - OtherPosition.X, 0, Position.Z - OtherPosition.Z)

        if Offset.Magnitude <= CROWDED_NEARBY_RADIUS then
            Count += 1
        end
    end

    return Count
end

local function Is_Target_Too_Close_To_Items(Items: { any }, Item: any, Candidate: Vector3, Now: number): boolean
    for _, OtherItem in Items do
        if OtherItem == Item or type(OtherItem) ~= "table" then
            continue
        end

        local OtherPosition = Get_Item_Effective_Position(OtherItem, Now)
        local Offset = Vector3.new(Candidate.X - OtherPosition.X, 0, Candidate.Z - OtherPosition.Z)

        if Offset.Magnitude < MIN_TARGET_SEPARATION then
            return true
        end
    end

    return false
end

local function Is_Target_Too_Close_To_Positions(Positions: { Vector3 }, Candidate: Vector3): boolean
    local FlatCandidate = Vector3.new(Candidate.X, 0, Candidate.Z)

    for _, Position in Positions do
        if (FlatCandidate - Position).Magnitude < MIN_TARGET_SEPARATION then
            return true
        end
    end

    return false
end

local function Is_Valid_Move_Target(
    Plot: Instance,
    Items: { any },
    Item: any,
    From: Vector3,
    Candidate: Vector3,
    Now: number
): boolean
    if not PlotAreaMath.IsPositionInUnlockedAreaWithClearance(Plot, Candidate, MOVEMENT_PADDING) then
        return false
    end

    if Is_Position_Near_Gate(Plot, Candidate) then
        return false
    end

    if not Is_Path_In_Unlocked_Area(Plot, From, Candidate) then
        return false
    end

    if Is_Target_Too_Close_To_Items(Items, Item, Candidate, Now) then
        return false
    end

    return true
end

local function Get_Local_Move_Candidate(RandomGenerator: Random, CurrentPosition: Vector3, IsCrowded: boolean): Vector3
    local LongMoveChance = if IsCrowded then CROWDED_LONG_MOVE_CHANCE else NORMAL_LONG_MOVE_CHANCE
    local UseLongMove = RandomGenerator:NextNumber() < LongMoveChance
    local Radius = if UseLongMove then MOVEMENT_LONG_DISTANCE else MOVEMENT_MAX_DISTANCE
    local Angle = RandomGenerator:NextNumber(0, math.pi * 2)
    local Distance = RandomGenerator:NextNumber(MOVEMENT_MIN_DISTANCE, Radius)

    return CurrentPosition + Vector3.new(math.cos(Angle) * Distance, 0, math.sin(Angle) * Distance)
end

local function Pick_Move_Target(Plot: Instance, Items: { any }, Item: any, Now: number): Vector3?
    local CurrentPosition = Clamp_Position_To_Plot(Plot, Get_Item_Effective_Position(Item, Now), MOVEMENT_PADDING)
    local MoveIndex = math.max(0, math.floor(Normalize_Number(Item.MoveIndex, 0))) + 1
    local ItemId = if type(Item.Id) == "string" then Item.Id else ""
    local OwnerUserId = Plot:GetAttribute("OwnerUserId")
    local SeedUserId = if type(OwnerUserId) == "number" then OwnerUserId else 0
    local RandomGenerator = Random.new(Get_Stable_Seed(ItemId, SeedUserId, MoveIndex))
    local RectCount = #PlotAreaMath.GetUnlockedAreaRects(Plot)
    local IsCrowded = Count_Nearby_Items(Items, Item, CurrentPosition, Now) >= CROWDED_NEARBY_THRESHOLD
    local GlobalTargetChance = if IsCrowded then CROWDED_GLOBAL_TARGET_CHANCE else NORMAL_GLOBAL_TARGET_CHANCE

    for _ = 1, MOVEMENT_TARGET_ATTEMPTS do
        local Candidate = nil
        local ShouldTryGlobal = RectCount > 1 and RandomGenerator:NextNumber() < GlobalTargetChance

        if ShouldTryGlobal then
            Candidate = PlotAreaMath.GetRandomPositionInUnlockedArea(Plot, RandomGenerator, MOVEMENT_PADDING)
            Candidate = if Candidate then Vector3.new(Candidate.X, CurrentPosition.Y, Candidate.Z) else nil
        end

        if not Candidate then
            Candidate = Get_Local_Move_Candidate(RandomGenerator, CurrentPosition, IsCrowded)
        end

        Candidate = Apply_Gate_Avoidance(Plot, Candidate)

        if Is_Valid_Move_Target(Plot, Items, Item, CurrentPosition, Candidate, Now) then
            return Candidate
        end
    end

    local NearestPosition =
        PlotAreaMath.GetNearestPositionInUnlockedAreaWithClearance(Plot, CurrentPosition, MOVEMENT_PADDING)

    if NearestPosition then
        return Vector3.new(NearestPosition.X, CurrentPosition.Y, NearestPosition.Z)
    end

    return nil
end

local function Set_Item_Idle(Item: any, Position: Vector3, Now: number, RandomGenerator: Random)
    Set_Item_Position(Item, Position)
    Item.MoveState = MOVE_STATE_IDLE
    Item.MoveStartX = Position.X
    Item.MoveStartY = Position.Y
    Item.MoveStartZ = Position.Z
    Item.MoveTargetX = Position.X
    Item.MoveTargetY = Position.Y
    Item.MoveTargetZ = Position.Z
    Item.MoveStartedAt = Now
    Item.MoveDuration = 0
    Item.IdleUntil = Now + RandomGenerator:NextNumber(MIN_IDLE_SECONDS, MAX_IDLE_SECONDS)
end

local function Set_Item_Moving(Item: any, From: Vector3, Target: Vector3, Now: number)
    local Distance = (Vector3.new(Target.X, 0, Target.Z) - Vector3.new(From.X, 0, From.Z)).Magnitude
    local Duration = math.clamp(Distance / MOVEMENT_SPEED, MOVEMENT_MIN_DURATION, MOVEMENT_MAX_DURATION)
    local MoveIndex = math.max(0, math.floor(Normalize_Number(Item.MoveIndex, 0))) + 1

    Set_Item_Position(Item, From)
    Item.MoveState = MOVE_STATE_MOVING
    Item.MoveStartX = From.X
    Item.MoveStartY = From.Y
    Item.MoveStartZ = From.Z
    Item.MoveTargetX = Target.X
    Item.MoveTargetY = Target.Y
    Item.MoveTargetZ = Target.Z
    Item.MoveStartedAt = Now
    Item.MoveDuration = Duration
    Item.IdleUntil = Now + Duration
    Item.MoveIndex = MoveIndex
end

local function Pick_Initial_Spread_Position(
    Plot: Instance,
    RandomGenerator: Random,
    CurrentPosition: Vector3,
    UsedPositions: { Vector3 }
): Vector3
    for _ = 1, MOVEMENT_TARGET_ATTEMPTS do
        local Candidate = PlotAreaMath.GetRandomPositionInUnlockedArea(Plot, RandomGenerator, MOVEMENT_PADDING)

        if not Candidate then
            break
        end

        Candidate = Vector3.new(Candidate.X, CurrentPosition.Y, Candidate.Z)
        Candidate = Apply_Gate_Avoidance(Plot, Candidate)

        if
            PlotAreaMath.IsPositionInUnlockedAreaWithClearance(Plot, Candidate, MOVEMENT_PADDING)
            and not Is_Position_Near_Gate(Plot, Candidate)
            and not Is_Target_Too_Close_To_Positions(UsedPositions, Candidate)
        then
            return Candidate
        end
    end

    local NearestPosition =
        PlotAreaMath.GetNearestPositionInUnlockedAreaWithClearance(Plot, CurrentPosition, MOVEMENT_PADDING)

    if NearestPosition then
        return Vector3.new(NearestPosition.X, CurrentPosition.Y, NearestPosition.Z)
    end

    return CurrentPosition
end

local function Ensure_Player_Initial_Spread(Player: Player, Now: number)
    if InitialSpreadCheckedByUserId[Player.UserId] then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    local Plot = Get_Player_Plot(PlayerEntity)
    local CurrentPlotSquishies = World:get(PlayerEntity, Components.PlotSquishies)

    if not Plot or type(CurrentPlotSquishies) ~= "table" then
        return
    end

    InitialSpreadCheckedByUserId[Player.UserId] = true

    local PlotSquishies = Copy_Array(CurrentPlotSquishies)
    local UsedPositions = {}
    local DidChange = false

    for Index, Item in PlotSquishies do
        if type(Item) ~= "table" then
            continue
        end

        local CurrentPosition = Get_Item_Effective_Position(Item, Now)
        local IsOutside = Is_Position_Outside_Plot_Clearance(Plot, CurrentPosition, MOVEMENT_PADDING)
        local IsTooClose = Is_Target_Too_Close_To_Positions(UsedPositions, CurrentPosition)

        if IsOutside or IsTooClose then
            local ItemId = if type(Item.Id) == "string" then Item.Id else tostring(Index)
            local RandomGenerator = Random.new(Get_Stable_Seed(ItemId, Player.UserId, Index + 101))
            CurrentPosition = Pick_Initial_Spread_Position(Plot, RandomGenerator, CurrentPosition, UsedPositions)
            Set_Item_Idle(Item, CurrentPosition, Now, RandomGenerator)
            DidChange = true
        end

        table.insert(UsedPositions, Vector3.new(CurrentPosition.X, 0, CurrentPosition.Z))
    end

    if not DidChange then
        return
    end

    World:set(PlayerEntity, Components.PlotSquishies, PlotSquishies)
    Broadcast_Player_State(Player, PlayerEntity, true)
end

local function Ensure_All_Player_Initial_Spread()
    local Now = Get_Now()

    for _, Player in Players:GetPlayers() do
        Ensure_Player_Initial_Spread(Player, Now)
    end
end

local function Build_Placed_Item(Item: any, Position: Vector3): any?
    if type(Item) ~= "table" then
        return nil
    end

    local Kind = Item.Kind
    local Name = Item.Name

    if type(Kind) ~= "string" or type(Name) ~= "string" then
        return nil
    end

    local SquishyData = Squishies.GetData(Kind :: any, Name)

    if not SquishyData then
        return nil
    end

    local ItemId = if type(Item.Id) == "string" then Item.Id else ""

    if ItemId == "" then
        return nil
    end

    local BaseIncomePerSec = if type(Item.BaseIncomePerSec) == "number" and Item.BaseIncomePerSec > 0
        then Item.BaseIncomePerSec
        else SquishyData.IncomePerSec
    local Level = SquishyLevels.NormalizeLevel(Item.Level)
    local Now = Get_Now()
    local Result = {
        Id = ItemId,
        Type = "Squishy",
        Kind = Kind,
        Name = Name,
        Rarity = SquishyData.Rarity,
        Image = SquishyData.Image,
        BaseIncomePerSec = BaseIncomePerSec,
        FinalIncomePerSec = 0,
        Weight = if type(Item.Weight) == "number" then Item.Weight else 0,
        Mutation = InventoryMath.NormalizeMutation(Item.Mutation, Kind),
        EventMutations = InventoryMath.NormalizeEventMutations(Item.EventMutations),
        Level = Level,
        XP = if Level >= SquishyLevels.MaxLevel then 0 else SquishyLevels.NormalizeXp(Item.XP),
        Favorite = Item.Favorite == true,
        PositionX = Position.X,
        PositionY = Position.Y,
        PositionZ = Position.Z,
        PlacedAt = os.time(),
        StoredCash = 0,
        LastCashUpdate = Now,
        MoveState = MOVE_STATE_IDLE,
        MoveStartX = Position.X,
        MoveStartY = Position.Y,
        MoveStartZ = Position.Z,
        MoveTargetX = Position.X,
        MoveTargetY = Position.Y,
        MoveTargetZ = Position.Z,
        MoveStartedAt = Now,
        MoveDuration = 0,
        IdleUntil = Now + Random.new(Get_Stable_Seed(ItemId, math.floor(Now * 1000))):NextNumber(0.75, 2.25),
        MoveIndex = 0,
        TutorialRole = if Item.TutorialRole == TutorialSteps.FirstRole
                or Item.TutorialRole == TutorialSteps.StrongRole
            then Item.TutorialRole
            else nil,
    }

    Result.FinalIncomePerSec = InventoryMath.GetFinalIncomePerSec(Result)

    return Result
end

local function Normalize_Placed_Item(Item: any, MoneyMultiplier: number?): any?
    if type(Item) ~= "table" then
        return nil
    end

    local Kind = Item.Kind
    local Name = Item.Name

    if type(Kind) ~= "string" or type(Name) ~= "string" then
        return nil
    end

    local SquishyData = Squishies.GetData(Kind :: any, Name)

    if not SquishyData then
        return nil
    end

    local BaseIncomePerSec = if type(Item.BaseIncomePerSec) == "number" and Item.BaseIncomePerSec > 0
        then Item.BaseIncomePerSec
        else SquishyData.IncomePerSec
    local Level = SquishyLevels.NormalizeLevel(Item.Level)
    local Now = Get_Now()
    local StoredCash = Get_Accrued_Cash(Item, Now, MoneyMultiplier)
    local PositionX = if type(Item.PositionX) == "number" then Item.PositionX else 0
    local PositionY = if type(Item.PositionY) == "number" then Item.PositionY else 0
    local PositionZ = if type(Item.PositionZ) == "number" then Item.PositionZ else 0
    local MoveState = if Item.MoveState == MOVE_STATE_MOVING then MOVE_STATE_MOVING else MOVE_STATE_IDLE
    local Result = {
        Id = if type(Item.Id) == "string" then Item.Id else "",
        Type = "Squishy",
        Kind = Kind,
        Name = Name,
        Rarity = if type(Item.Rarity) == "string" then Item.Rarity else SquishyData.Rarity,
        Image = if type(Item.Image) == "string" then Item.Image else SquishyData.Image,
        BaseIncomePerSec = math.max(0, math.floor(BaseIncomePerSec + 0.5)),
        FinalIncomePerSec = 0,
        Weight = if type(Item.Weight) == "number" then Item.Weight else 0,
        Mutation = InventoryMath.NormalizeMutation(Item.Mutation, Kind),
        EventMutations = InventoryMath.NormalizeEventMutations(Item.EventMutations),
        Level = Level,
        XP = if Level >= SquishyLevels.MaxLevel then 0 else SquishyLevels.NormalizeXp(Item.XP),
        Favorite = Item.Favorite == true,
        PositionX = PositionX,
        PositionY = PositionY,
        PositionZ = PositionZ,
        StoredCash = StoredCash,
        LastCashUpdate = Now,
        MoveState = MoveState,
        MoveStartX = if type(Item.MoveStartX) == "number" then Item.MoveStartX else PositionX,
        MoveStartY = if type(Item.MoveStartY) == "number" then Item.MoveStartY else PositionY,
        MoveStartZ = if type(Item.MoveStartZ) == "number" then Item.MoveStartZ else PositionZ,
        MoveTargetX = if type(Item.MoveTargetX) == "number" then Item.MoveTargetX else PositionX,
        MoveTargetY = if type(Item.MoveTargetY) == "number" then Item.MoveTargetY else PositionY,
        MoveTargetZ = if type(Item.MoveTargetZ) == "number" then Item.MoveTargetZ else PositionZ,
        MoveStartedAt = if type(Item.MoveStartedAt) == "number" then Item.MoveStartedAt else Now,
        MoveDuration = math.max(0, Normalize_Number(Item.MoveDuration, 0)),
        IdleUntil = if type(Item.IdleUntil) == "number" then Item.IdleUntil else Now,
        MoveIndex = math.max(0, math.floor(Normalize_Number(Item.MoveIndex, 0))),
        TutorialRole = if Item.TutorialRole == TutorialSteps.FirstRole
                or Item.TutorialRole == TutorialSteps.StrongRole
            then Item.TutorialRole
            else nil,
    }

    Result.FinalIncomePerSec = math.max(0, math.floor(InventoryMath.GetFinalIncomePerSec(Result) + 0.5))

    if Result.Id == "" then
        return nil
    end

    return Result
end

local function Normalize_Placed_Array(Value: any, MoneyMultiplier: number?): { any }
    local Result = {}

    if type(Value) ~= "table" then
        return Result
    end

    for _, Item in Value do
        local Normalized = Normalize_Placed_Item(Item, MoneyMultiplier)

        if Normalized then
            table.insert(Result, Normalized)
        end
    end

    return Result
end

local function Fire_Notification(Player: Player, Text: string, Type: string?)
    Network.Notification.Fire(Player, {
        Text = Text,
        Type = Type or "Info",
        Duration = NOTIFICATION_DURATION,
    })
end

local function Is_Tutorial_Active(PlayerEntity: number): boolean
    return not TutorialProgress.Is_Complete(PlayerEntity)
end

local function Block_Tutorial_Action(Player: Player)
    Fire_Notification(Player, TutorialSteps.BlockedMessage, "Error")
end

local function Is_Tutorial_Role(Item: any, Role: string): boolean
    return type(Item) == "table" and Item.TutorialRole == Role
end

local function Queue_Collect_All_Group_Access_Load(Player: Player)
    if RunService:IsStudio() then
        CollectAllGroupAccessByUserId[Player.UserId] = true
        CollectAllGroupAccessPendingByUserId[Player.UserId] = nil
        return
    end

    if game.CreatorType ~= Enum.CreatorType.Group or game.CreatorId <= 0 then
        CollectAllGroupAccessByUserId[Player.UserId] = true
        CollectAllGroupAccessPendingByUserId[Player.UserId] = nil
        return
    end

    if CollectAllGroupAccessByUserId[Player.UserId] ~= nil or CollectAllGroupAccessPendingByUserId[Player.UserId] then
        return
    end

    CollectAllGroupAccessPendingByUserId[Player.UserId] = true

    task.spawn(function()
        local Success, IsInGroup = pcall(function()
            return Player:IsInGroup(game.CreatorId)
        end)

        CollectAllGroupAccessPendingByUserId[Player.UserId] = nil

        if not Player.Parent then
            CollectAllGroupAccessByUserId[Player.UserId] = nil
            PendingCollectAllRequestByUserId[Player.UserId] = nil
            return
        end

        CollectAllGroupAccessByUserId[Player.UserId] = Success and IsInGroup == true

        if PendingCollectAllRequestByUserId[Player.UserId] then
            PendingCollectAllRequestByUserId[Player.UserId] = nil

            local CollectAll = Collect_All_Squishy_Cash

            if CollectAll then
                task.defer(CollectAll, Player, true)
            end
        end
    end)
end

local function Get_Collect_All_Access(Player: Player): boolean?
    if RunService:IsStudio() then
        return true
    end

    if game.CreatorType ~= Enum.CreatorType.Group or game.CreatorId <= 0 then
        return true
    end

    local Cached = CollectAllGroupAccessByUserId[Player.UserId]

    if Cached ~= nil then
        return Cached
    end

    Queue_Collect_All_Group_Access_Load(Player)
    return nil
end

local function Normalize_Instance_Name(Name: string): string
    return string.lower((string.gsub(Name, "[%s_%-%p]+", "")))
end

local function Is_Collect_All_Model(InstanceToCheck: Instance): boolean
    local NormalizedName = Normalize_Instance_Name(InstanceToCheck.Name)

    return string.find(NormalizedName, "collect", 1, true) ~= nil
        and string.find(NormalizedName, "cash", 1, true) ~= nil
end

local function Get_Collect_All_Model(Plot: Instance?): Instance?
    if not Plot then
        return nil
    end

    local Direct = Plot:FindFirstChild(COLLECT_ALL_MODEL_NAME)

    if Direct then
        return Direct
    end

    for _, Child in Plot:GetChildren() do
        if Is_Collect_All_Model(Child) then
            return Child
        end
    end

    return nil
end

local function Get_Collect_All_Activate_Part(Plot: Instance?): BasePart?
    local Model = Get_Collect_All_Model(Plot)
    local Activate = Model and Model:FindFirstChild(COLLECT_ALL_ACTIVATE_PART_NAME, true)

    if Activate and Activate:IsA("BasePart") then
        return Activate
    end

    return nil
end

local function Is_Part_In_Collect_All_Activate(Activate: BasePart, Part: BasePart): boolean
    local LocalPosition = Activate.CFrame:PointToObjectSpace(Part.Position)
    local HalfSize = Activate.Size * 0.5

    return math.abs(LocalPosition.X) <= HalfSize.X + COLLECT_ALL_ACTIVATE_PADDING_XZ
        and math.abs(LocalPosition.Z) <= HalfSize.Z + COLLECT_ALL_ACTIVATE_PADDING_XZ
        and math.abs(LocalPosition.Y) <= HalfSize.Y + COLLECT_ALL_ACTIVATE_PADDING_Y
end

local function Is_Position_In_Collect_All_Activate(Activate: BasePart, Position: Vector3): boolean
    local LocalPosition = Activate.CFrame:PointToObjectSpace(Position)
    local HalfSize = Activate.Size * 0.5

    return math.abs(LocalPosition.X) <= HalfSize.X + COLLECT_ALL_ACTIVATE_PADDING_XZ
        and math.abs(LocalPosition.Z) <= HalfSize.Z + COLLECT_ALL_ACTIVATE_PADDING_XZ
        and math.abs(LocalPosition.Y) <= HalfSize.Y + COLLECT_ALL_ACTIVATE_PADDING_Y
end

local function Is_Player_Touching_Collect_All(Player: Player, PlayerEntity: number): boolean
    local Activate = Get_Collect_All_Activate_Part(Get_Player_Plot(PlayerEntity))
    local Character = Player.Character

    if not Activate or not Character then
        return false
    end

    local OverlapParamsObject = OverlapParams.new()
    OverlapParamsObject.FilterType = Enum.RaycastFilterType.Include
    OverlapParamsObject.FilterDescendantsInstances = { Character }

    local Parts = workspace:GetPartBoundsInBox(
        Activate.CFrame,
        Activate.Size
            + Vector3.new(
                COLLECT_ALL_ACTIVATE_PADDING_XZ * 2,
                COLLECT_ALL_ACTIVATE_PADDING_Y * 2,
                COLLECT_ALL_ACTIVATE_PADDING_XZ * 2
            ),
        OverlapParamsObject
    )

    if #Parts > 0 then
        return true
    end

    local RootPart = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart

    if RootPart and RootPart:IsA("BasePart") and Is_Position_In_Collect_All_Activate(Activate, RootPart.Position) then
        return true
    end

    for _, Descendant in Character:GetDescendants() do
        if Descendant:IsA("BasePart") and Is_Part_In_Collect_All_Activate(Activate, Descendant) then
            return true
        end
    end

    return false
end

local function Notify_Event_Mutations(Player: Player, Item: any, AddedEvents: { string })
    if type(Item) ~= "table" or type(AddedEvents) ~= "table" or #AddedEvents <= 0 then
        return
    end

    local SquishyName = InventoryMath.FormatSquishyDisplayName(Item.Kind, Item.Name, Item.Mutation)

    for _, EventName in AddedEvents do
        Fire_Notification(Player, `{SquishyName} got the {Events.GetDisplayName(EventName)} Event Mutation!`, "Reward")
    end
end

local function Fire_Player_State(
    TargetPlayer: Player?,
    SourcePlayer: Player,
    Items: any,
    SuppressCollectBounce: boolean?
)
    local SourceEntity = Get_Player_Entity(SourcePlayer)
    local MoneyMultiplier = Get_Money_Multiplier(SourceEntity)
    local Payload = {
        PlayerUserId = SourcePlayer.UserId,
        SuppressCollectBounce = SuppressCollectBounce == true,
        Items = Normalize_Placed_Array(Items, MoneyMultiplier),
    }

    if TargetPlayer then
        Network.PlotSquishiesChanged.Fire(TargetPlayer, Payload)
    else
        Network.PlotSquishiesChanged.FireAll(Payload)
    end
end

Broadcast_Player_State = function(Player: Player, PlayerEntity: number, SuppressCollectBounce: boolean?)
    Fire_Player_State(nil, Player, World:get(PlayerEntity, Components.PlotSquishies), SuppressCollectBounce)
end

local function Send_All_States_To(Player: Player)
    for _, SourcePlayer in Players:GetPlayers() do
        local PlayerEntity = Get_Player_Entity(SourcePlayer)

        if PlayerEntity then
            Fire_Player_State(Player, SourcePlayer, World:get(PlayerEntity, Components.PlotSquishies))
        end
    end
end

local function Place_Squishy(Player: Player, ItemId: string)
    if type(ItemId) ~= "string" or ItemId == "" then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    local Plot = Get_Player_Plot(PlayerEntity)
    local Character = Player.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if not Plot or not Root or not Root:IsA("BasePart") then
        return
    end

    if not PlotAreaMath.IsPositionInUnlockedArea(Plot, Root.Position) then
        Fire_Notification(Player, "Stand inside your pen to place.", "Error")
        return
    end

    local PlotSquishies = Copy_Array(World:get(PlayerEntity, Components.PlotSquishies))
    local MaxSquishies = PlotAreaMath.GetMaxSquishies(Plot)

    if #PlotSquishies >= MaxSquishies then
        Fire_Notification(Player, "Pen is full.", "Error")
        return
    end

    local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))
    local ExistingItem = Find_Squishy(OwnedSquishies, ItemId)
    local TutorialStep = TutorialProgress.Get(PlayerEntity)

    if Is_Tutorial_Active(PlayerEntity) then
        local ExpectedRole = if TutorialStep == TutorialSteps.PlaceFirst
            then TutorialSteps.FirstRole
            elseif TutorialStep == TutorialSteps.PlaceStrong then TutorialSteps.StrongRole
            else nil

        if not ExpectedRole or not Is_Tutorial_Role(ExistingItem, ExpectedRole) then
            Block_Tutorial_Action(Player)
            return
        end
    end

    local Item = Find_And_Remove_Squishy(OwnedSquishies, ItemId)

    if not Item then
        return
    end

    local PlacementPosition = Get_Placement_Position(Plot, Root.Position)

    if not PlacementPosition then
        Fire_Notification(Player, "Stand inside your pen to place.", "Error")
        return
    end

    local PlacedItem = Build_Placed_Item(Item, PlacementPosition)

    if not PlacedItem then
        return
    end

    if TutorialStep == TutorialSteps.PlaceFirst then
        PlacedItem.TutorialRole = TutorialSteps.FirstRole
    elseif TutorialStep == TutorialSteps.PlaceStrong then
        PlacedItem.TutorialRole = TutorialSteps.StrongRole
    end

    local Now = Get_Now()
    local DidMutate, AddedEvents = Apply_Event_Mutation_Rolls_To_Item(
        PlacedItem,
        EventService.GetActiveEvents(),
        Random.new(Get_Stable_Seed(PlacedItem.Id, Player.UserId, math.floor(Now * 1000))),
        Now,
        Get_Money_Multiplier(PlayerEntity)
    )

    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))
    Remove_From_Hotbar(HotbarSlots, ItemId)
    table.insert(PlotSquishies, PlacedItem)

    World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    World:set(PlayerEntity, Components.PlotSquishies, PlotSquishies)

    if DidMutate then
        Notify_Event_Mutations(Player, PlacedItem, AddedEvents)
    end

    if TutorialStep == TutorialSteps.PlaceFirst and PlacedItem.TutorialRole == TutorialSteps.FirstRole then
        TutorialProgress.Complete_Step(PlayerEntity, TutorialSteps.PlaceFirst, TutorialSteps.CollectCash)
    elseif TutorialStep == TutorialSteps.PlaceStrong and PlacedItem.TutorialRole == TutorialSteps.StrongRole then
        TutorialProgress.Complete_Step(PlayerEntity, TutorialSteps.PlaceStrong, TutorialSteps.FeedStrong)
    end

    Broadcast_Player_State(Player, PlayerEntity)
end

local function Remove_Placed_Squishy(Player: Player, ItemId: string)
    if type(ItemId) ~= "string" or ItemId == "" then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    if not InventoryCapacity.CanAddSquishies(World:get(PlayerEntity, Components.OwnedSquishies), 1) then
        Fire_Notification(Player, InventoryCapacity.SquishyInventoryFullMessage, "Error")
        return
    end

    local PlotSquishies = Copy_Array(World:get(PlayerEntity, Components.PlotSquishies))
    local ExistingItem = Find_Placed_Squishy(PlotSquishies, ItemId)
    local TutorialStep = TutorialProgress.Get(PlayerEntity)

    if
        Is_Tutorial_Active(PlayerEntity)
        and (TutorialStep ~= TutorialSteps.PickupOld or not Is_Tutorial_Role(ExistingItem, TutorialSteps.FirstRole))
    then
        Block_Tutorial_Action(Player)
        return
    end

    local Item = Find_And_Remove_Squishy(PlotSquishies, ItemId)

    if not Item then
        return
    end

    local AccruedCash = Accrue_Item_Cash(Item, Get_Now(), Get_Money_Multiplier(PlayerEntity))
    local CollectedCash = math.floor(AccruedCash)

    if CollectedCash > 0 then
        Add_Cash(PlayerEntity, CollectedCash)
    end

    local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))
    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))
    local ReturnedSlot = Get_First_Open_Hotbar_Slot(HotbarSlots)
    local ReturnedItem = table.clone(Item)
    ReturnedItem.HotbarSlot = ReturnedSlot
    ReturnedItem.Equipped = false
    ReturnedItem.PositionX = nil
    ReturnedItem.PositionY = nil
    ReturnedItem.PositionZ = nil
    ReturnedItem.PlacedAt = nil
    ReturnedItem.StoredCash = nil
    ReturnedItem.LastCashUpdate = nil
    ReturnedItem.MoveState = nil
    ReturnedItem.MoveStartX = nil
    ReturnedItem.MoveStartY = nil
    ReturnedItem.MoveStartZ = nil
    ReturnedItem.MoveTargetX = nil
    ReturnedItem.MoveTargetY = nil
    ReturnedItem.MoveTargetZ = nil
    ReturnedItem.MoveStartedAt = nil
    ReturnedItem.MoveDuration = nil
    ReturnedItem.IdleUntil = nil
    ReturnedItem.MoveIndex = nil
    table.insert(OwnedSquishies, ReturnedItem)

    if ReturnedSlot then
        HotbarSlots[tostring(ReturnedSlot)] = {
            Slot = ReturnedSlot,
            ItemId = ReturnedItem.Id,
            ItemType = "Squishy",
        }
    end

    World:set(PlayerEntity, Components.PlotSquishies, PlotSquishies)
    World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)

    Fire_Notification(
        Player,
        if ReturnedSlot then "Squishy returned to hotbar." else "Squishy returned to inventory.",
        "Info"
    )

    if ReturnedItem.TutorialRole == TutorialSteps.FirstRole then
        TutorialProgress.Complete_Step(PlayerEntity, TutorialSteps.PickupOld, TutorialSteps.SellOld)
    end

    Broadcast_Player_State(Player, PlayerEntity)
end

local function Collect_Squishy_Cash(Player: Player, ItemId: string)
    if type(ItemId) ~= "string" or ItemId == "" then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    if Get_Selected_Food_Data(Player, PlayerEntity) then
        return
    end

    local PlotSquishies = Copy_Array(World:get(PlayerEntity, Components.PlotSquishies))
    local Item = Find_Placed_Squishy(PlotSquishies, ItemId)

    if not Item then
        return
    end

    local Now = Get_Now()
    local CollectKey = Get_Collect_Key(Player, ItemId)
    local LastCollectAt = LastCollectAtByKey[CollectKey]

    if LastCollectAt and Now - LastCollectAt < COLLECT_COOLDOWN_SECONDS then
        return
    end

    local AccruedCash = Accrue_Item_Cash(Item, Now, Get_Money_Multiplier(PlayerEntity))
    local CollectedCash = math.floor(AccruedCash)
    local TutorialShortfall = Get_Tutorial_Collect_Shortfall(PlayerEntity)

    if CollectedCash < CASH_COLLECT_MIN_AMOUNT and TutorialShortfall <= 0 then
        return
    end

    CollectedCash = math.max(CollectedCash, TutorialShortfall)
    LastCollectAtByKey[CollectKey] = Now
    Item.StoredCash = math.max(0, AccruedCash - CollectedCash)
    Add_Cash(PlayerEntity, CollectedCash)
    World:set(PlayerEntity, Components.PlotSquishies, PlotSquishies)
    if TutorialProgress.Complete_Step(PlayerEntity, TutorialSteps.CollectCash, TutorialSteps.BuyNextLasso) then
        Teleport_Player_In_Front_Of_Plot_Target(Player, PlayerEntity, TUTORIAL_LASSO_SHOP_NAME)
    end
    Network.CollectEffect.FireAll({
        PlayerUserId = Player.UserId,
        ItemId = ItemId,
    })
    Broadcast_Player_State(Player, PlayerEntity)
end

Collect_All_Squishy_Cash = function(Player: Player, SkipTouchValidation: boolean?)
    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    if Is_Tutorial_Active(PlayerEntity) then
        Block_Tutorial_Action(Player)
        return
    end

    if SkipTouchValidation ~= true and not Is_Player_Touching_Collect_All(Player, PlayerEntity) then
        return
    end

    local Access = Get_Collect_All_Access(Player)

    if Access == nil then
        PendingCollectAllRequestByUserId[Player.UserId] = true
        return
    end

    local Now = Get_Now()
    local CollectKey = Get_Collect_All_Key(Player)
    local LastCollectAt = LastCollectAtByKey[CollectKey]

    if LastCollectAt and Now - LastCollectAt < COLLECT_COOLDOWN_SECONDS then
        return
    end

    if not Access then
        LastCollectAtByKey[CollectKey] = Now
        Fire_Notification(Player, COLLECT_ALL_GROUP_NOTIFICATION, "Error")
        return
    end

    local PlotSquishies = Copy_Array(World:get(PlayerEntity, Components.PlotSquishies))
    local MoneyMultiplier = Get_Money_Multiplier(PlayerEntity)
    local CollectedCash = 0

    for _, Item in PlotSquishies do
        if type(Item) ~= "table" then
            continue
        end

        local AccruedCash = Accrue_Item_Cash(Item, Now, MoneyMultiplier)
        local ItemCash = math.floor(AccruedCash)

        if ItemCash < CASH_COLLECT_MIN_AMOUNT then
            continue
        end

        Item.StoredCash = math.max(0, AccruedCash - ItemCash)
        CollectedCash += ItemCash
    end

    local TutorialShortfall = Get_Tutorial_Collect_Shortfall(PlayerEntity)

    if CollectedCash < CASH_COLLECT_MIN_AMOUNT and TutorialShortfall <= 0 then
        return
    end

    CollectedCash = math.max(CollectedCash, TutorialShortfall)
    LastCollectAtByKey[CollectKey] = Now
    Add_Cash(PlayerEntity, CollectedCash)
    World:set(PlayerEntity, Components.PlotSquishies, PlotSquishies)
    Network.CollectAllEffect.FireAll({
        PlayerUserId = Player.UserId,
    })
    TutorialProgress.Complete_Step(PlayerEntity, TutorialSteps.CollectCash, TutorialSteps.BuyNextLasso)
    Broadcast_Player_State(Player, PlayerEntity, true)
end

local function Feed_Squishy(Player: Player, ItemId: string, Amount: any)
    if type(ItemId) ~= "string" or ItemId == "" then
        return
    end

    local FeedAmount = if type(Amount) == "number" then math.floor(Amount) else 0

    if not FEED_AMOUNTS[FeedAmount] then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    local TutorialStep = TutorialProgress.Get(PlayerEntity)

    if Is_Tutorial_Active(PlayerEntity) and TutorialStep ~= TutorialSteps.FeedStrong then
        Block_Tutorial_Action(Player)
        return
    end

    local IsTutorialFeed = Is_Tutorial_Active(PlayerEntity) and TutorialStep == TutorialSteps.FeedStrong
    local FoodData = if IsTutorialFeed
        then Foods.Get(TutorialSteps.FeedName)
        else Get_Selected_Food_Data(Player, PlayerEntity)

    if not FoodData then
        Fire_Notification(Player, "Equip food to feed.", "Error")
        return
    end

    local PlotSquishies = Copy_Array(World:get(PlayerEntity, Components.PlotSquishies))
    local Item = Find_Placed_Squishy(PlotSquishies, ItemId)

    if not Item then
        return
    end

    if
        Is_Tutorial_Active(PlayerEntity)
        and (not Is_Tutorial_Role(Item, TutorialSteps.StrongRole) or FoodData.Name ~= TutorialSteps.FeedName)
    then
        Block_Tutorial_Action(Player)
        return
    end

    local CurrentLevel = SquishyLevels.NormalizeLevel(Item.Level)

    if CurrentLevel >= SquishyLevels.MaxLevel then
        Fire_Notification(Player, "Squishy is already max level.", "Info")
        return
    end

    local OwnedFood = Copy_Array(World:get(PlayerEntity, Components.OwnedFood))
    local FoodEntry, FoodIndex = Find_Food_Entry(OwnedFood, FoodData.Name)
    local CurrentFoodAmount = if type(FoodEntry) == "table" and type(FoodEntry.Amount) == "number"
        then math.floor(FoodEntry.Amount)
        else 0

    if not FoodEntry or not FoodIndex or CurrentFoodAmount < FeedAmount then
        Fire_Notification(Player, "Not enough food.", "Error")
        return
    end

    local Now = Get_Now()
    Accrue_Item_Cash(Item, Now, Get_Money_Multiplier(PlayerEntity))

    local XPGain = math.max(0, math.floor(FoodData.XPValue * FeedAmount))
    local NewLevel, NewXP, DidLevelUp = SquishyLevels.ApplyXp(CurrentLevel, Item.XP, XPGain, Item.Rarity)

    Item.Level = NewLevel
    Item.XP = NewXP
    Item.FinalIncomePerSec = math.max(0, math.floor(InventoryMath.GetFinalIncomePerSec(Item) + 0.5))

    FoodEntry.Amount = CurrentFoodAmount - FeedAmount

    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))

    if FoodEntry.Amount <= 0 then
        table.remove(OwnedFood, FoodIndex)
        Remove_Food_From_Hotbar(HotbarSlots, FoodData.Name)
    end

    World:set(PlayerEntity, Components.OwnedFood, OwnedFood)
    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    World:set(PlayerEntity, Components.PlotSquishies, PlotSquishies)
    Network.FeedEffect.FireAll({
        PlayerUserId = Player.UserId,
        ItemId = ItemId,
    })
    TutorialProgress.Complete_Step(PlayerEntity, TutorialSteps.FeedStrong, TutorialSteps.SellOld)

    if DidLevelUp then
        local SquishyDisplayName = InventoryMath.FormatSquishyDisplayName(Item.Kind, Item.Name, Item.Mutation)

        Fire_Notification(Player, `{SquishyDisplayName} reached Level {NewLevel}!`, "Success")
    end

    Broadcast_Player_State(Player, PlayerEntity)
end

local function Advance_Item_Movement(Plot: Model, Items: { any }, Item: any, Now: number): boolean
    if type(Item) ~= "table" then
        return false
    end

    local MoveState = if Item.MoveState == MOVE_STATE_MOVING then MOVE_STATE_MOVING else MOVE_STATE_IDLE
    local MoveIndex = math.max(0, math.floor(Normalize_Number(Item.MoveIndex, 0)))
    local ItemId = if type(Item.Id) == "string" then Item.Id else ""
    local OwnerUserId = Plot:GetAttribute("OwnerUserId")
    local SeedUserId = if type(OwnerUserId) == "number" then OwnerUserId else 0
    local RandomGenerator = Random.new(Get_Stable_Seed(ItemId, SeedUserId, MoveIndex + 17))

    if MoveState == MOVE_STATE_MOVING then
        local RawCurrentPosition = Get_Item_Effective_Position(Item, Now)

        if Is_Position_Outside_Plot_Clearance(Plot, RawCurrentPosition, MOVEMENT_PADDING) then
            Set_Item_Idle(
                Item,
                Clamp_Position_To_Plot(Plot, RawCurrentPosition, MOVEMENT_PADDING),
                Now,
                RandomGenerator
            )
            return true
        end

        local StartedAt = Normalize_Number(Item.MoveStartedAt, Now)
        local Duration = math.max(0.001, Normalize_Number(Item.MoveDuration, 0))

        if Now < StartedAt + Duration then
            return false
        end

        Set_Item_Idle(
            Item,
            Clamp_Position_To_Plot(Plot, Get_Item_Move_Target(Item), MOVEMENT_PADDING),
            Now,
            RandomGenerator
        )
        return true
    end

    local IdleUntil = Normalize_Number(Item.IdleUntil, Now)

    if Now < IdleUntil then
        return false
    end

    local RawCurrentPosition = Get_Item_Effective_Position(Item, Now)
    local CurrentPosition = Clamp_Position_To_Plot(Plot, RawCurrentPosition, MOVEMENT_PADDING)

    if
        (Vector3.new(CurrentPosition.X, 0, CurrentPosition.Z) - Vector3.new(
            RawCurrentPosition.X,
            0,
            RawCurrentPosition.Z
        )).Magnitude > 0.05
    then
        Set_Item_Idle(Item, CurrentPosition, Now, RandomGenerator)
        return true
    end

    local Target = Pick_Move_Target(Plot, Items, Item, Now)

    if not Target then
        Set_Item_Idle(Item, CurrentPosition, Now, RandomGenerator)
        return true
    end

    Set_Item_Moving(Item, CurrentPosition, Target, Now)
    return true
end

local function Is_Item_Movement_Due(Item: any, Now: number): boolean
    if type(Item) ~= "table" then
        return false
    end

    local MoveState = if Item.MoveState == MOVE_STATE_MOVING then MOVE_STATE_MOVING else MOVE_STATE_IDLE

    if MoveState == MOVE_STATE_MOVING then
        local StartedAt = Normalize_Number(Item.MoveStartedAt, Now)
        local Duration = math.max(0.001, Normalize_Number(Item.MoveDuration, 0))

        return Now >= StartedAt + Duration
    end

    return Now >= Normalize_Number(Item.IdleUntil, Now)
end

local function Has_Movement_Due(Plot: Instance, Items: any, Now: number): boolean
    if type(Items) ~= "table" then
        return false
    end

    for _, Item in Items do
        if Is_Item_Movement_Due(Item, Now) or Is_Item_Outside_Plot_Clearance(Plot, Item, Now) then
            return true
        end
    end

    return false
end

local function Advance_Player_Movement(Player: Player, Now: number)
    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    local Plot = Get_Player_Plot(PlayerEntity)

    if not Plot then
        return
    end

    local CurrentPlotSquishies = World:get(PlayerEntity, Components.PlotSquishies)

    if not Has_Movement_Due(Plot, CurrentPlotSquishies, Now) then
        return
    end

    local PlotSquishies = Copy_Array(CurrentPlotSquishies)
    local DidChange = false

    for _, Item in PlotSquishies do
        if
            (Is_Item_Movement_Due(Item, Now) or Is_Item_Outside_Plot_Clearance(Plot, Item, Now))
            and Advance_Item_Movement(Plot, PlotSquishies, Item, Now)
        then
            DidChange = true
        end
    end

    if not DidChange then
        return
    end

    World:set(PlayerEntity, Components.PlotSquishies, PlotSquishies)
    Broadcast_Player_State(Player, PlayerEntity)
end

local function Advance_All_Movement()
    local Now = Get_Now()

    if Now - LastMovementTick < MOVEMENT_TICK_SECONDS then
        return
    end

    LastMovementTick = Now

    for _, Player in Players:GetPlayers() do
        Advance_Player_Movement(Player, Now)
    end
end

local function Apply_Event_Mutation_Rolls_To_Player(Player: Player, Now: number, ActiveEvents: any)
    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    local CurrentPlotSquishies = World:get(PlayerEntity, Components.PlotSquishies)

    if type(CurrentPlotSquishies) ~= "table" then
        return
    end

    local PlotSquishies = Copy_Array(CurrentPlotSquishies)
    local DidChange = false

    for _, Item in PlotSquishies do
        local ItemId = if type(Item) == "table" and type(Item.Id) == "string" then Item.Id else ""
        local Rng = Random.new(Get_Stable_Seed(ItemId, Player.UserId, math.floor(Now)))

        local DidItemChange, AddedEvents =
            Apply_Event_Mutation_Rolls_To_Item(Item, ActiveEvents, Rng, Now, Get_Money_Multiplier(PlayerEntity))

        if DidItemChange then
            DidChange = true
            Notify_Event_Mutations(Player, Item, AddedEvents)
        end
    end

    if not DidChange then
        return
    end

    World:set(PlayerEntity, Components.PlotSquishies, PlotSquishies)
    Broadcast_Player_State(Player, PlayerEntity)
end

local function Apply_Event_Mutation_Rolls_To_All_Plots()
    local Now = Get_Now()

    if Now - LastEventMutationRollTick < EVENT_MUTATION_ROLL_TICK_SECONDS then
        return
    end

    LastEventMutationRollTick = Now

    local ActiveEvents = EventService.GetActiveEvents()

    if next(ActiveEvents) == nil then
        return
    end

    for _, Player in Players:GetPlayers() do
        Apply_Event_Mutation_Rolls_To_Player(Player, Now, ActiveEvents)
    end
end

local function Accrue_All_Plot_Cash(PlayerEntity: number, Now: number, MoneyMultiplier: number): boolean
    local CurrentPlotSquishies = World:get(PlayerEntity, Components.PlotSquishies)

    if type(CurrentPlotSquishies) ~= "table" then
        return false
    end

    local PlotSquishies = Copy_Array(CurrentPlotSquishies)
    local DidChange = false

    for _, Item in PlotSquishies do
        if type(Item) ~= "table" then
            continue
        end

        local LastCashUpdate = Normalize_Number(Item.LastCashUpdate, Now)

        if Now <= LastCashUpdate then
            continue
        end

        Accrue_Item_Cash(Item, Now, MoneyMultiplier)
        DidChange = true
    end

    if DidChange then
        World:set(PlayerEntity, Components.PlotSquishies, PlotSquishies)
    end

    return DidChange
end

local function Sync_Money_Multiplier_Changes()
    local Now = Get_Now()

    for _, Player in Players:GetPlayers() do
        local PlayerEntity = Get_Player_Entity(Player)

        if not PlayerEntity then
            LastMoneyMultiplierByUserId[Player.UserId] = nil
            continue
        end

        local CurrentMultiplier = Get_Money_Multiplier(PlayerEntity)
        local PreviousMultiplier = LastMoneyMultiplierByUserId[Player.UserId]

        if not PreviousMultiplier then
            LastMoneyMultiplierByUserId[Player.UserId] = CurrentMultiplier
            Broadcast_Player_State(Player, PlayerEntity)
            continue
        end

        if CurrentMultiplier == PreviousMultiplier then
            continue
        end

        Accrue_All_Plot_Cash(PlayerEntity, Now, PreviousMultiplier)
        LastMoneyMultiplierByUserId[Player.UserId] = CurrentMultiplier
        Broadcast_Player_State(Player, PlayerEntity)
    end
end

local function Process_Remotes()
    if not PlayerAddedConnection then
        PlayerAddedConnection = Players.PlayerAdded:Connect(function(Player)
            Queue_Collect_All_Group_Access_Load(Player)
        end)

        for _, Player in Players:GetPlayers() do
            Queue_Collect_All_Group_Access_Load(Player)
        end
    end

    if not PlayerRemovingConnection then
        PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(Player)
            Clear_Player_Collect_Cooldowns(Player)
            LastMoneyMultiplierByUserId[Player.UserId] = nil
            CollectAllGroupAccessByUserId[Player.UserId] = nil
            CollectAllGroupAccessPendingByUserId[Player.UserId] = nil
            PendingCollectAllRequestByUserId[Player.UserId] = nil
            InitialSpreadCheckedByUserId[Player.UserId] = nil
            Fire_Player_State(nil, Player, {})
        end)
    end

    for _, Player in Network.PlotSquishiesSyncRequest.Iter() do
        if not RemoteCooldowns.Allow(Player, "PlotSquishiesSyncRequest") then
            continue
        end

        Send_All_States_To(Player)
    end

    for _, Player, Data in Network.PlacePlotSquishy.Iter() do
        if not RemoteCooldowns.Allow(Player, "PlacePlotSquishy") then
            continue
        end

        Place_Squishy(Player, Data.ItemId)
    end

    for _, Player, Data in Network.RemovePlotSquishy.Iter() do
        if not RemoteCooldowns.Allow(Player, "RemovePlotSquishy") then
            continue
        end

        Remove_Placed_Squishy(Player, Data.ItemId)
    end

    for _, Player, Data in Network.CollectPlotSquishyCash.Iter() do
        if not RemoteCooldowns.Allow(Player, "CollectPlotSquishyCash") then
            continue
        end

        Collect_Squishy_Cash(Player, Data.ItemId)
    end

    for _, Player in Network.CollectAllPlotSquishyCash.Iter() do
        Collect_All_Squishy_Cash(Player, true)
    end

    for _, Player, Data in Network.FeedPlotSquishy.Iter() do
        if not RemoteCooldowns.Allow(Player, "FeedPlotSquishy") then
            continue
        end

        Feed_Squishy(Player, Data.ItemId, Data.Amount)
    end

    Sync_Money_Multiplier_Changes()
    Ensure_All_Player_Initial_Spread()
    Advance_All_Movement()
    Apply_Event_Mutation_Rolls_To_All_Plots()
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = Process_Remotes,
    runConditions = {},
}
