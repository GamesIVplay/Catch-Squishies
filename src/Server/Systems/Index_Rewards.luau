local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)

local Components = require(ReplicatedStorage.Shared.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Log)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local Util = require(ReplicatedStorage.Shared.Modules.Util)
local World = require(ReplicatedStorage.Shared.World)

local Ratelimit = require(ReplicatedStorage.Packages.Ratelimit)

local CLAIM_COOLDOWN_SECONDS = 0.05
local ClaimRateLimit = Ratelimit(1, CLAIM_COOLDOWN_SECONDS)
local ActiveClaims: { [number]: boolean } = {}

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

local function Get_Index_Reward_Seconds(): number
    local IndexConfig = Config.Index
    local Seconds = if type(IndexConfig) == "table" then IndexConfig.ClaimRewardSeconds else nil

    if type(Seconds) ~= "number" or Seconds ~= Seconds then
        return 180
    end

    return math.max(0, Seconds)
end

local function Is_In_List(List: any, Key: string): boolean
    if type(List) ~= "table" then
        return false
    end

    return table.find(List, Key) ~= nil
end

local function Normalize_Claimed_Rewards(PlayerEntity: number, Index: { string }): { string }
    local Indexed = {}
    local Result = {}
    local Seen = {}
    local ClaimedIndexRewards = World:get(PlayerEntity, Components.ClaimedIndexRewards)

    for _, Key in Index do
        Indexed[Key] = true
    end

    if type(ClaimedIndexRewards) == "table" then
        for _, Key in ClaimedIndexRewards do
            if type(Key) ~= "string" or Seen[Key] or not Indexed[Key] then
                continue
            end

            Seen[Key] = true
            table.insert(Result, Key)
        end
    end

    table.sort(Result)

    return Result
end

local function Get_Normalized_Index(PlayerEntity: number): { string }
    local CurrentIndex = World:get(PlayerEntity, Components.Index)
    local Result = {}
    local Seen = {}

    if type(CurrentIndex) == "table" then
        for _, Key in CurrentIndex do
            if type(Key) ~= "string" or Seen[Key] or not Squishies.GetDataFromKey(Key) then
                continue
            end

            Seen[Key] = true
            table.insert(Result, Key)
        end
    end

    table.sort(Result)

    if #Result ~= (type(CurrentIndex) == "table" and #CurrentIndex or 0) then
        World:set(PlayerEntity, Components.Index, Result)
    end

    return Result
end

local function Get_Reward_Value(Key: string): number?
    local SquishyData = Squishies.GetDataFromKey(Key)

    if not SquishyData or type(SquishyData.IncomePerSec) ~= "number" then
        return nil
    end

    return math.max(0, math.floor(SquishyData.IncomePerSec * Get_Index_Reward_Seconds() + 0.5))
end

local function Handle_Claim_Index_Reward(Player: Player, Key: string)
    if type(Key) ~= "string" or Key == "" then
        return
    end

    if not ClaimRateLimit(Player.UserId) or ActiveClaims[Player.UserId] then
        return
    end

    ActiveClaims[Player.UserId] = true

    local Success, Error = pcall(function()
        local PlayerEntity = Registry.Get("Players", Player)

        if not PlayerEntity or not World:contains(PlayerEntity) then
            return
        end

        local SquishyData, _, SquishyName = Squishies.GetDataFromKey(Key)

        if not SquishyData or not SquishyName then
            Notify(Player, "Unknown index reward.", "Error")
            return
        end

        local Index = Get_Normalized_Index(PlayerEntity)

        if not Is_In_List(Index, Key) then
            Notify(Player, "Discover this squishy first.", "Error")
            return
        end

        local ClaimedIndexRewards = Normalize_Claimed_Rewards(PlayerEntity, Index)

        if Is_In_List(ClaimedIndexRewards, Key) then
            Notify(Player, "Index reward already claimed.", "Info")
            return
        end

        local RewardValue = Get_Reward_Value(Key)

        if not RewardValue or RewardValue <= 0 then
            Notify(Player, "Index reward failed.", "Error")
            return
        end

        table.insert(ClaimedIndexRewards, Key)
        table.sort(ClaimedIndexRewards)

        World:set(PlayerEntity, Components.Cash, (World:get(PlayerEntity, Components.Cash) or 0) + RewardValue)
        World:set(PlayerEntity, Components.ClaimedIndexRewards, ClaimedIndexRewards)

        Notify(Player, `Claimed ${Util.Abbreviate_Number(RewardValue, 1)} for {SquishyName}.`, "Success")
    end)

    ActiveClaims[Player.UserId] = nil

    if not Success then
        Log.Warn(`[IndexRewards] Failed to claim reward for {Player.Name}: {Error}`)
    end
end

Players.PlayerRemoving:Connect(function(Player)
    ActiveClaims[Player.UserId] = nil
end)

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        for _, Player: Player, Key: string in Network.ClaimIndexReward.Iter() do
            if not RemoteCooldowns.Allow(Player, "ClaimIndexReward", CLAIM_COOLDOWN_SECONDS) then
                continue
            end

            task.spawn(Handle_Claim_Index_Reward, Player, Key)
        end
    end,
    runConditions = {},
}
