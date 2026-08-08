local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)

local Components = require(ReplicatedStorage.Shared.Components)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local Util = require(ReplicatedStorage.Shared.Modules.Util)
local World = require(ReplicatedStorage.Shared.World)

local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local SkipTimeRewards = require(ServerScriptService.Server.Modules.SkipTimeRewards)

local MIN_OFFLINE_SECONDS = 60
local OFFLINE_REWARD_RATE = 0.1
local CLAIM_REMOTE_COOLDOWN = 0.25

local Offline_Rewards = {}
local CheckedPlayerEntities: { [number]: boolean } = {}

local function Format_Cash(Amount: number): string
    return "$" .. Util.Format_Number_With_Commas(math.max(0, math.floor(Amount)))
end

local function Get_Player_Entity(Player: Player): number?
    local PlayerEntity = Registry.Get("Players", Player)

    if PlayerEntity and World:contains(PlayerEntity) then
        return PlayerEntity
    end

    return nil
end

local function Get_Pending_Offline_Cash(PlayerEntity: number): number
    return math.max(0, math.floor(tonumber(World:get(PlayerEntity, Components.PendingOfflineCash)) or 0))
end

local function Get_Pending_Offline_Seconds(PlayerEntity: number): number
    return math.max(0, math.floor(tonumber(World:get(PlayerEntity, Components.PendingOfflineSeconds)) or 0))
end

local function Send_Offline_Reward(Player: Player?, Amount: number, Seconds: number)
    if not Player then
        return
    end

    Network.OfflineRewardChanged.Fire(Player, {
        Amount = math.max(0, math.floor(Amount)),
        Seconds = math.max(0, math.floor(Seconds)),
    })
end

local function Mark_Checked(PlayerEntity: number)
    CheckedPlayerEntities[PlayerEntity] = true
    World:set(PlayerEntity, Components.LastPlayed, os.time())
end

local function Calculate_Offline_Cash(PlayerEntity: number, OfflineSeconds: number): number
    local NormalValue = SkipTimeRewards.Calculate_Player_Production_Value(PlayerEntity, OfflineSeconds)

    return math.max(0, math.floor((NormalValue or 0) * OFFLINE_REWARD_RATE + 0.5))
end

function Offline_Rewards.Try_Create_Offline_Reward(Player: Player, PlayerEntity: number)
    if CheckedPlayerEntities[PlayerEntity] then
        return
    end

    local PendingCash = Get_Pending_Offline_Cash(PlayerEntity)

    if PendingCash > 0 then
        CheckedPlayerEntities[PlayerEntity] = true
        Send_Offline_Reward(Player, PendingCash, Get_Pending_Offline_Seconds(PlayerEntity))
        return
    end

    local LastPlayed = tonumber(World:get(PlayerEntity, Components.LastPlayed)) or 0

    if LastPlayed <= 0 then
        Mark_Checked(PlayerEntity)
        Send_Offline_Reward(Player, 0, 0)
        return
    end

    local OfflineSeconds = math.max(0, os.time() - math.floor(LastPlayed))

    if OfflineSeconds < MIN_OFFLINE_SECONDS then
        Mark_Checked(PlayerEntity)
        Send_Offline_Reward(Player, 0, OfflineSeconds)
        return
    end

    local OfflineCash = Calculate_Offline_Cash(PlayerEntity, OfflineSeconds)
    Mark_Checked(PlayerEntity)

    if OfflineCash <= 0 then
        Send_Offline_Reward(Player, 0, OfflineSeconds)
        return
    end

    World:set(PlayerEntity, Components.PendingOfflineCash, OfflineCash)
    World:set(PlayerEntity, Components.PendingOfflineSeconds, OfflineSeconds)
    Send_Offline_Reward(Player, OfflineCash, OfflineSeconds)
end

function Offline_Rewards.Claim_Offline_Reward(PlayerEntity: number, Multiplier: number?): (boolean, number)
    local Player = World:get(PlayerEntity, Components.Player)
    local PendingCash = Get_Pending_Offline_Cash(PlayerEntity)

    if PendingCash <= 0 then
        Send_Offline_Reward(Player, 0, 0)
        return false, 0
    end

    local Payout = math.max(0, math.floor(PendingCash * math.max(1, tonumber(Multiplier) or 1)))
    local Cash = math.max(0, math.floor(tonumber(World:get(PlayerEntity, Components.Cash)) or 0))

    World:set(PlayerEntity, Components.PendingOfflineCash, 0)
    World:set(PlayerEntity, Components.PendingOfflineSeconds, 0)
    World:set(PlayerEntity, Components.Cash, Cash + Payout)
    Send_Offline_Reward(Player, 0, 0)

    if Player then
        Network.Notification.Fire(Player, {
            Text = `Claimed {Format_Cash(Payout)} offline cash!`,
            Type = "Success",
        })
    end

    return true, Payout
end

local function Handle_Offline_Reward_Checks()
    for _, Player in Players:GetPlayers() do
        local PlayerEntity = Get_Player_Entity(Player)

        if PlayerEntity then
            Offline_Rewards.Try_Create_Offline_Reward(Player, PlayerEntity)
        end
    end
end

local function Handle_Claim_Offline_Reward_Requests()
    for _, Player: Player in Network.ClaimOfflineReward.Iter() do
        if not RemoteCooldowns.Allow(Player, "ClaimOfflineReward", CLAIM_REMOTE_COOLDOWN) then
            continue
        end

        local PlayerEntity = Get_Player_Entity(Player)

        if PlayerEntity then
            Offline_Rewards.Claim_Offline_Reward(PlayerEntity, 1)
        end
    end
end

Players.PlayerRemoving:Connect(function(Player)
    local PlayerEntity = Registry.Get("Players", Player)

    if PlayerEntity then
        CheckedPlayerEntities[PlayerEntity] = nil
    end
end)

Offline_Rewards.name = script.Name
Offline_Rewards.phase = Phases.Runservice.PreUpdate
Offline_Rewards.system = function()
    Handle_Offline_Reward_Checks()
    Handle_Claim_Offline_Reward_Requests()
end
Offline_Rewards.runConditions = {}

return Offline_Rewards
