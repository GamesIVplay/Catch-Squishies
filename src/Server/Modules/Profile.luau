local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FoodStock = require(ReplicatedStorage.Shared.Modules.FoodStock)
local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local Log = require(ReplicatedStorage.Shared.Log)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local SquishyLevels = require(ReplicatedStorage.Shared.Modules.SquishyLevels)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)

export type ProfileData = {
    Cash: number,
    MoneyMultiplier: number,
    Lasso: string,
    OwnedLassos: { string },
    OwnedSquishies: { any },
    OwnedFood: { any },
    FoodStock: { [string]: number },
    LastFoodRestock: number,
    HotbarSlots: { any },
    HotbarSlotLayoutVersion: number?,
    Index: { string },
    ClaimedIndexRewards: { string },
    ClaimedDailyRewards: { number },
    LastDailyRewardClaim: number,
    LastPlayed: number,
    PendingOfflineCash: number,
    PendingOfflineSeconds: number,
    TutorialVersion: number,
    TutorialStep: number,
    PlotAreas: { [string]: boolean },
    PlotSquishies: { any },
    ClaimedGroupReward: boolean?,
}

local ProfileStore = require(ReplicatedStorage.Packages.ProfileStore)
type Profile = ProfileStore.Profile<ProfileData>

local PLAYER_DATA_TEMPLATE: ProfileData = {
    Cash = 250,
    MoneyMultiplier = 1,
    Lasso = "Basic",
    OwnedLassos = { "Basic" },
    OwnedSquishies = {},
    OwnedFood = {},
    FoodStock = {},
    LastFoodRestock = 0,
    HotbarSlots = {},
    HotbarSlotLayoutVersion = 2,
    Index = {},
    ClaimedIndexRewards = {},
    ClaimedDailyRewards = {},
    LastDailyRewardClaim = 0,
    LastPlayed = 0,
    PendingOfflineCash = 0,
    PendingOfflineSeconds = 0,
    TutorialVersion = TutorialSteps.Version,
    TutorialStep = TutorialSteps.StartStep,
    PlotAreas = {},
    PlotSquishies = {},
}

local PlayerProfileStore = ProfileStore.New(not _G.IN_DEV and "Main" or "Dev", PLAYER_DATA_TEMPLATE)
local Profiles: { [Player]: Profile } = {}

local PLOT_AREA_KEYS = table.freeze({
    "LeftFront",
    "RightFront",
    "CenterBack",
    "LeftBack",
    "RightBack",
})

local HOTBAR_SLOT_LAYOUT_VERSION = 2
local CUSTOM_SLOT_MIN = 3
local CUSTOM_SLOT_MAX = 7
local LEGACY_CUSTOM_SLOT_MIN = 4
local LEGACY_CUSTOM_SLOT_MAX = 8

local function Normalize_Tutorial_Role(Value: any): string?
    if Value == TutorialSteps.FirstRole or Value == TutorialSteps.StrongRole then
        return Value
    end

    return nil
end

local function Migrate_Lasso_Data(Profile_Data: ProfileData)
    Profile_Data.OwnedLassos = Lassos.Normalize_Owned(Profile_Data.OwnedLassos)
    Profile_Data.Lasso = Lassos.Normalize_Selected(Profile_Data.Lasso, Profile_Data.OwnedLassos)
end

local function Migrate_Money_Multiplier(Profile_Data: ProfileData)
    local Value = Profile_Data.MoneyMultiplier

    if type(Value) ~= "number" or Value ~= Value then
        Profile_Data.MoneyMultiplier = 1
        return
    end

    local Normalized = math.max(1, math.floor(Value))
    local Result = 1

    for _, Tier in { 2, 4, 8, 16, 32, 64 } do
        if Normalized >= Tier then
            Result = Tier
        end
    end

    Profile_Data.MoneyMultiplier = Result
end

local function Normalize_Nonnegative_Number(Value: any): number
    if type(Value) ~= "number" or Value ~= Value then
        return 0
    end

    return math.max(0, math.floor(Value))
end

local function Migrate_Offline_Rewards(Profile_Data: ProfileData)
    Profile_Data.LastPlayed = Normalize_Nonnegative_Number(Profile_Data.LastPlayed)
    Profile_Data.PendingOfflineCash = Normalize_Nonnegative_Number(Profile_Data.PendingOfflineCash)
    Profile_Data.PendingOfflineSeconds = Normalize_Nonnegative_Number(Profile_Data.PendingOfflineSeconds)
end

local function Migrate_Squishy_Data(Profile_Data: ProfileData)
    if type(Profile_Data.OwnedSquishies) ~= "table" then
        Profile_Data.OwnedSquishies = {}
        return
    end

    local Migrated = {}

    for _, Entry in Profile_Data.OwnedSquishies do
        if type(Entry) ~= "table" then
            continue
        end

        local Kind = if type(Entry.Kind) == "string" and Entry.Kind ~= "" then Entry.Kind else "Slime"
        local Name = if type(Entry.Name) == "string" then Entry.Name else ""
        local SquishyData = Squishies.GetData(Kind :: any, Name)

        if not SquishyData then
            continue
        end

        local Weight = if type(Entry.Weight) == "number" and Entry.Weight == Entry.Weight then Entry.Weight else 0
        local BaseIncomePerSec = if type(Entry.BaseIncomePerSec) == "number"
            then Entry.BaseIncomePerSec
            else SquishyData.IncomePerSec
        local Level = SquishyLevels.NormalizeLevel(Entry.Level)
        local NormalizedEntry = {
            Id = if type(Entry.Id) == "string" and Entry.Id ~= "" then Entry.Id else HttpService:GenerateGUID(false),
            Type = "Squishy",
            Kind = Kind,
            Name = Name,
            Rarity = SquishyData.Rarity,
            Image = SquishyData.Image,
            BaseIncomePerSec = BaseIncomePerSec,
            FinalIncomePerSec = 0,
            Weight = Weight,
            Mutation = InventoryMath.NormalizeMutation(Entry.Mutation, Kind),
            EventMutations = InventoryMath.NormalizeEventMutations(Entry.EventMutations),
            Level = Level,
            XP = if Level >= SquishyLevels.MaxLevel then 0 else SquishyLevels.NormalizeXp(Entry.XP),
            Equipped = Entry.Equipped == true,
            Favorite = Entry.Favorite == true,
            HotbarSlot = if type(Entry.HotbarSlot) == "number" then Entry.HotbarSlot else nil,
            CaughtAt = if type(Entry.CaughtAt) == "number" then Entry.CaughtAt else os.time(),
            TutorialRole = Normalize_Tutorial_Role(Entry.TutorialRole),
        }

        NormalizedEntry.FinalIncomePerSec = InventoryMath.GetFinalIncomePerSec(NormalizedEntry)
        table.insert(Migrated, NormalizedEntry)
    end

    Profile_Data.OwnedSquishies = Migrated
end

local function Migrate_Food_Data(Profile_Data: ProfileData)
    if type(Profile_Data.OwnedFood) ~= "table" then
        Profile_Data.OwnedFood = {}
        return
    end

    local Migrated = {}

    for Key, Entry in Profile_Data.OwnedFood do
        local FoodName = ""
        local Amount = 0
        local HotbarSlot = nil

        if type(Entry) == "table" then
            FoodName = if type(Entry.Name) == "string"
                then Entry.Name
                elseif type(Entry.Id) == "string" then Entry.Id
                else ""
            Amount = if type(Entry.Amount) == "number" then Entry.Amount else 0
            HotbarSlot = if type(Entry.HotbarSlot) == "number" then Entry.HotbarSlot else nil
        elseif type(Key) == "string" and type(Entry) == "number" then
            FoodName = Key
            Amount = Entry
        end

        local FoodData = Foods.Get(FoodName)

        if not FoodData or Amount <= 0 then
            continue
        end

        table.insert(Migrated, {
            Id = FoodData.Name,
            Type = "Food",
            Name = FoodData.Name,
            Rarity = FoodData.Rarity,
            Image = FoodData.Image,
            Amount = math.clamp(math.floor(Amount), 0, 65_535),
            XPValue = FoodData.XPValue,
            Favorite = if type(Entry) == "table" then Entry.Favorite == true else false,
            HotbarSlot = HotbarSlot,
        })
    end

    Profile_Data.OwnedFood = Migrated
end

local function Migrate_Food_Stock_Data(Profile_Data: ProfileData)
    local NormalizedStock, Changed = FoodStock.Normalize(Profile_Data.FoodStock)

    if Changed then
        Profile_Data.FoodStock = NormalizedStock
    end

    if
        type(Profile_Data.LastFoodRestock) ~= "number"
        or Profile_Data.LastFoodRestock ~= Profile_Data.LastFoodRestock
    then
        Profile_Data.LastFoodRestock = 0
    else
        Profile_Data.LastFoodRestock = math.max(0, math.floor(Profile_Data.LastFoodRestock))
    end
end

local function Is_Custom_Hotbar_Slot(Slot: any): boolean
    return type(Slot) == "number" and Slot >= CUSTOM_SLOT_MIN and Slot <= CUSTOM_SLOT_MAX and math.floor(Slot) == Slot
end

local function Normalize_Hotbar_Slot(Slot: any, ShiftLegacySlots: boolean): number?
    if type(Slot) ~= "number" or math.floor(Slot) ~= Slot then
        return nil
    end

    if ShiftLegacySlots and Slot >= LEGACY_CUSTOM_SLOT_MIN and Slot <= LEGACY_CUSTOM_SLOT_MAX then
        return Slot - 1
    end

    if Is_Custom_Hotbar_Slot(Slot) then
        return Slot
    end

    return nil
end

local function Owns_Inventory_Item(Profile_Data: ProfileData, ItemId: string, ItemType: string): boolean
    if ItemType == "Squishy" then
        for _, Entry in Profile_Data.OwnedSquishies do
            if type(Entry) == "table" and Entry.Id == ItemId then
                return true
            end
        end

        return false
    end

    if ItemType == "Food" then
        for _, Entry in Profile_Data.OwnedFood do
            if type(Entry) == "table" and Entry.Id == ItemId and Entry.Amount > 0 then
                return true
            end
        end
    end

    return false
end

local function Clear_Item_Hotbar_Slots(Profile_Data: ProfileData)
    for _, Entry in Profile_Data.OwnedSquishies do
        if type(Entry) == "table" then
            Entry.HotbarSlot = nil
        end
    end

    for _, Entry in Profile_Data.OwnedFood do
        if type(Entry) == "table" then
            Entry.HotbarSlot = nil
        end
    end
end

local function Set_Item_Hotbar_Slot(Profile_Data: ProfileData, ItemId: string, ItemType: string, Slot: number)
    local Source = if ItemType == "Squishy" then Profile_Data.OwnedSquishies else Profile_Data.OwnedFood

    for _, Entry in Source do
        if type(Entry) == "table" and Entry.Id == ItemId then
            Entry.HotbarSlot = Slot
            return
        end
    end
end

local function Migrate_Hotbar_Data(Profile_Data: ProfileData)
    if type(Profile_Data.HotbarSlots) ~= "table" then
        Profile_Data.HotbarSlots = {}
    end

    local ShiftLegacySlots = Profile_Data.HotbarSlotLayoutVersion ~= HOTBAR_SLOT_LAYOUT_VERSION
    local Normalized = {}
    local OccupiedSlots = {}

    local function Add_Assignment(Slot: any, ItemId: any, ItemType: any)
        local NormalizedSlot = Normalize_Hotbar_Slot(Slot, ShiftLegacySlots)

        if not NormalizedSlot or type(ItemId) ~= "string" or type(ItemType) ~= "string" then
            return
        end

        if OccupiedSlots[NormalizedSlot] or not Owns_Inventory_Item(Profile_Data, ItemId, ItemType) then
            return
        end

        OccupiedSlots[NormalizedSlot] = true
        Normalized[tostring(NormalizedSlot)] = {
            Slot = NormalizedSlot,
            ItemId = ItemId,
            ItemType = ItemType,
        }
    end

    for Key, Entry in Profile_Data.HotbarSlots do
        if type(Entry) == "table" then
            Add_Assignment(Entry.Slot or tonumber(Key), Entry.ItemId, Entry.ItemType)
        end
    end

    for _, Entry in Profile_Data.OwnedSquishies do
        if type(Entry) == "table" then
            Add_Assignment(Entry.HotbarSlot, Entry.Id, "Squishy")
        end
    end

    for _, Entry in Profile_Data.OwnedFood do
        if type(Entry) == "table" then
            Add_Assignment(Entry.HotbarSlot, Entry.Id, "Food")
        end
    end

    Clear_Item_Hotbar_Slots(Profile_Data)

    for _, Assignment in Normalized do
        Set_Item_Hotbar_Slot(Profile_Data, Assignment.ItemId, Assignment.ItemType, Assignment.Slot)
    end

    Profile_Data.HotbarSlots = Normalized
    Profile_Data.HotbarSlotLayoutVersion = HOTBAR_SLOT_LAYOUT_VERSION
end

local function Migrate_Plot_Areas(Profile_Data: ProfileData)
    if type(Profile_Data.PlotAreas) ~= "table" then
        Profile_Data.PlotAreas = {}
        return
    end

    local Normalized = {}

    for _, AreaName in PLOT_AREA_KEYS do
        if Profile_Data.PlotAreas[AreaName] == true then
            Normalized[AreaName] = true
        end
    end

    Profile_Data.PlotAreas = Normalized
end

local function Migrate_Plot_Squishy_Data(Profile_Data: ProfileData)
    if type(Profile_Data.PlotSquishies) ~= "table" then
        Profile_Data.PlotSquishies = {}
        return
    end

    local Migrated = {}
    local Now = workspace:GetServerTimeNow()

    for _, Entry in Profile_Data.PlotSquishies do
        if type(Entry) ~= "table" then
            continue
        end

        local Kind = if type(Entry.Kind) == "string" and Entry.Kind ~= "" then Entry.Kind else "Slime"
        local Name = if type(Entry.Name) == "string" then Entry.Name else ""
        local SquishyData = Squishies.GetData(Kind :: any, Name)

        if not SquishyData then
            continue
        end

        local Weight = if type(Entry.Weight) == "number" and Entry.Weight == Entry.Weight then Entry.Weight else 0
        local BaseIncomePerSec = if type(Entry.BaseIncomePerSec) == "number"
            then Entry.BaseIncomePerSec
            else SquishyData.IncomePerSec
        local Level = SquishyLevels.NormalizeLevel(Entry.Level)
        local NormalizedEntry = {
            Id = if type(Entry.Id) == "string" and Entry.Id ~= "" then Entry.Id else HttpService:GenerateGUID(false),
            Type = "Squishy",
            Kind = Kind,
            Name = Name,
            Rarity = SquishyData.Rarity,
            Image = SquishyData.Image,
            BaseIncomePerSec = BaseIncomePerSec,
            FinalIncomePerSec = 0,
            Weight = Weight,
            Mutation = InventoryMath.NormalizeMutation(Entry.Mutation, Kind),
            EventMutations = InventoryMath.NormalizeEventMutations(Entry.EventMutations),
            Level = Level,
            XP = if Level >= SquishyLevels.MaxLevel then 0 else SquishyLevels.NormalizeXp(Entry.XP),
            Favorite = Entry.Favorite == true,
            PositionX = if type(Entry.PositionX) == "number" then Entry.PositionX else 0,
            PositionY = if type(Entry.PositionY) == "number" then Entry.PositionY else 0,
            PositionZ = if type(Entry.PositionZ) == "number" then Entry.PositionZ else 0,
            PlacedAt = if type(Entry.PlacedAt) == "number" then Entry.PlacedAt else os.time(),
            StoredCash = if type(Entry.StoredCash) == "number" and Entry.StoredCash == Entry.StoredCash
                then math.max(0, Entry.StoredCash)
                else 0,
            LastCashUpdate = Now,
            TutorialRole = Normalize_Tutorial_Role(Entry.TutorialRole),
        }

        NormalizedEntry.FinalIncomePerSec = InventoryMath.GetFinalIncomePerSec(NormalizedEntry)
        table.insert(Migrated, NormalizedEntry)
    end

    Profile_Data.PlotSquishies = Migrated
end

local function Add_Index_Key(Result: { string }, Seen: { [string]: boolean }, Key: any)
    if type(Key) ~= "string" or Key == "" or Seen[Key] then
        return
    end

    if not Squishies.GetDataFromKey(Key) then
        return
    end

    Seen[Key] = true
    table.insert(Result, Key)
end

local function Add_Index_Item(Result: { string }, Seen: { [string]: boolean }, Kind: any, Name: any)
    if (Kind ~= "Slime" and Kind ~= "Dumpling") or type(Name) ~= "string" or Name == "" then
        return
    end

    Add_Index_Key(Result, Seen, Squishies.GetKey(Kind, Name))
end

local function Add_Legacy_Index_Name(Result: { string }, Seen: { [string]: boolean }, Name: string)
    if Squishies.GetData("Slime", Name) then
        Add_Index_Key(Result, Seen, Squishies.GetKey("Slime", Name))
        return
    end

    if Squishies.GetData("Dumpling", Name) then
        Add_Index_Key(Result, Seen, Squishies.GetKey("Dumpling", Name))
    end
end

local function Migrate_Index_Data(Profile_Data: ProfileData)
    local Result = {}
    local Seen = {}

    if type(Profile_Data.Index) == "table" then
        for _, Key in Profile_Data.Index do
            if type(Key) ~= "string" then
                continue
            end

            if Key:find(":", 1, true) then
                Add_Index_Key(Result, Seen, Key)
            else
                Add_Legacy_Index_Name(Result, Seen, Key)
            end
        end
    end

    if type(Profile_Data.OwnedSquishies) == "table" then
        for _, Entry in Profile_Data.OwnedSquishies do
            if type(Entry) == "table" then
                Add_Index_Item(Result, Seen, Entry.Kind, Entry.Name)
            end
        end
    end

    if type(Profile_Data.PlotSquishies) == "table" then
        for _, Entry in Profile_Data.PlotSquishies do
            if type(Entry) == "table" then
                Add_Index_Item(Result, Seen, Entry.Kind, Entry.Name)
            end
        end
    end

    table.sort(Result)
    Profile_Data.Index = Result

    local Claimed = {}
    local ClaimedSeen = {}

    if type(Profile_Data.ClaimedIndexRewards) == "table" then
        for _, Key in Profile_Data.ClaimedIndexRewards do
            if type(Key) ~= "string" then
                continue
            end

            local NormalizedKey = Key

            if not NormalizedKey:find(":", 1, true) then
                local LegacyResult = {}
                local LegacySeen = {}

                Add_Legacy_Index_Name(LegacyResult, LegacySeen, NormalizedKey)
                NormalizedKey = LegacyResult[1]
            end

            if type(NormalizedKey) == "string" and Seen[NormalizedKey] and not ClaimedSeen[NormalizedKey] then
                ClaimedSeen[NormalizedKey] = true
                table.insert(Claimed, NormalizedKey)
            end
        end
    end

    table.sort(Claimed)
    Profile_Data.ClaimedIndexRewards = Claimed
end

local function Migrate_Daily_Rewards(Profile_Data: ProfileData)
    local Claimed = {}
    local Seen = {}

    if type(Profile_Data.ClaimedDailyRewards) == "table" then
        for _, RewardIndex in Profile_Data.ClaimedDailyRewards do
            RewardIndex = tonumber(RewardIndex)

            if
                RewardIndex
                and RewardIndex >= 1
                and RewardIndex <= 8
                and math.floor(RewardIndex) == RewardIndex
                and not Seen[RewardIndex]
            then
                Seen[RewardIndex] = true
                table.insert(Claimed, RewardIndex)
            end
        end
    end

    table.sort(Claimed)
    Profile_Data.ClaimedDailyRewards = Claimed
    Profile_Data.LastDailyRewardClaim = math.max(tonumber(Profile_Data.LastDailyRewardClaim) or 0, 0)
end

local function Has_Lasso(Profile_Data: ProfileData, LassoName: string): boolean
    for _, OwnedLasso in Profile_Data.OwnedLassos do
        if OwnedLasso == LassoName then
            return true
        end
    end

    return false
end

local function Has_Tutorial_Role(Items: any, Role: string): boolean
    if type(Items) ~= "table" then
        return false
    end

    for _, Item in Items do
        if type(Item) == "table" and Item.TutorialRole == Role then
            return true
        end
    end

    return false
end

local function Count_Table_Items(Items: any): number
    if type(Items) ~= "table" then
        return 0
    end

    local Count = 0

    for _, Item in Items do
        if type(Item) == "table" then
            Count += 1
        end
    end

    return Count
end

local function Has_Enough_Cash_For_Next_Lasso(Profile_Data: ProfileData): boolean
    local LassoData = Lassos.Get(TutorialSteps.NextLasso)
    local Price = LassoData and LassoData.Price or 0

    return Price > 0 and (tonumber(Profile_Data.Cash) or 0) >= Price
end

local function Get_Profile_Plot_Capacity(Profile_Data: ProfileData): number
    local UnlockedCount = 0

    if type(Profile_Data.PlotAreas) == "table" then
        for _, AreaName in PLOT_AREA_KEYS do
            if Profile_Data.PlotAreas[AreaName] == true then
                UnlockedCount += 1
            end
        end
    end

    return 6 + UnlockedCount * 3
end

local function Is_Profile_Pen_Full(Profile_Data: ProfileData): boolean
    return Count_Table_Items(Profile_Data.PlotSquishies) >= Get_Profile_Plot_Capacity(Profile_Data)
end

local LEGACY_TUTORIAL_COMPLETE_AFTER_BUY_STEP = 6

local function Normalize_Legacy_Tutorial_Step(Step: any): number
    Step = tonumber(Step) or TutorialSteps.StartStep

    return math.clamp(math.floor(Step), TutorialSteps.StartStep, 14)
end

local function Get_Adjusted_Legacy_Tutorial_Step(PreviousVersion: number, Step: any): number
    Step = Normalize_Legacy_Tutorial_Step(Step)

    if PreviousVersion < 2 and Step >= 8 then
        Step += 1
    end

    if PreviousVersion < 3 and Step >= 8 then
        Step += 1
    end

    return Step
end

local function Map_Legacy_Tutorial_Step(PreviousVersion: number, Step: any): number
    Step = Get_Adjusted_Legacy_Tutorial_Step(PreviousVersion, Step)

    if PreviousVersion >= TutorialSteps.Version then
        return TutorialSteps.Normalize_Step(Step)
    end

    if Step >= LEGACY_TUTORIAL_COMPLETE_AFTER_BUY_STEP then
        return TutorialSteps.Complete
    end

    if Step <= 2 then
        return TutorialSteps.CatchFirst
    elseif Step == 3 then
        return TutorialSteps.PlaceFirst
    elseif Step == 4 then
        return TutorialSteps.CollectCash
    end

    return TutorialSteps.BuyNextLasso
end

local function Migrate_Tutorial_Data(Profile_Data: ProfileData)
    local PreviousVersion = if type(Profile_Data.TutorialVersion) == "number"
        then math.floor(Profile_Data.TutorialVersion)
        else 0

    local Step = Map_Legacy_Tutorial_Step(PreviousVersion, Profile_Data.TutorialStep)

    Profile_Data.TutorialVersion = TutorialSteps.Version

    local HasFirstOwned = Has_Tutorial_Role(Profile_Data.OwnedSquishies, TutorialSteps.FirstRole)
    local HasFirstPlaced = Has_Tutorial_Role(Profile_Data.PlotSquishies, TutorialSteps.FirstRole)
    local HasStrongOwned = Has_Tutorial_Role(Profile_Data.OwnedSquishies, TutorialSteps.StrongRole)
    local HasStrongPlaced = Has_Tutorial_Role(Profile_Data.PlotSquishies, TutorialSteps.StrongRole)
    local OwnsNextLasso = Has_Lasso(Profile_Data, TutorialSteps.NextLasso)

    if
        TutorialSteps.Is_Complete(Step)
        or OwnsNextLasso
        or HasStrongOwned
        or HasStrongPlaced
        or Has_Enough_Cash_For_Next_Lasso(Profile_Data)
        or Is_Profile_Pen_Full(Profile_Data)
    then
        Step = TutorialSteps.Complete
    elseif HasFirstPlaced then
        Step = if Step >= TutorialSteps.BuyNextLasso then TutorialSteps.BuyNextLasso else TutorialSteps.CollectCash
    elseif HasFirstOwned then
        Step = TutorialSteps.PlaceFirst
    elseif Step >= TutorialSteps.BuyNextLasso then
        Step = TutorialSteps.BuyNextLasso
    elseif Step >= TutorialSteps.PlaceFirst then
        Step = TutorialSteps.CatchFirst
    end

    Profile_Data.TutorialStep = TutorialSteps.Normalize_Step(Step)
end

function Load_Profile(Player: Player): Profile?
    if not Player:IsDescendantOf(Players) then
        return nil
    end

    local Profile

    if _G.Mock == true then
        Profile = PlayerProfileStore.Mock:StartSessionAsync(tostring(Player.UserId), {
            Cancel = function()
                return not Player:IsDescendantOf(Players)
            end,
        })
    else
        Profile = PlayerProfileStore:StartSessionAsync(tostring(Player.UserId), {
            Cancel = function()
                return not Player:IsDescendantOf(Players)
            end,
        })
    end

    if Profile then
        Profile:AddUserId(Player.UserId)
        Profile:Reconcile()
        Migrate_Money_Multiplier(Profile.Data)
        Migrate_Lasso_Data(Profile.Data)
        Migrate_Squishy_Data(Profile.Data)
        Migrate_Food_Data(Profile.Data)
        Migrate_Food_Stock_Data(Profile.Data)
        Migrate_Hotbar_Data(Profile.Data)
        Migrate_Plot_Areas(Profile.Data)
        Migrate_Plot_Squishy_Data(Profile.Data)
        Migrate_Index_Data(Profile.Data)
        Migrate_Daily_Rewards(Profile.Data)
        Migrate_Offline_Rewards(Profile.Data)
        Migrate_Tutorial_Data(Profile.Data)

        Profile.OnSessionEnd:Connect(function()
            Profiles[Player] = nil

            Player:Kick(`Profile session ended - please rejoin`)

            Log.Info(`Profile session ended for: '{Player.Name}'`)
        end)

        if Player.Parent == Players then
            Profiles[Player] = Profile

            Log.Info(`Profile loaded for: '{Player.Name}'`)

            return Profile
        else
            Profile:EndSession()

            Log.Info(`'{Player.Name}' left before their profile loaded`)

            return nil
        end
    else
        Player:Kick(`Profile failed to load`)

        Log.Warn(`Profile failed to load for: '{Player.Name}'`)

        return nil
    end
end

function Unload_Profile(Player: Player)
    local Profile = Profiles[Player]

    if Profile then
        Profile:EndSession()
        Profiles[Player] = nil

        Log.Info(`Profile unloaded for: '{Player.Name}'`)
    end
end

function Get_Profile(Player: Player)
    return Profiles[Player]
end

return table.freeze({
    Load = Load_Profile,
    Unload = Unload_Profile,
    Get = Get_Profile,
})
