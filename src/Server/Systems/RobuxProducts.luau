local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)

local CatchConfig = require(ReplicatedStorage.Shared.Modules.CatchConfig)
local Components = require(ReplicatedStorage.Shared.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local FoodStock = require(ReplicatedStorage.Shared.Modules.FoodStock)
local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local InventoryCapacity = require(ReplicatedStorage.Shared.Modules.InventoryCapacity)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local Log = require(ReplicatedStorage.Shared.Log)
local Mutations = require(ReplicatedStorage.Shared.Modules.Mutations)
local Phases = require(ReplicatedStorage.Shared.Phases)
local ProgressionFunnels = require(ServerScriptService.Server.Modules.ProgressionFunnels)
local Registry = require(ReplicatedStorage.Shared.Registry)
local RobuxGifts = require(ServerScriptService.Server.Modules.RobuxGifts)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local SkipTimeRewards = require(ServerScriptService.Server.Modules.SkipTimeRewards)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local Util = require(ReplicatedStorage.Shared.Modules.Util)
local World = require(ReplicatedStorage.Shared.World)

local DailyRewardsSystem = require(ServerScriptService.Server.Systems.Daily_Rewards)
local OfflineRewardsSystem = require(ServerScriptService.Server.Systems.Offline_Rewards)
local CUSTOM_HOTBAR_SLOTS = table.freeze({ 3, 4, 5, 6, 7 })
local MAX_FOOD_AMOUNT = 65_535
local RESTOCK_TIME = Config.FoodRestockTime or (60 * 5)
local RNG = Random.new()
local ReceiptHandlerInstalled = false
local ProcessedPurchaseIds: { [string]: boolean } = {}
local GamepassOwnershipChecks: { [Player]: boolean } = {}

local function Notify(Player: Player, Text: string, Type: string)
    Network.Notification.Fire(Player, {
        Text = Text,
        Type = Type :: any,
    })
end

local function Get_Player_Entity(Player: Player): number?
    local Entity = Registry.Get("Players", Player)

    if not Entity or not World:contains(Entity) then
        return nil
    end

    return Entity
end

local function Grant_Cash(Player: Player, PlayerEntity: number, Amount: number)
    local Cash = World:get(PlayerEntity, Components.Cash) or 0

    World:set(PlayerEntity, Components.Cash, Cash + math.floor(Amount))
    Notify(Player, `Purchased ${Util.Abbreviate_Number(Amount, 1)}.`, "Success")
end

local function Normalize_Number(Value: any, Fallback: number?): number
    if type(Value) ~= "number" or Value ~= Value then
        return Fallback or 0
    end

    return Value
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

local function Snapshot_Plot_Cash(PlayerEntity: number, MoneyMultiplier: number)
    local PlotSquishies = World:get(PlayerEntity, Components.PlotSquishies)

    if type(PlotSquishies) ~= "table" then
        return
    end

    local Now = workspace:GetServerTimeNow()
    local UpdatedPlotSquishies = Copy_Array(PlotSquishies)
    local DidChange = false

    for _, Item in UpdatedPlotSquishies do
        if type(Item) ~= "table" then
            continue
        end

        local LastCashUpdate = Normalize_Number(Item.LastCashUpdate, Now)
        local Delta = math.max(0, Now - LastCashUpdate)

        if Delta <= 0 then
            continue
        end

        local StoredCash = math.max(0, Normalize_Number(Item.StoredCash, 0))
        local IncomePerSec = InventoryMath.GetFinalIncomePerSec(Item) * MoneyMultiplier

        Item.StoredCash = StoredCash + IncomePerSec * Delta
        Item.LastCashUpdate = Now
        DidChange = true
    end

    if DidChange then
        World:set(PlayerEntity, Components.PlotSquishies, UpdatedPlotSquishies)
    end
end

local function Copy_Hotbar_And_Get_Occupied(PlayerEntity: number): ({ [string]: any }, { [number]: boolean })
    local HotbarSlots = {}
    local OccupiedSlots = {}
    local ExistingHotbarSlots = World:get(PlayerEntity, Components.HotbarSlots)

    if type(ExistingHotbarSlots) ~= "table" then
        return HotbarSlots, OccupiedSlots
    end

    for Key, Assignment in ExistingHotbarSlots do
        if type(Assignment) ~= "table" then
            continue
        end

        local Slot = if type(Assignment.Slot) == "number" then Assignment.Slot else tonumber(Key)

        if
            type(Slot) == "number"
            and Slot >= 3
            and Slot <= 7
            and math.floor(Slot) == Slot
            and type(Assignment.ItemId) == "string"
            and type(Assignment.ItemType) == "string"
        then
            HotbarSlots[tostring(Slot)] = {
                Slot = Slot,
                ItemId = Assignment.ItemId,
                ItemType = Assignment.ItemType,
            }

            if Slot >= 3 then
                OccupiedSlots[Slot] = true
            end
        end
    end

    return HotbarSlots, OccupiedSlots
end

local function Get_First_Open_Custom_Hotbar_Slot(OccupiedSlots: { [number]: boolean }): number?
    for _, Slot in CUSTOM_HOTBAR_SLOTS do
        if not OccupiedSlots[Slot] then
            OccupiedSlots[Slot] = true
            return Slot
        end
    end

    return nil
end

local function Find_Food_Entry(OwnedFood: { any }, FoodName: string): any?
    for _, Entry in OwnedFood do
        if type(Entry) ~= "table" or Entry.Type ~= "Food" then
            continue
        end

        local EntryFood = Foods.Get(Entry.Id or Entry.Name)

        if Entry.Id == FoodName or (EntryFood and EntryFood.Name == FoodName) then
            return Entry
        end
    end

    return nil
end

local function Find_Assigned_Food_Slot(HotbarSlots: { [string]: any }, FoodName: string): number?
    for _, Assignment in HotbarSlots do
        local AssignmentFood = if type(Assignment) == "table" then Foods.Get(Assignment.ItemId) else nil

        if
            type(Assignment) == "table"
            and Assignment.ItemType == "Food"
            and (Assignment.ItemId == FoodName or (AssignmentFood and AssignmentFood.Name == FoodName))
            and type(Assignment.Slot) == "number"
            and Assignment.Slot >= 3
        then
            return Assignment.Slot
        end
    end

    return nil
end

local function Add_Index_Keys(PlayerEntity: number, IndexKeys: { string })
    local CurrentIndex = World:get(PlayerEntity, Components.Index)
    local NewIndex = {}
    local Seen = {}
    local Added = false

    if type(CurrentIndex) == "table" then
        for _, Key in CurrentIndex do
            if type(Key) == "string" and Key ~= "" and not Seen[Key] then
                Seen[Key] = true
                table.insert(NewIndex, Key)
            end
        end
    end

    for _, IndexKey in IndexKeys do
        if type(IndexKey) ~= "string" or Seen[IndexKey] or not Squishies.GetDataFromKey(IndexKey) then
            continue
        end

        Seen[IndexKey] = true
        Added = true
        table.insert(NewIndex, IndexKey)
    end

    if Added then
        table.sort(NewIndex)
        World:set(PlayerEntity, Components.Index, NewIndex)
    end
end

local function Build_Squishy_Item(Kind: string, SquishyName: string, SquishyData: any, HotbarSlot: number?): any
    local NewItem = {
        Id = HttpService:GenerateGUID(false),
        Type = "Squishy",
        Kind = Kind,
        Name = SquishyName,
        Rarity = SquishyData.Rarity,
        Image = SquishyData.Image,
        BaseIncomePerSec = SquishyData.IncomePerSec,
        FinalIncomePerSec = 0,
        Weight = CatchConfig.MinWeight,
        IncomePerSec = 0,
        Mutation = Mutations.Roll(Kind),
        EventMutations = {},
        Level = 0,
        XP = 0,
        Equipped = false,
        Favorite = false,
        HotbarSlot = HotbarSlot,
        CaughtAt = os.time(),
    }

    NewItem.FinalIncomePerSec = InventoryMath.GetFinalIncomePerSec(NewItem)
    NewItem.IncomePerSec = NewItem.FinalIncomePerSec

    return NewItem
end

local function Grant_Squishy_Pack(
    Player: Player,
    PlayerEntity: number,
    DisplayName: string,
    SquishyGrants: { RobuxProducts.SquishyGrantConfig }
): boolean
    local ValidatedGrants = {}

    for _, Grant in SquishyGrants do
        local SquishyData = Squishies.GetData(Grant.Kind, Grant.Name)

        if not SquishyData then
            Log.Warn(`[RobuxProducts] Unknown squishy grant: {Grant.Kind}:{Grant.Name}`)
            return false
        end

        table.insert(ValidatedGrants, {
            Kind = Grant.Kind,
            Name = Grant.Name,
            Data = SquishyData,
            Key = Squishies.GetKey(Grant.Kind, Grant.Name),
        })
    end

    local HotbarSlots, OccupiedSlots = Copy_Hotbar_And_Get_Occupied(PlayerEntity)
    local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))
    local IndexKeys = {}

    if not InventoryCapacity.CanAddSquishies(OwnedSquishies, #ValidatedGrants) then
        Notify(Player, InventoryCapacity.SquishyInventoryFullMessage, "Error")
        return false
    end

    for _, Grant in ValidatedGrants do
        local HotbarSlot = Get_First_Open_Custom_Hotbar_Slot(OccupiedSlots)
        local NewItem = Build_Squishy_Item(Grant.Kind, Grant.Name, Grant.Data, HotbarSlot)

        table.insert(OwnedSquishies, NewItem)
        table.insert(IndexKeys, Grant.Key)

        if HotbarSlot then
            HotbarSlots[tostring(HotbarSlot)] = {
                Slot = HotbarSlot,
                ItemId = NewItem.Id,
                ItemType = "Squishy",
            }
        end
    end

    World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    Add_Index_Keys(PlayerEntity, IndexKeys)
    Notify(Player, `Purchased {DisplayName}.`, "Success")

    return true
end

local function Roll_Lucky_Block_Reward(Rewards: { RobuxProducts.LuckyBlockRewardConfig })
    local TotalWeight = 0

    for _, Reward in Rewards do
        if type(Reward.Weight) == "number" and Reward.Weight > 0 then
            TotalWeight += Reward.Weight
        end
    end

    if TotalWeight <= 0 then
        return nil
    end

    local Roll = RNG:NextNumber(0, TotalWeight)
    local Cursor = 0

    for _, Reward in Rewards do
        if type(Reward.Weight) ~= "number" or Reward.Weight <= 0 then
            continue
        end

        Cursor += Reward.Weight

        if Roll <= Cursor then
            return Reward
        end
    end

    return Rewards[#Rewards]
end

local function Grant_Lucky_Block(
    Player: Player,
    PlayerEntity: number,
    DisplayName: string,
    RollCount: number,
    Rewards: { RobuxProducts.LuckyBlockRewardConfig }
): boolean
    RollCount = math.max(0, math.floor(RollCount))

    if RollCount <= 0 then
        Log.Warn(`[RobuxProducts] Invalid lucky block roll count: {DisplayName}`)
        return false
    end

    local RolledRewards = {}

    for _ = 1, RollCount do
        local Reward = Roll_Lucky_Block_Reward(Rewards)

        if not Reward then
            Log.Warn(`[RobuxProducts] Invalid lucky block reward table: {DisplayName}`)
            return false
        end

        local SquishyData = Squishies.GetData(Reward.Kind, Reward.Name)

        if not SquishyData then
            Log.Warn(`[RobuxProducts] Unknown lucky block reward: {Reward.Kind}:{Reward.Name}`)
            return false
        end

        table.insert(RolledRewards, {
            Kind = Reward.Kind,
            Name = Reward.Name,
            Data = SquishyData,
            Key = Squishies.GetKey(Reward.Kind, Reward.Name),
        })
    end

    local HotbarSlots, OccupiedSlots = Copy_Hotbar_And_Get_Occupied(PlayerEntity)
    local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))
    local IndexKeys = {}

    if not InventoryCapacity.CanAddSquishies(OwnedSquishies, #RolledRewards) then
        Notify(Player, InventoryCapacity.SquishyInventoryFullMessage, "Error")
        return false
    end

    for _, Reward in RolledRewards do
        local HotbarSlot = Get_First_Open_Custom_Hotbar_Slot(OccupiedSlots)
        local NewItem = Build_Squishy_Item(Reward.Kind, Reward.Name, Reward.Data, HotbarSlot)

        table.insert(OwnedSquishies, NewItem)
        table.insert(IndexKeys, Reward.Key)

        if HotbarSlot then
            HotbarSlots[tostring(HotbarSlot)] = {
                Slot = HotbarSlot,
                ItemId = NewItem.Id,
                ItemType = "Squishy",
            }
        end
    end

    World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    Add_Index_Keys(PlayerEntity, IndexKeys)
    Notify(Player, `Opened {DisplayName}.`, "Success")

    return true
end

local function Grant_Lasso(
    Player: Player,
    PlayerEntity: number,
    LassoName: string,
    ShouldNotify: boolean?,
    ShouldEquip: boolean?
)
    local LassoData = Lassos.Get(LassoName)

    if not LassoData then
        Log.Warn(`[RobuxProducts] Unknown lasso grant: {LassoName}`)
        return false
    end

    local OwnedLassos = Lassos.Normalize_Owned(World:get(PlayerEntity, Components.OwnedLassos))

    local UpdatedOwnedLassos = Lassos.Add_Owned(OwnedLassos, LassoData.Name)

    World:set(PlayerEntity, Components.OwnedLassos, UpdatedOwnedLassos)
    ProgressionFunnels.Log_Lassos(PlayerEntity, UpdatedOwnedLassos)

    if ShouldEquip ~= false then
        World:set(PlayerEntity, Components.Lasso, LassoData.Name)
    end

    if ShouldNotify ~= false then
        local Message = if ShouldEquip == false
            then `Bought {LassoData.DisplayName}.`
            else `Bought and equipped {LassoData.DisplayName}.`

        Notify(Player, Message, "Success")
    end

    return true
end

local function Grant_Food(Player: Player, PlayerEntity: number, FoodName: string, ShouldNotify: boolean?): boolean
    local FoodData = Foods.Get(FoodName)

    if not FoodData then
        Log.Warn(`[RobuxProducts] Unknown food grant: {FoodName}`)
        return false
    end

    local HotbarSlots, OccupiedSlots = Copy_Hotbar_And_Get_Occupied(PlayerEntity)
    local OwnedFood = Copy_Array(World:get(PlayerEntity, Components.OwnedFood))
    local Entry = Find_Food_Entry(OwnedFood, FoodData.Name)

    if Entry then
        local Amount = if type(Entry.Amount) == "number" then Entry.Amount else 0

        Entry.Amount = math.clamp(math.floor(Amount) + 1, 0, MAX_FOOD_AMOUNT)
        Entry.Name = FoodData.Name
        Entry.Rarity = FoodData.Rarity
        Entry.Image = FoodData.Image
        Entry.XPValue = FoodData.XPValue
    else
        Entry = {
            Id = FoodData.Name,
            Type = "Food",
            Name = FoodData.Name,
            Rarity = FoodData.Rarity,
            Image = FoodData.Image,
            Amount = 1,
            XPValue = FoodData.XPValue,
            Favorite = false,
        }
        table.insert(OwnedFood, Entry)
    end

    if not Find_Assigned_Food_Slot(HotbarSlots, FoodData.Name) then
        local HotbarSlot = Get_First_Open_Custom_Hotbar_Slot(OccupiedSlots)

        if HotbarSlot then
            Entry.HotbarSlot = HotbarSlot
            HotbarSlots[tostring(HotbarSlot)] = {
                Slot = HotbarSlot,
                ItemId = FoodData.Name,
                ItemType = "Food",
            }
            World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
        end
    end

    World:set(PlayerEntity, Components.OwnedFood, OwnedFood)
    if ShouldNotify ~= false then
        Notify(Player, `Bought {FoodData.DisplayName}.`, "Success")
    end

    return true
end

local function Grant_Giftable_Product(
    Player: Player,
    PlayerEntity: number,
    Product: RobuxProducts.PurchaseConfig,
    ShouldEquipLasso: boolean?
): boolean
    if Product.GrantKind == "Food" and Product.FoodName then
        return Grant_Food(Player, PlayerEntity, Product.FoodName, false)
    end

    if Product.GrantKind == "Lasso" and Product.LassoName then
        return Grant_Lasso(Player, PlayerEntity, Product.LassoName, false, ShouldEquipLasso)
    end

    return false
end

local function Grant_Money_Multiplier(Player: Player, PlayerEntity: number, Multiplier: number): boolean
    local CurrentMultiplier =
        RobuxProducts.NormalizeMoneyMultiplier(World:get(PlayerEntity, Components.MoneyMultiplier))
    local PurchasedMultiplier = RobuxProducts.NormalizeMoneyMultiplier(Multiplier)
    local NewMultiplier = math.max(CurrentMultiplier, PurchasedMultiplier)

    if NewMultiplier > CurrentMultiplier then
        Snapshot_Plot_Cash(PlayerEntity, CurrentMultiplier)
        World:set(PlayerEntity, Components.MoneyMultiplier, NewMultiplier)
        Notify(Player, `Money multiplier upgraded to {NewMultiplier}x!`, "Success")
    else
        World:set(PlayerEntity, Components.MoneyMultiplier, CurrentMultiplier)
        Notify(Player, `Money multiplier already {CurrentMultiplier}x.`, "Info")
    end

    return true
end

local function Grant_Restock(Player: Player, PlayerEntity: number)
    local LastRestock = os.time()

    World:set(PlayerEntity, Components.FoodStock, FoodStock.Roll_All())
    World:set(PlayerEntity, Components.LastFoodRestock, LastRestock)
    Network.FoodRestockEndTimeChanged.Fire(Player, LastRestock + RESTOCK_TIME)
    Notify(Player, "The Food Shop has been restocked!", "Success")
end

local function Grant_Product(Player: Player, PlayerEntity: number, Product: RobuxProducts.PurchaseConfig): boolean
    if Product.GrantKind == "Cash" and Product.CashAmount then
        Grant_Cash(Player, PlayerEntity, Product.CashAmount)
        return true
    end

    if Product.GrantKind == "Restock" then
        Grant_Restock(Player, PlayerEntity)
        return true
    end

    if Product.GrantKind == "Food" and Product.FoodName then
        return Grant_Food(Player, PlayerEntity, Product.FoodName)
    end

    if Product.GrantKind == "Lasso" and Product.LassoName then
        return Grant_Lasso(Player, PlayerEntity, Product.LassoName)
    end

    if Product.GrantKind == "Squishies" and Product.Squishies then
        return Grant_Squishy_Pack(Player, PlayerEntity, Product.DisplayName, Product.Squishies)
    end

    if Product.GrantKind == "LuckyBlock" and Product.LuckyBlockRolls and Product.LuckyBlockRewards then
        return Grant_Lucky_Block(
            Player,
            PlayerEntity,
            Product.DisplayName,
            Product.LuckyBlockRolls,
            Product.LuckyBlockRewards
        )
    end

    if Product.GrantKind == "MoneyMultiplier" and Product.MoneyMultiplier then
        return Grant_Money_Multiplier(Player, PlayerEntity, Product.MoneyMultiplier)
    end

    if Product.GrantKind == "SkipTime" and Product.SkipTimeSeconds then
        return SkipTimeRewards.Grant(Player, PlayerEntity, Product.SkipTimeSeconds)
    end

    if Product.GrantKind == "OfflineRewardX5" then
        local Claimed = OfflineRewardsSystem.Claim_Offline_Reward(PlayerEntity, 5)

        if not Claimed then
            Notify(Player, "No offline rewards to claim.", "Info")
        end

        return true
    end

    if Product.GrantKind == "ClaimAllDailyRewards" then
        local ClaimedCount, FailureReason = DailyRewardsSystem.Claim_All_Ready(PlayerEntity)

        if FailureReason == "InventoryFull" then
            return false
        end

        if ClaimedCount <= 0 then
            Notify(Player, "No daily rewards to claim.", "Info")
        end

        return true
    end

    Log.Warn(`[RobuxProducts] Grant not implemented for product: {Product.Key}`)
    return false
end

local function Grant_Pending_Gift(
    Player: Player,
    PlayerEntity: number,
    Product: RobuxProducts.PurchaseConfig
): (boolean, boolean)
    local PendingGift = RobuxGifts.Consume_Pending_Gift(Player, Product)

    if not PendingGift then
        return false, false
    end

    local TargetPlayer = Players:GetPlayerByUserId(PendingGift.TargetUserId)
    local TargetEntity = TargetPlayer and Registry.Get("Players", TargetPlayer)

    if TargetPlayer and TargetEntity and World:contains(TargetEntity) then
        if not Grant_Giftable_Product(TargetPlayer, TargetEntity, Product, false) then
            return true, false
        end

        RobuxGifts.Notify_Gifted(Player, TargetPlayer, Product.DisplayName)
        return true, true
    end

    if not Grant_Giftable_Product(Player, PlayerEntity, Product, true) then
        return true, false
    end

    RobuxGifts.Notify_Purchased(Player, Product.DisplayName)
    return true, true
end

local function Fire_Robux_Purchase_Effect(Player: Player)
    Network.RobuxPurchaseEffect.FireAll({
        PlayerUserId = Player.UserId,
    })
end

local function Process_Receipt(ReceiptInfo)
    local Product = RobuxProducts.GetByProductId(ReceiptInfo.ProductId)

    if not Product then
        Log.Warn(`[RobuxProducts] Unknown product receipt: {ReceiptInfo.ProductId}`)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local PurchaseId = tostring(ReceiptInfo.PurchaseId)

    if ProcessedPurchaseIds[PurchaseId] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)

    if not Player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local GiftHandled, GiftGranted = Grant_Pending_Gift(Player, PlayerEntity, Product)

    if GiftHandled and not GiftGranted then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    if not GiftHandled and not Grant_Product(Player, PlayerEntity, Product) then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    Fire_Robux_Purchase_Effect(Player)

    ProcessedPurchaseIds[PurchaseId] = true
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function Handle_Gamepass_Purchase_Finished(Player: Player, GamePassId: number, WasPurchased: boolean)
    local Product = RobuxProducts.GetByGamePassId(GamePassId)

    if not WasPurchased or not Product then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity or not Grant_Product(Player, PlayerEntity, Product) then
        return
    end

    Fire_Robux_Purchase_Effect(Player)
end

local function Get_Player_Entity_When_Loaded(Player: Player): number?
    local StartedAt = os.clock()

    while Player.Parent and os.clock() - StartedAt < 30 do
        local Entity = Get_Player_Entity(Player)

        if Entity then
            return Entity
        end

        task.wait(0.25)
    end

    return nil
end

local function Player_Owns_Gamepass(Player: Player, GamePassId: number): boolean
    local Success, Result = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, GamePassId)
    end)

    if not Success then
        Log.Warn(`[RobuxProducts] GamePass ownership check failed for {Player.UserId}: {Result}`)
        return false
    end

    return Result == true
end

local function Sync_Player_Gamepass_Grants(Player: Player)
    if GamepassOwnershipChecks[Player] then
        return
    end

    GamepassOwnershipChecks[Player] = true

    local PlayerEntity = Get_Player_Entity_When_Loaded(Player)

    if not PlayerEntity then
        GamepassOwnershipChecks[Player] = nil
        return
    end

    for _, Product in RobuxProducts.Products do
        if Product.Kind ~= "GamePass" or not Product.GamePassId then
            continue
        end

        if Product.GrantKind ~= "Lasso" or not Product.LassoName then
            continue
        end

        if not Player_Owns_Gamepass(Player, Product.GamePassId) then
            continue
        end

        local OwnedLassos = Lassos.Normalize_Owned(World:get(PlayerEntity, Components.OwnedLassos))

        if Lassos.Is_Owned(OwnedLassos, Product.LassoName) then
            World:set(PlayerEntity, Components.OwnedLassos, OwnedLassos)
            continue
        end

        Grant_Lasso(Player, PlayerEntity, Product.LassoName, false, false)
    end
end

local function Install_Receipt_Handler()
    if ReceiptHandlerInstalled then
        return
    end

    ReceiptHandlerInstalled = true
    MarketplaceService.ProcessReceipt = Process_Receipt
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(Handle_Gamepass_Purchase_Finished)

    Players.PlayerAdded:Connect(function(Player)
        task.spawn(Sync_Player_Gamepass_Grants, Player)
    end)

    Players.PlayerRemoving:Connect(function(Player)
        GamepassOwnershipChecks[Player] = nil
    end)

    for _, Player in Players:GetPlayers() do
        task.spawn(Sync_Player_Gamepass_Grants, Player)
    end
end

return {
    name = script.Name,
    phase = Phases.InitPhases.Init,
    system = Install_Receipt_Handler,
    runConditions = {},
}
