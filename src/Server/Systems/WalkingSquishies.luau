local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)

local Components = require(ReplicatedStorage.Shared.Components)
local EventMutations = require(ReplicatedStorage.Shared.Modules.EventMutations)
local EventService = require(script.Parent.Parent.Modules.EventService)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local SquishyLevels = require(ReplicatedStorage.Shared.Modules.SquishyLevels)
local World = require(ReplicatedStorage.Shared.World)

type WalkingSquishyState = {
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

local PlayerStates: { [Player]: WalkingSquishyState } = {}
local BoundPlayers: { [Player]: boolean } = {}
local EVENT_MUTATION_ROLL_TICK_SECONDS = 0.5
local EVENT_MUTATION_ROLL_END_PADDING_SECONDS = 3
local EventMutationRNG = Random.new()
local LastEventMutationRollTick = 0

type EventMutationRollState = {
    StartedAt: number,
    RollAt: number,
    Rolled: boolean,
}

local EventMutationRollsByItemId: { [string]: { [string]: EventMutationRollState } } = {}

local function Get_Player_Entity(Player: Player): number?
    local Entity = Registry.Get("Players", Player)

    if Entity and World:contains(Entity) then
        return Entity
    end

    return nil
end

local function Copy_Array(Value): { any }
    local Result = {}

    if type(Value) ~= "table" then
        return Result
    end

    for _, Entry in Value do
        table.insert(Result, Entry)
    end

    return Result
end

local function Find_Owned_Squishy_In_Array(OwnedSquishies: any, ItemId: string): any?
    if type(ItemId) ~= "string" or ItemId == "" then
        return nil
    end

    if type(OwnedSquishies) ~= "table" then
        return nil
    end

    for _, Entry in OwnedSquishies do
        if type(Entry) == "table" and Entry.Id == ItemId and Entry.Type == "Squishy" then
            return Entry
        end
    end

    return nil
end

local function Find_Owned_Squishy(PlayerEntity: number, ItemId: string): any?
    return Find_Owned_Squishy_In_Array(World:get(PlayerEntity, Components.OwnedSquishies), ItemId)
end

local function Get_Event_Roll_Record(ItemId: string): { [string]: EventMutationRollState }
    local Record = EventMutationRollsByItemId[ItemId]

    if not Record then
        Record = {}
        EventMutationRollsByItemId[ItemId] = Record
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
    ItemId: string,
    EventName: string,
    ActiveEvent: any,
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

local function Apply_Event_Mutation_Rolls_To_Item(Item: any, ActiveEvents: any, Now: number): boolean
    if type(Item) ~= "table" or type(Item.Id) ~= "string" or Item.Id == "" or type(ActiveEvents) ~= "table" then
        return false
    end

    local CurrentEventMutations = EventMutations.NormalizeList(Item.EventMutations)
    local DidChange = false

    for EventName, ActiveEvent in ActiveEvents do
        if EventMutations.Has(CurrentEventMutations, EventName) then
            continue
        end

        local EventRoll = Get_Or_Create_Event_Mutation_Roll(Item.Id, EventName, ActiveEvent, Now)

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
        Item.EventMutations = CurrentEventMutations
        Item.FinalIncomePerSec = math.max(0, math.floor(InventoryMath.GetFinalIncomePerSec(Item) + 0.5))
    end

    return DidChange
end

local function Get_Selected_Lasso_Name(PlayerEntity: number): string
    local OwnedLassos = Lassos.Normalize_Owned(World:get(PlayerEntity, Components.OwnedLassos))

    return Lassos.Normalize_Selected(World:get(PlayerEntity, Components.Lasso), OwnedLassos)
end

local function Get_Config_Base_Income(Kind: string, Name: string): number
    local SquishyData = Squishies.GetData(Kind :: any, Name)

    if SquishyData and type(SquishyData.IncomePerSec) == "number" then
        return math.max(0, SquishyData.IncomePerSec)
    end

    return 0
end

local function Build_State(PlayerEntity: number, Item: any): WalkingSquishyState?
    if type(Item) ~= "table" then
        return nil
    end

    local ItemId = Item.Id
    local Kind = Item.Kind
    local Name = Item.Name

    if type(ItemId) ~= "string" or ItemId == "" then
        return nil
    end

    if type(Kind) ~= "string" or Kind == "" then
        return nil
    end

    if type(Name) ~= "string" or Name == "" then
        return nil
    end

    local BaseIncomePerSec = if type(Item.BaseIncomePerSec) == "number" and Item.BaseIncomePerSec > 0
        then Item.BaseIncomePerSec
        else Get_Config_Base_Income(Kind, Name)
    local IncomeItem = table.clone(Item)
    IncomeItem.BaseIncomePerSec = BaseIncomePerSec
    IncomeItem.Kind = Kind
    IncomeItem.Mutation = InventoryMath.NormalizeMutation(Item.Mutation, Kind)
    IncomeItem.EventMutations = InventoryMath.NormalizeEventMutations(Item.EventMutations)

    return {
        ItemId = ItemId,
        Kind = Kind,
        Name = Name,
        Rarity = if type(Item.Rarity) == "string" then Item.Rarity else "Common",
        Weight = if type(Item.Weight) == "number" then Item.Weight else 0,
        Mutation = IncomeItem.Mutation,
        EventMutations = IncomeItem.EventMutations,
        Level = SquishyLevels.NormalizeLevel(Item.Level),
        BaseIncomePerSec = BaseIncomePerSec,
        FinalIncomePerSec = InventoryMath.GetFinalIncomePerSec(IncomeItem),
        LassoName = Get_Selected_Lasso_Name(PlayerEntity),
    }
end

local function Fire_State(TargetPlayer: Player?, SourcePlayer: Player, State: WalkingSquishyState?)
    local Payload = {
        PlayerUserId = SourcePlayer.UserId,
        Equipped = State ~= nil,
        ItemId = if State then State.ItemId else "",
        Kind = if State then State.Kind else "",
        Name = if State then State.Name else "",
        Rarity = if State then State.Rarity else "",
        Weight = if State then State.Weight else 0,
        Mutation = if State then State.Mutation else "",
        EventMutations = if State then State.EventMutations else {},
        Level = if State then State.Level else 0,
        BaseIncomePerSec = if State then State.BaseIncomePerSec else 0,
        FinalIncomePerSec = if State then State.FinalIncomePerSec else 0,
        LassoName = if State then State.LassoName else Lassos.Default,
    }

    if TargetPlayer then
        Network.WalkingSquishyChanged.Fire(TargetPlayer, Payload)
    else
        Network.WalkingSquishyChanged.FireAll(Payload)
    end
end

local function String_Arrays_Are_Equal(Left: { string }?, Right: { string }?): boolean
    if Left == Right then
        return true
    end

    if type(Left) ~= "table" or type(Right) ~= "table" or #Left ~= #Right then
        return false
    end

    for Index, Value in Left do
        if Right[Index] ~= Value then
            return false
        end
    end

    return true
end

local function Clear_Player_State(Player: Player)
    if not PlayerStates[Player] then
        return
    end

    PlayerStates[Player] = nil
    Fire_State(nil, Player, nil)
end

local function Set_Player_State(Player: Player, ItemId: string, Equipped: boolean)
    if not Equipped then
        Clear_Player_State(Player)
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        Clear_Player_State(Player)
        return
    end

    local Item = Find_Owned_Squishy(PlayerEntity, ItemId)
    local State = Build_State(PlayerEntity, Item)

    if not State then
        Clear_Player_State(Player)
        return
    end

    PlayerStates[Player] = State
    Fire_State(nil, Player, State)
end

local function Send_Current_States_To(Player: Player)
    if not Player.Parent then
        return
    end

    for SourcePlayer, State in PlayerStates do
        if SourcePlayer.Parent then
            Fire_State(Player, SourcePlayer, State)
        end
    end
end

local function Reconcile_Player(Player: Player)
    local State = PlayerStates[Player]

    if not State then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)
    local Item = if PlayerEntity then Find_Owned_Squishy(PlayerEntity, State.ItemId) else nil

    if not PlayerEntity or not Item then
        Clear_Player_State(Player)
        return
    end

    local UpdatedState = Build_State(PlayerEntity, Item)

    if not UpdatedState then
        Clear_Player_State(Player)
        return
    end

    if
        State.LassoName ~= UpdatedState.LassoName
        or State.FinalIncomePerSec ~= UpdatedState.FinalIncomePerSec
        or not String_Arrays_Are_Equal(State.EventMutations, UpdatedState.EventMutations)
    then
        PlayerStates[Player] = UpdatedState
        Fire_State(nil, Player, UpdatedState)
    end
end

local function Bind_Player(Player: Player)
    if BoundPlayers[Player] then
        return
    end

    BoundPlayers[Player] = true

    Player.CharacterAdded:Connect(function()
        local State = PlayerStates[Player]

        if not State then
            return
        end

        task.delay(0.2, function()
            if Player.Parent and PlayerStates[Player] == State then
                Fire_State(nil, Player, State)
            end
        end)
    end)
end

local function Cleanup_Player(Player: Player)
    Clear_Player_State(Player)
    PlayerStates[Player] = nil
    BoundPlayers[Player] = nil
end

local function Apply_Event_Mutation_Rolls_To_Equipped()
    local Now = workspace:GetServerTimeNow()

    if Now - LastEventMutationRollTick < EVENT_MUTATION_ROLL_TICK_SECONDS then
        return
    end

    LastEventMutationRollTick = Now

    local ActiveEvents = EventService.GetActiveEvents()

    if next(ActiveEvents) == nil then
        return
    end

    for Player, State in PlayerStates do
        if not Player.Parent then
            continue
        end

        local PlayerEntity = Get_Player_Entity(Player)

        if not PlayerEntity then
            continue
        end

        local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))
        local Item = Find_Owned_Squishy_In_Array(OwnedSquishies, State.ItemId)

        if not Item then
            continue
        end

        if Apply_Event_Mutation_Rolls_To_Item(Item, ActiveEvents, Now) then
            World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
        end
    end
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
        for _, Player in Network.WalkingSquishySyncRequest.Iter() do
            if not RemoteCooldowns.Allow(Player, "WalkingSquishySyncRequest") then
                continue
            end

            Send_Current_States_To(Player)
        end

        for _, Player, Data in Network.WalkingSquishyRequest.Iter() do
            if not RemoteCooldowns.Allow(Player, "WalkingSquishyRequest") then
                continue
            end

            Set_Player_State(Player, Data.ItemId, Data.Equipped)
        end

        Apply_Event_Mutation_Rolls_To_Equipped()

        for _, Player in Players:GetPlayers() do
            Reconcile_Player(Player)
        end
    end,
    runConditions = {},
}
