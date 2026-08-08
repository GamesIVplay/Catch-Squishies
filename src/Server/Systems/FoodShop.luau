local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local TutorialProgress = require(ServerScriptService.Server.Modules.TutorialProgress)

local Components = require(ReplicatedStorage.Shared.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local FoodStock = require(ReplicatedStorage.Shared.Modules.FoodStock)
local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local SkipTimeRewards = require(ServerScriptService.Server.Modules.SkipTimeRewards)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local Util = require(ReplicatedStorage.Shared.Modules.Util)
local World = require(ReplicatedStorage.Shared.World)

local RESTOCK_TIME = Config.FoodRestockTime or (60 * 5)
local RESTOCK_CHECK_INTERVAL = 1
local MAX_FOOD_AMOUNT = 65_535
local CUSTOM_SLOT_MIN = 3
local CUSTOM_SLOT_MAX = 7

local FoodRestockQuery = World:query(Components.Player, Components.LastFoodRestock, Components.FoodStock):cached()
local LastRestockCheck = 0
local LastRestockEndSentByUserId: { [number]: number } = {}

local function Notify(Player: Player, Text: string, Type: string, Duration: number?)
    Network.Notification.Fire(Player, {
        Text = Text,
        Type = Type :: any,
        Duration = Duration,
    })
end

local function Get_Restock_End_Time(LastRestock: any): number
    if type(LastRestock) ~= "number" or LastRestock <= 0 or LastRestock ~= LastRestock then
        return 0
    end

    return math.max(0, math.floor(LastRestock + RESTOCK_TIME))
end

local function Send_Restock_End_Time(Player: Player, LastRestock: any)
    local EndTime = Get_Restock_End_Time(LastRestock)

    if EndTime <= 0 then
        return
    end

    if LastRestockEndSentByUserId[Player.UserId] == EndTime then
        return
    end

    LastRestockEndSentByUserId[Player.UserId] = EndTime
    Network.FoodRestockEndTimeChanged.Fire(Player, EndTime)
end

local function Get_Player_Entity(Player: Player): number?
    local Entity = Registry.Get("Players", Player)

    if not Entity or not World:contains(Entity) then
        return nil
    end

    return Entity
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

local function Find_Food_Entry(OwnedFood: { any }, FoodName: string): any?
    for _, Entry in OwnedFood do
        if type(Entry) == "table" and Entry.Id == FoodName then
            return Entry
        end
    end

    return nil
end

local function Is_Custom_Slot(Slot: any): boolean
    return type(Slot) == "number" and Slot >= CUSTOM_SLOT_MIN and Slot <= CUSTOM_SLOT_MAX and math.floor(Slot) == Slot
end

local function Copy_Hotbar(Value): { [string]: any }
    local Result = {}

    if type(Value) ~= "table" then
        return Result
    end

    for Key, Entry in Value do
        if type(Entry) ~= "table" then
            continue
        end

        local Slot = if Is_Custom_Slot(Entry.Slot) then Entry.Slot else tonumber(Key)

        if Is_Custom_Slot(Slot) and type(Entry.ItemId) == "string" and type(Entry.ItemType) == "string" then
            Result[tostring(Slot)] = {
                Slot = Slot,
                ItemId = Entry.ItemId,
                ItemType = Entry.ItemType,
            }
        end
    end

    return Result
end

local function Find_Assigned_Food_Slot(HotbarSlots: { [string]: any }, FoodName: string): number?
    for _, Assignment in HotbarSlots do
        if type(Assignment) ~= "table" then
            continue
        end

        if Assignment.ItemType == "Food" and Assignment.ItemId == FoodName and Is_Custom_Slot(Assignment.Slot) then
            return Assignment.Slot
        end
    end

    return nil
end

local function Find_Open_Hotbar_Slot(HotbarSlots: { [string]: any }): number?
    local Occupied = {}

    for _, Assignment in HotbarSlots do
        if type(Assignment) == "table" and Is_Custom_Slot(Assignment.Slot) then
            Occupied[Assignment.Slot] = true
        end
    end

    for Slot = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
        if not Occupied[Slot] then
            return Slot
        end
    end

    return nil
end

local function Is_Hotbar_Slot_Open(HotbarSlots: { [string]: any }, Slot: number): boolean
    for _, Assignment in HotbarSlots do
        if type(Assignment) == "table" and Assignment.Slot == Slot then
            return false
        end
    end

    return true
end

local function Ensure_Food_Hotbar_Assignment(PlayerEntity: number, OwnedFood: { any }, FoodData: Foods.FoodData)
    local Entry = Find_Food_Entry(OwnedFood, FoodData.Name)

    if not Entry then
        return
    end

    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))
    local AssignedSlot = Find_Assigned_Food_Slot(HotbarSlots, FoodData.Name)
    local PreferredSlot = if Is_Custom_Slot(Entry.HotbarSlot)
            and Is_Hotbar_Slot_Open(HotbarSlots, Entry.HotbarSlot)
        then Entry.HotbarSlot
        else nil
    local Slot = AssignedSlot or PreferredSlot or Find_Open_Hotbar_Slot(HotbarSlots)

    if not Slot then
        return
    end

    if AssignedSlot then
        Entry.HotbarSlot = AssignedSlot
        return
    end

    HotbarSlots[tostring(Slot)] = {
        Slot = Slot,
        ItemId = FoodData.Name,
        ItemType = "Food",
    }
    Entry.HotbarSlot = Slot

    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
end

local function Add_Food_To_Inventory(PlayerEntity: number, FoodData: Foods.FoodData)
    local OwnedFood = Copy_Array(World:get(PlayerEntity, Components.OwnedFood))
    local Entry = Find_Food_Entry(OwnedFood, FoodData.Name)

    if Entry then
        local Amount = if type(Entry.Amount) == "number" then Entry.Amount else 0

        Entry.Amount = math.clamp(math.floor(Amount) + 1, 0, MAX_FOOD_AMOUNT)
        Entry.Rarity = FoodData.Rarity
        Entry.Image = FoodData.Image
        Entry.XPValue = FoodData.XPValue
    else
        table.insert(OwnedFood, {
            Id = FoodData.Name,
            Type = "Food",
            Name = FoodData.Name,
            Rarity = FoodData.Rarity,
            Image = FoodData.Image,
            Amount = 1,
            XPValue = FoodData.XPValue,
            Favorite = false,
        })
    end

    Ensure_Food_Hotbar_Assignment(PlayerEntity, OwnedFood, FoodData)
    World:set(PlayerEntity, Components.OwnedFood, OwnedFood)
end

local function Set_New_Stock(PlayerEntity: number, Player: Player, ShouldNotify: boolean)
    local LastRestock = os.time()

    World:set(PlayerEntity, Components.FoodStock, FoodStock.Roll_All())
    World:set(PlayerEntity, Components.LastFoodRestock, LastRestock)
    Send_Restock_End_Time(Player, LastRestock)

    if ShouldNotify then
        Notify(Player, "The Food Shop has been restocked!", "Info", 6)
    end
end

local function Normalize_Player_Stock(PlayerEntity: number): { [string]: number }
    local Stock, Changed = FoodStock.Normalize(World:get(PlayerEntity, Components.FoodStock))

    if Changed then
        World:set(PlayerEntity, Components.FoodStock, Stock)
    end

    return Stock
end

local function Ensure_Player_Stock(PlayerEntity: number, Player: Player): { [string]: number }
    local Stock = World:get(PlayerEntity, Components.FoodStock)
    local LastRestock = World:get(PlayerEntity, Components.LastFoodRestock)

    if type(LastRestock) ~= "number" or LastRestock <= 0 or not FoodStock.Has_Stock_Data(Stock) then
        Set_New_Stock(PlayerEntity, Player, false)
    elseif os.time() - LastRestock >= RESTOCK_TIME then
        Set_New_Stock(PlayerEntity, Player, true)
    else
        Send_Restock_End_Time(Player, LastRestock)
    end

    return Normalize_Player_Stock(PlayerEntity)
end

local function Handle_Buy_Food(Player: Player, FoodName: string)
    local FoodData = Foods.Get(FoodName)

    if not FoodData then
        Notify(Player, "Unknown food.", "Error")
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    local TutorialStep = TutorialProgress.Get(PlayerEntity)
    local IsTutorialBuy = TutorialStep == TutorialSteps.FeedStrong and FoodData.Name == TutorialSteps.FeedName

    if not TutorialProgress.Is_Complete(PlayerEntity) and not IsTutorialBuy then
        Notify(Player, TutorialSteps.BlockedMessage, "Error")
        return
    end

    local Stock = Ensure_Player_Stock(PlayerEntity, Player)
    local CurrentStock = if IsTutorialBuy
        then math.max(1, FoodStock.Get_Stock(Stock, FoodData.Name))
        else FoodStock.Get_Stock(Stock, FoodData.Name)

    if CurrentStock <= 0 then
        Notify(Player, "That food is out of stock.", "Error")
        return
    end

    local Cash = World:get(PlayerEntity, Components.Cash) or 0
    local Price = if IsTutorialBuy then 0 else FoodData.Price

    if Cash < Price then
        SkipTimeRewards.PromptShortfall(Player, PlayerEntity, Cash, Price)
        Notify(Player, "Not enough cash.", "Error")
        return
    end

    Stock[FoodData.Name] = math.max(0, CurrentStock - 1)

    if Price > 0 then
        World:set(PlayerEntity, Components.Cash, Cash - Price)
    end

    World:set(PlayerEntity, Components.FoodStock, Stock)
    Add_Food_To_Inventory(PlayerEntity, FoodData)
    TutorialProgress.Complete_Step(PlayerEntity, TutorialSteps.BuyFood, TutorialSteps.FeedStrong)

    local PriceText = if Price <= 0 then "FREE" else `$${Util.Abbreviate_Number(Price, 1)}`

    Notify(Player, `Bought {FoodData.DisplayName} for {PriceText}.`, "Success", 4)
    Network.CollectEffect.FireAll({
        PlayerUserId = Player.UserId,
        ItemId = "",
    })
end

local function Process_Buy_Remotes()
    for _, Player, FoodName in Network.BuyFood.Iter() do
        if not RemoteCooldowns.Allow(Player, "BuyFood") then
            continue
        end

        Handle_Buy_Food(Player, FoodName)
    end
end

local function Process_Restocks()
    local NowClock = os.clock()

    if NowClock - LastRestockCheck < RESTOCK_CHECK_INTERVAL then
        return
    end

    LastRestockCheck = NowClock

    local Now = os.time()

    for PlayerEntity: number, Player: Player, LastRestock: number, Stock in FoodRestockQuery:iter() do
        if type(LastRestock) ~= "number" or LastRestock <= 0 or not FoodStock.Has_Stock_Data(Stock) then
            Set_New_Stock(PlayerEntity, Player, false)
            continue
        end

        if Now - LastRestock >= RESTOCK_TIME then
            Set_New_Stock(PlayerEntity, Player, true)
            continue
        end

        Send_Restock_End_Time(Player, LastRestock)

        local NormalizedStock, Changed = FoodStock.Normalize(Stock)

        if Changed then
            World:set(PlayerEntity, Components.FoodStock, NormalizedStock)
        end
    end
end

Players.PlayerRemoving:Connect(function(Player)
    LastRestockEndSentByUserId[Player.UserId] = nil
end)

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = function()
        Process_Buy_Remotes()
        Process_Restocks()
    end,
    runConditions = {},
}
