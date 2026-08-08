local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)

local Jecs = require(ReplicatedStorage.Packages.Jecs)
local Pair = Jecs.pair

local Components = require(ReplicatedStorage.Shared.Components)
local EventMutations = require(ReplicatedStorage.Shared.Modules.EventMutations)
local Events = require(ReplicatedStorage.Shared.Modules.Events)
local FoodStock = require(ReplicatedStorage.Shared.Modules.FoodStock)
local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Phases = require(ReplicatedStorage.Shared.Phases)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local SquishyLevels = require(ReplicatedStorage.Shared.Modules.SquishyLevels)
local World = require(ReplicatedStorage.Shared.World)

local PlayerEntities = World:query(Components.Player):cached()
local U32_MAX = 4_294_967_295

local function Normalize_Number(Value): number
    if type(Value) ~= "number" or Value ~= Value then
        return 0
    end

    return Value
end

local function Normalize_U32(Value): number
    Value = Normalize_Number(Value)

    return math.clamp(math.floor(Value), 0, U32_MAX)
end

local function Normalize_Money_Multiplier(Value): number
    return RobuxProducts.NormalizeMoneyMultiplier(Value)
end

local function Normalize_String(Value): string
    if type(Value) ~= "string" then
        return ""
    end

    return Value
end

local function Normalize_String_Array(Value): { string }
    local Result = {}
    local Seen = {}

    if type(Value) ~= "table" then
        return Result
    end

    for _, Entry in Value do
        if type(Entry) == "string" and Entry ~= "" and not Seen[Entry] then
            Seen[Entry] = true
            table.insert(Result, Entry)
        end
    end

    table.sort(Result)

    return Result
end

local function Normalize_U8_Array(Value): { number }
    local Result = {}
    local Seen = {}

    if type(Value) ~= "table" then
        return Result
    end

    for _, Entry in Value do
        local Number = tonumber(Entry)

        if Number and Number >= 0 and Number <= 255 and math.floor(Number) == Number and not Seen[Number] then
            Seen[Number] = true
            table.insert(Result, Number)
        end
    end

    table.sort(Result)

    return Result
end

local function Normalize_Event_List(Value): { string }
    return EventMutations.NormalizeList(Value)
end

local function Copy_Table(Value)
    if type(Value) ~= "table" then
        return Value
    end

    local Result = {}

    for Key, Entry in Value do
        Result[Key] = Copy_Table(Entry)
    end

    return Result
end

local function Normalize_Boolean(Value): boolean
    return Value == true
end

local function Normalize_Optional_Slot(Value): number?
    if type(Value) ~= "number" or Value ~= Value then
        return nil
    end

    local Slot = math.floor(Value)

    if Slot < 3 or Slot > 7 then
        return nil
    end

    return Slot
end

local function Normalize_Squishy_Array(Value): { any }
    local Result = {}

    if type(Value) ~= "table" then
        return Result
    end

    for _, Entry in Value do
        if type(Entry) ~= "table" then
            continue
        end

        local Kind = Normalize_String(Entry.Kind)
        local Name = Normalize_String(Entry.Name)
        local SquishyData = Squishies.GetData(Kind :: any, Name)
        local BaseIncomePerSec = Normalize_U32(Entry.BaseIncomePerSec)

        if BaseIncomePerSec <= 0 and SquishyData then
            BaseIncomePerSec = Normalize_U32(SquishyData.IncomePerSec)
        end

        local Rarity = Entry.Rarity
        local Image = Entry.Image

        if type(Rarity) ~= "string" and SquishyData then
            Rarity = SquishyData.Rarity
        end

        if type(Image) ~= "string" and SquishyData then
            Image = SquishyData.Image
        end

        local Level = SquishyLevels.NormalizeLevel(Entry.Level)
        local NormalizedEntry = {
            Id = Normalize_String(Entry.Id),
            Type = "Squishy",
            Kind = Kind,
            Name = Name,
            Rarity = InventoryMath.NormalizeRarity(Rarity),
            Image = Normalize_String(Image),
            BaseIncomePerSec = BaseIncomePerSec,
            FinalIncomePerSec = 0,
            Weight = Normalize_Number(Entry.Weight),
            Mutation = InventoryMath.NormalizeMutation(Entry.Mutation, Kind),
            EventMutations = Normalize_Event_List(Entry.EventMutations),
            Level = Level,
            XP = if Level >= SquishyLevels.MaxLevel then 0 else SquishyLevels.NormalizeXp(Entry.XP),
            Equipped = Normalize_Boolean(Entry.Equipped),
            Favorite = Normalize_Boolean(Entry.Favorite),
            HotbarSlot = Normalize_Optional_Slot(Entry.HotbarSlot),
        }

        NormalizedEntry.FinalIncomePerSec = Normalize_U32(InventoryMath.GetFinalIncomePerSec(NormalizedEntry))

        if NormalizedEntry.Id ~= "" and NormalizedEntry.Name ~= "" and SquishyData then
            table.insert(Result, NormalizedEntry)
        end
    end

    return Result
end

local function Normalize_Event_State(Value): any
    local Result = {
        NextEventAt = 0,
        ActiveEvents = {},
    }

    if type(Value) ~= "table" then
        return Result
    end

    Result.NextEventAt = Normalize_Number(Value.NextEventAt)

    local ActiveEvents = Value.ActiveEvents

    if type(ActiveEvents) == "table" then
        for Key, Entry in ActiveEvents do
            if type(Entry) ~= "table" then
                continue
            end

            local EventName = Events.Normalize(Entry.Name or Key)

            if not EventName then
                continue
            end

            table.insert(Result.ActiveEvents, {
                Name = EventName,
                StartedAt = Normalize_Number(Entry.StartedAt),
                EndsAt = Normalize_Number(Entry.EndsAt),
                Source = Normalize_String(Entry.Source),
            })
        end
    end

    table.sort(Result.ActiveEvents, function(Left, Right)
        if Left.EndsAt ~= Right.EndsAt then
            return Left.EndsAt < Right.EndsAt
        end

        return Left.Name < Right.Name
    end)

    return Result
end

local function Normalize_Food_Array(Value): { any }
    local Result = {}

    if type(Value) ~= "table" then
        return Result
    end

    for _, Entry in Value do
        if type(Entry) ~= "table" then
            continue
        end

        local FoodData = Foods.Get(Entry.Name or Entry.Id)

        if not FoodData then
            continue
        end

        local Amount = math.clamp(Normalize_U32(Entry.Amount), 0, 65_535)

        if Amount <= 0 then
            continue
        end

        table.insert(Result, {
            Id = FoodData.Name,
            Type = "Food",
            Name = FoodData.Name,
            Rarity = FoodData.Rarity,
            Image = FoodData.Image,
            Amount = Amount,
            XPValue = Normalize_U32(FoodData.XPValue),
            Favorite = Normalize_Boolean(Entry.Favorite),
            HotbarSlot = Normalize_Optional_Slot(Entry.HotbarSlot),
        })
    end

    return Result
end

local function Normalize_Food_Stock(Value): { [string]: number }
    local NormalizedStock = FoodStock.Normalize(Value)

    for FoodName, Stock in NormalizedStock do
        NormalizedStock[FoodName] = math.clamp(Normalize_U32(Stock), 0, 65_535)
    end

    return NormalizedStock
end

local function Normalize_Hotbar_Slots(Value): { any }
    local Result = {}

    if type(Value) ~= "table" then
        return Result
    end

    for _, Entry in Value do
        if type(Entry) ~= "table" then
            continue
        end

        local Slot = Normalize_Optional_Slot(Entry.Slot)
        local ItemId = Normalize_String(Entry.ItemId)
        local ItemType = Normalize_String(Entry.ItemType)

        if Slot and ItemId ~= "" and (ItemType == "Squishy" or ItemType == "Food") then
            table.insert(Result, {
                Slot = Slot,
                ItemId = ItemId,
                ItemType = ItemType,
            })
        end
    end

    table.sort(Result, function(Left, Right)
        return Left.Slot < Right.Slot
    end)

    return Result
end

local function Values_Are_Equal(Left, Right): boolean
    if Left == Right then
        return true
    end

    if type(Left) ~= "table" or type(Right) ~= "table" then
        return false
    end

    local LeftCount = 0
    local RightCount = 0

    for Key, Value in Left do
        LeftCount += 1

        if not Values_Are_Equal(Value, Right[Key]) then
            return false
        end
    end

    for _ in Right do
        RightCount += 1
    end

    if LeftCount ~= RightCount then
        return false
    end

    return true
end

local function Get_Previous_Component(Component)
    return Pair(Components.Relationships.Previous, Component)
end

local function Replicate_Component(Player: Player, Entity: Jecs.Entity, Component, Remote, Normalize)
    local Value = Normalize(World:get(Entity, Component))
    local PreviousComponent = Get_Previous_Component(Component)

    if Values_Are_Equal(Value, World:get(Entity, PreviousComponent)) then
        return
    end

    Remote.Fire(Player, Value)
    World:set(Entity, PreviousComponent, Copy_Table(Value))
end

local Replicators = {
    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(Player, Entity, Components.Cash, Network.CashChanged, Normalize_U32)
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(
            Player,
            Entity,
            Components.MoneyMultiplier,
            Network.MoneyMultiplierChanged,
            Normalize_Money_Multiplier
        )
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(Player, Entity, Components.FriendBoost, Network.FriendBoostChanged, Normalize_U32)
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(Player, Entity, Components.Lasso, Network.LassoChanged, Normalize_String)
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(Player, Entity, Components.OwnedLassos, Network.OwnedLassosChanged, Normalize_String_Array)
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(
            Player,
            Entity,
            Components.OwnedSquishies,
            Network.OwnedSquishiesChanged,
            Normalize_Squishy_Array
        )
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(Player, Entity, Components.OwnedFood, Network.OwnedFoodChanged, Normalize_Food_Array)
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(Player, Entity, Components.FoodStock, Network.FoodStockChanged, Normalize_Food_Stock)
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(Player, Entity, Components.LastFoodRestock, Network.LastFoodRestockChanged, Normalize_U32)
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(Player, Entity, Components.HotbarSlots, Network.HotbarSlotsChanged, Normalize_Hotbar_Slots)
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(Player, Entity, Components.Index, Network.IndexChanged, Normalize_String_Array)
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(
            Player,
            Entity,
            Components.ClaimedIndexRewards,
            Network.ClaimedIndexRewardsChanged,
            Normalize_String_Array
        )
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(
            Player,
            Entity,
            Components.LastDailyRewardClaim,
            Network.DailyStartChanged,
            Normalize_Number
        )
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(
            Player,
            Entity,
            Components.ClaimedDailyRewards,
            Network.ClaimedDailyRewardsChanged,
            Normalize_U8_Array
        )
    end,

    function(Player: Player, Entity: Jecs.Entity)
        Replicate_Component(Player, Entity, Components.TutorialStep, Network.TutorialStepChanged, Normalize_U32)
    end,

    function(Player: Player, _Entity: Jecs.Entity)
        Replicate_Component(
            Player,
            Components.Singletons.EventState,
            Components.Singletons.EventState,
            Network.EventStateChanged,
            Normalize_Event_State
        )
    end,
}

return {
    name = script.Name,
    phase = Phases.Runservice.Last,
    system = function()
        for Entity, Player in PlayerEntities:iter() do
            for _, Replicate in Replicators do
                Replicate(Player, Entity)
            end
        end
    end,
    runConditions = {},
}
