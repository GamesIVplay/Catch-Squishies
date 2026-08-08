local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local ProgressionFunnels = require(ServerScriptService.Server.Modules.ProgressionFunnels)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)

local CatchConfig = require(ReplicatedStorage.Shared.Modules.CatchConfig)
local Components = require(ReplicatedStorage.Shared.Components)
local InventoryCapacity = require(ReplicatedStorage.Shared.Modules.InventoryCapacity)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Log = require(ReplicatedStorage.Shared.Log)
local Mutations = require(ReplicatedStorage.Shared.Modules.Mutations)
local Phases = require(ReplicatedStorage.Shared.Phases)
local PlaytimeRewards = require(ReplicatedStorage.Shared.Modules.PlaytimeRewards)
local Registry = require(ReplicatedStorage.Shared.Registry)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local World = require(ReplicatedStorage.Shared.World)

local Ratelimit = require(ReplicatedStorage.Packages.Ratelimit)

local PlayerEntities = World:query(Components.Player):cached()
local CLAIM_COOLDOWN_SECONDS = 0.05
local ClaimRateLimit = Ratelimit(1, CLAIM_COOLDOWN_SECONDS)
local CUSTOM_HOTBAR_SLOTS = table.freeze({ 3, 4, 5, 6, 7 })
local ActiveClaims: { [number]: boolean } = {}
local Sessions: {
    [Player]: {
        StartedAt: number,
        Claimed: { [number]: boolean },
        Notified: { [number]: boolean },
    },
} =
    {}

local function Notify(
    Player: Player,
    Text: string,
    Type: "Success" | "Info" | "Warning" | "Error" | "Reward" | "Announcement"
)
    Network.Notification.Fire(Player, {
        Text = Text,
        Type = Type,
    })
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
            OccupiedSlots[Slot] = true
        end
    end

    return HotbarSlots, OccupiedSlots
end

local function Get_First_Open_Custom_Hotbar_Slot(PlayerEntity: number): (number?, { [string]: any })
    local HotbarSlots, OccupiedSlots = Copy_Hotbar_And_Get_Occupied(PlayerEntity)

    for _, Slot in CUSTOM_HOTBAR_SLOTS do
        if not OccupiedSlots[Slot] then
            return Slot, HotbarSlots
        end
    end

    return nil, HotbarSlots
end

local function Add_Index_Key(PlayerEntity: number, IndexKey: string)
    if type(IndexKey) ~= "string" or not Squishies.GetDataFromKey(IndexKey) then
        return
    end

    local CurrentIndex = World:get(PlayerEntity, Components.Index)
    local NewIndex = {}
    local Seen = {}

    if type(CurrentIndex) == "table" then
        for _, Key in CurrentIndex do
            if type(Key) == "string" and Key ~= "" and not Seen[Key] then
                Seen[Key] = true
                table.insert(NewIndex, Key)
            end
        end
    end

    if Seen[IndexKey] then
        return
    end

    table.insert(NewIndex, IndexKey)
    table.sort(NewIndex)
    World:set(PlayerEntity, Components.Index, NewIndex)
end

local function Get_Claimed_List(Player: Player): { number }
    local Session = Sessions[Player]
    local Claimed = {}

    if not Session then
        return Claimed
    end

    for RewardIndex in Session.Claimed do
        table.insert(Claimed, RewardIndex)
    end

    table.sort(Claimed)

    return Claimed
end

local function Send_Claimed_Rewards(Player: Player)
    Network.ClaimedPlaytimeRewardsChanged.Fire(Player, Get_Claimed_List(Player))
end

local function Create_Session(Player: Player)
    if Sessions[Player] then
        return
    end

    Sessions[Player] = {
        StartedAt = workspace:GetServerTimeNow(),
        Claimed = {},
        Notified = {},
    }

    Network.PlaytimeStartChanged.Fire(Player, Sessions[Player].StartedAt)
    Send_Claimed_Rewards(Player)
end

local function Notify_Ready_Rewards(Player: Player)
    local Session = Sessions[Player]

    if not Session then
        return
    end

    local Elapsed = workspace:GetServerTimeNow() - Session.StartedAt
    local DidNotify = false

    for RewardIndex, Reward in PlaytimeRewards do
        if Session.Claimed[RewardIndex] or Session.Notified[RewardIndex] or Elapsed < Reward.Time then
            continue
        end

        Session.Notified[RewardIndex] = true
        DidNotify = true
    end

    if DidNotify then
        Notify(Player, "Playtime reward is ready!", "Info")
    end
end

local function Sync_Sessions()
    for _, Player in PlayerEntities:iter() do
        Create_Session(Player)
        Notify_Ready_Rewards(Player)
    end
end

local function Grant_Cash_Reward(PlayerEntity: number, Amount: number): boolean
    if type(Amount) ~= "number" or Amount <= 0 or Amount ~= Amount then
        return false
    end

    local Cash = World:get(PlayerEntity, Components.Cash) or 0
    World:set(PlayerEntity, Components.Cash, Cash + math.floor(Amount))

    return true
end

local function Build_Squishy_Item(Kind: string, SquishyName: string, SquishyData: any, HotbarSlot: number?): any
    local Weight = CatchConfig.MinWeight
    local NewItem = {
        Id = HttpService:GenerateGUID(false),
        Type = "Squishy",
        Kind = Kind,
        Name = SquishyName,
        Rarity = SquishyData.Rarity,
        Image = SquishyData.Image,
        BaseIncomePerSec = SquishyData.IncomePerSec,
        FinalIncomePerSec = 0,
        Weight = Weight,
        IncomePerSec = 0,
        Mutation = Mutations.Roll(Kind),
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

local function Grant_Squishy_Reward(
    Player: Player,
    PlayerEntity: number,
    Kind: string,
    SquishyName: string
): (boolean, string?)
    local SquishyData = Squishies.GetData(Kind :: any, SquishyName)

    if not SquishyData then
        return false, "InvalidReward"
    end

    local NewHotbarSlot, HotbarSlots = Get_First_Open_Custom_Hotbar_Slot(PlayerEntity)
    local NewItem = Build_Squishy_Item(Kind, SquishyName, SquishyData, NewHotbarSlot)
    local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))

    if not InventoryCapacity.CanAddSquishies(OwnedSquishies, 1) then
        Notify(Player, InventoryCapacity.SquishyInventoryFullMessage, "Error")
        return false, "InventoryFull"
    end

    table.insert(OwnedSquishies, NewItem)

    if NewHotbarSlot then
        HotbarSlots[tostring(NewHotbarSlot)] = {
            Slot = NewHotbarSlot,
            ItemId = NewItem.Id,
            ItemType = "Squishy",
        }
        World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    end

    World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
    Add_Index_Key(PlayerEntity, Squishies.GetKey(Kind :: any, SquishyName))

    return true, nil
end

local function Grant_Reward(Player: Player, PlayerEntity: number, Reward): (boolean, string?)
    if type(Reward) ~= "table" then
        return false, "InvalidReward"
    end

    if Reward.Type == "Cash" then
        return Grant_Cash_Reward(PlayerEntity, Reward.Amount), nil
    end

    if Reward.Type == "Squishy" and type(Reward.Kind) == "string" and type(Reward.Name) == "string" then
        return Grant_Squishy_Reward(Player, PlayerEntity, Reward.Kind, Reward.Name)
    end

    return false, "InvalidReward"
end

local function Handle_Claim_Request(Player: Player, RewardIndex: number)
    if type(RewardIndex) ~= "number" then
        return
    end

    RewardIndex = math.floor(RewardIndex)

    if not ClaimRateLimit(Player.UserId) or ActiveClaims[Player.UserId] then
        return
    end

    ActiveClaims[Player.UserId] = true

    local Success, Error = pcall(function()
        local PlayerEntity = Registry.Get("Players", Player)

        if not PlayerEntity or not World:contains(PlayerEntity) then
            return
        end

        Create_Session(Player)

        local Session = Sessions[Player]
        local Reward = PlaytimeRewards[RewardIndex]

        if not Session or not Reward then
            return
        end

        if Session.Claimed[RewardIndex] then
            Notify(Player, "You already claimed this reward.", "Error")
            return
        end

        if workspace:GetServerTimeNow() - Session.StartedAt < Reward.Time then
            Notify(Player, "This reward is not ready yet.", "Error")
            return
        end

        local Granted, FailureReason = Grant_Reward(Player, PlayerEntity, Reward)

        if not Granted then
            Log.Warn(`[PlaytimeRewards] Failed to grant reward {RewardIndex} for {Player.Name}`)

            if FailureReason ~= "InventoryFull" then
                Notify(Player, "Reward failed to claim.", "Error")
            end

            return
        end

        Session.Claimed[RewardIndex] = true
        ProgressionFunnels.Log_Playtime_Reward(PlayerEntity, RewardIndex)
        Send_Claimed_Rewards(Player)
        Notify(Player, "Playtime reward claimed!", "Success")
    end)

    ActiveClaims[Player.UserId] = nil

    if not Success then
        Log.Warn(`[PlaytimeRewards] Failed to claim reward for {Player.Name}: {Error}`)
    end
end

local function Handle_Claim_Requests()
    for _, Player: Player, RewardIndex: number in Network.ClaimPlaytimeReward.Iter() do
        if not RemoteCooldowns.Allow(Player, "ClaimPlaytimeReward", CLAIM_COOLDOWN_SECONDS) then
            continue
        end

        task.spawn(Handle_Claim_Request, Player, RewardIndex)
    end
end

Players.PlayerRemoving:Connect(function(Player)
    Sessions[Player] = nil
    ActiveClaims[Player.UserId] = nil
end)

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        Sync_Sessions()
        Handle_Claim_Requests()
    end,
    runConditions = {},
}
