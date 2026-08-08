local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local ProgressionFunnels = require(ServerScriptService.Server.Modules.ProgressionFunnels)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)

local CatchConfig = require(ReplicatedStorage.Shared.Modules.CatchConfig)
local Components = require(ReplicatedStorage.Shared.Components)
local DailyRewards = require(ReplicatedStorage.Shared.Modules.DailyRewards)
local InventoryCapacity = require(ReplicatedStorage.Shared.Modules.InventoryCapacity)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Log = require(ReplicatedStorage.Shared.Log)
local Mutations = require(ReplicatedStorage.Shared.Modules.Mutations)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local World = require(ReplicatedStorage.Shared.World)

local Ratelimit = require(ReplicatedStorage.Packages.Ratelimit)

local PlayerEntities = World:query(Components.Player):cached()
local CLAIM_COOLDOWN_SECONDS = 0.05
local ClaimRateLimit = Ratelimit(1, CLAIM_COOLDOWN_SECONDS)
local CUSTOM_HOTBAR_SLOTS = table.freeze({ 3, 4, 5, 6, 7 })

local Daily_Rewards = {}
local ActiveClaims: { [number]: boolean } = {}
local Sessions: {
    [Player]: {
        LastClaimAt: number,
        Claimed: { [number]: boolean },
    },
} = {}

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

local function Normalize_Claimed_List(ClaimedRewards): { number }
    local Result = {}
    local Seen = {}

    if type(ClaimedRewards) ~= "table" then
        return Result
    end

    for _, RewardIndex in ClaimedRewards do
        RewardIndex = tonumber(RewardIndex)

        if
            RewardIndex
            and DailyRewards[RewardIndex]
            and math.floor(RewardIndex) == RewardIndex
            and not Seen[RewardIndex]
        then
            Seen[RewardIndex] = true
            table.insert(Result, RewardIndex)
        end
    end

    table.sort(Result)

    return Result
end

local function Claimed_List_To_Set(ClaimedRewards): { [number]: boolean }
    local Claimed = {}

    for _, RewardIndex in Normalize_Claimed_List(ClaimedRewards) do
        Claimed[RewardIndex] = true
    end

    return Claimed
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

local function Save_Session_To_Components(Player: Player, PlayerEntity: number)
    local Session = Sessions[Player]

    if not Session then
        return
    end

    World:set(PlayerEntity, Components.ClaimedDailyRewards, Get_Claimed_List(Player))
    World:set(PlayerEntity, Components.LastDailyRewardClaim, Session.LastClaimAt)
end

local function Create_Session(Player: Player, PlayerEntity: number)
    if Sessions[Player] then
        return
    end

    Sessions[Player] = {
        LastClaimAt = math.max(tonumber(World:get(PlayerEntity, Components.LastDailyRewardClaim)) or 0, 0),
        Claimed = Claimed_List_To_Set(World:get(PlayerEntity, Components.ClaimedDailyRewards)),
    }

    Save_Session_To_Components(Player, PlayerEntity)
end

local function Sync_Sessions()
    for PlayerEntity, Player in PlayerEntities:iter() do
        Create_Session(Player, PlayerEntity)
    end
end

local function Get_Next_Unclaimed_Reward_Index(Session): number?
    for RewardIndex = 1, #DailyRewards do
        if not Session.Claimed[RewardIndex] then
            return RewardIndex
        end
    end

    return nil
end

local function Can_Claim_Reward(Session, RewardIndex: number): boolean
    local NextIndex = Get_Next_Unclaimed_Reward_Index(Session)

    if NextIndex ~= RewardIndex then
        return false
    end

    local Reward = DailyRewards[RewardIndex]

    if not Reward then
        return false
    end

    local Elapsed = if Session.LastClaimAt > 0
        then math.max(workspace:GetServerTimeNow() - Session.LastClaimAt, 0)
        else math.huge

    return Elapsed >= Reward.Time
end

local function Count_Unclaimed_Squishy_Rewards(Session): number
    local Count = 0

    for RewardIndex, Reward in DailyRewards do
        if Session.Claimed[RewardIndex] then
            continue
        end

        if Reward.Type == "Squishy" then
            Count += 1
        end
    end

    return Count
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

    if Reward.Type == "Squishy" and type(Reward.Kind) == "string" and type(Reward.Name) == "string" then
        return Grant_Squishy_Reward(Player, PlayerEntity, Reward.Kind, Reward.Name)
    end

    return false, "InvalidReward"
end

local function Claim_Reward_Index(
    Player: Player,
    PlayerEntity: number,
    RewardIndex: number,
    IgnoreTimer: boolean?
): (boolean, string?)
    local Session = Sessions[Player]
    local Reward = DailyRewards[RewardIndex]

    if not Session or not Reward then
        return false, "InvalidReward"
    end

    if Session.Claimed[RewardIndex] then
        return false, "Claimed"
    end

    if not IgnoreTimer and not Can_Claim_Reward(Session, RewardIndex) then
        return false, "NotReady"
    end

    local Granted, FailureReason = Grant_Reward(Player, PlayerEntity, Reward)

    if not Granted then
        return false, FailureReason
    end

    Session.Claimed[RewardIndex] = true
    Session.LastClaimAt = workspace:GetServerTimeNow()
    ProgressionFunnels.Log_Daily_Reward(PlayerEntity, RewardIndex)

    return true, nil
end

function Daily_Rewards.Claim_All_Ready(PlayerEntity: number): (number, string?)
    local Player = World:get(PlayerEntity, Components.Player)

    if not Player then
        return 0, "MissingPlayer"
    end

    Create_Session(Player, PlayerEntity)

    local Session = Sessions[Player]

    if not Session then
        return 0, "MissingSession"
    end

    local SquishyRewardCount = Count_Unclaimed_Squishy_Rewards(Session)
    local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))

    if SquishyRewardCount > 0 and not InventoryCapacity.CanAddSquishies(OwnedSquishies, SquishyRewardCount) then
        Notify(Player, InventoryCapacity.SquishyInventoryFullMessage, "Error")
        return 0, "InventoryFull"
    end

    local ClaimedCount = 0

    for RewardIndex = 1, #DailyRewards do
        local Claimed = false

        if not Session.Claimed[RewardIndex] then
            Claimed = Claim_Reward_Index(Player, PlayerEntity, RewardIndex, true)
        end

        if Claimed then
            ClaimedCount += 1
        end
    end

    if ClaimedCount > 0 then
        Save_Session_To_Components(Player, PlayerEntity)
        Notify(Player, `Claimed {ClaimedCount} daily rewards!`, "Success")
    end

    return ClaimedCount, nil
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

        Create_Session(Player, PlayerEntity)

        local Session = Sessions[Player]
        local Reward = DailyRewards[RewardIndex]

        if not Session or not Reward then
            return
        end

        local Granted, FailureReason = Claim_Reward_Index(Player, PlayerEntity, RewardIndex)

        if not Granted then
            if FailureReason == "Claimed" then
                Notify(Player, "You already claimed this reward.", "Error")
            elseif FailureReason == "NotReady" then
                Notify(Player, "This reward is not ready yet.", "Error")
            elseif FailureReason ~= "InventoryFull" then
                Log.Warn(`[DailyRewards] Failed to grant reward {RewardIndex} for {Player.Name}`)
                Notify(Player, "Reward failed to claim.", "Error")
            end

            return
        end

        Save_Session_To_Components(Player, PlayerEntity)
        Notify(Player, "Daily reward claimed!", "Success")
    end)

    ActiveClaims[Player.UserId] = nil

    if not Success then
        Log.Warn(`[DailyRewards] Failed to claim reward for {Player.Name}: {Error}`)
    end
end

local function Handle_Claim_Requests()
    for _, Player: Player, RewardIndex: number in Network.ClaimDailyReward.Iter() do
        if not RemoteCooldowns.Allow(Player, "ClaimDailyReward", CLAIM_COOLDOWN_SECONDS) then
            continue
        end

        task.spawn(Handle_Claim_Request, Player, RewardIndex)
    end
end

Players.PlayerRemoving:Connect(function(Player)
    Sessions[Player] = nil
    ActiveClaims[Player.UserId] = nil
end)

Daily_Rewards.name = script.Name
Daily_Rewards.phase = Phases.Runservice.Update
Daily_Rewards.system = function()
    Sync_Sessions()
    Handle_Claim_Requests()
end
Daily_Rewards.runConditions = {}

return Daily_Rewards
