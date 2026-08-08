local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local Profile = require(ServerScriptService.Server.Modules.Profile)
local ProgressionFunnels = require(ServerScriptService.Server.Modules.ProgressionFunnels)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local TutorialProgress = require(ServerScriptService.Server.Modules.TutorialProgress)

local Components = require(ReplicatedStorage.Shared.Components)
local Log = require(ReplicatedStorage.Shared.Log)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local World = require(ReplicatedStorage.Shared.World)

local FRIEND_BOOST_PER_FRIEND = 10
local PROFILE_COMPONENT_MAP = {
    { ProfileKey = "Cash", Component = Components.Cash },
    { ProfileKey = "MoneyMultiplier", Component = Components.MoneyMultiplier },
    { ProfileKey = "Lasso", Component = Components.Lasso },
    { ProfileKey = "OwnedLassos", Component = Components.OwnedLassos },
    { ProfileKey = "OwnedSquishies", Component = Components.OwnedSquishies },
    { ProfileKey = "OwnedFood", Component = Components.OwnedFood },
    { ProfileKey = "FoodStock", Component = Components.FoodStock },
    { ProfileKey = "LastFoodRestock", Component = Components.LastFoodRestock },
    { ProfileKey = "HotbarSlots", Component = Components.HotbarSlots },
    { ProfileKey = "Index", Component = Components.Index },
    { ProfileKey = "ClaimedIndexRewards", Component = Components.ClaimedIndexRewards },
    { ProfileKey = "ClaimedDailyRewards", Component = Components.ClaimedDailyRewards },
    { ProfileKey = "LastDailyRewardClaim", Component = Components.LastDailyRewardClaim },
    { ProfileKey = "LastPlayed", Component = Components.LastPlayed },
    { ProfileKey = "PendingOfflineCash", Component = Components.PendingOfflineCash },
    { ProfileKey = "PendingOfflineSeconds", Component = Components.PendingOfflineSeconds },
    { ProfileKey = "TutorialStep", Component = Components.TutorialStep },
    { ProfileKey = "PlotAreas", Component = Components.PlotAreas },
    { ProfileKey = "PlotSquishies", Component = Components.PlotSquishies },
}

local PlayerRemovingConnection: RBXScriptConnection? = nil
local UpdatingFriendBoosts = false
local PendingFriendBoostUpdate = false

local function Register_Collision_Groups()
    PhysicsService:RegisterCollisionGroup("Character")
    PhysicsService:RegisterCollisionGroup("Debris")

    PhysicsService:CollisionGroupSetCollidable("Character", "Debris", false)
    PhysicsService:CollisionGroupSetCollidable("Character", "Character", false)
end

Register_Collision_Groups()

local function Update_Character_Collision_Groups(Character: Model)
    for _, Part in Character:GetDescendants() do
        if not Part:IsA("BasePart") then
            continue
        end

        Part.CollisionGroup = "Character"
    end
end

local function Character_Appearance_Loaded(Player_Entity: number, Character: Model)
    Update_Character_Collision_Groups(Character)

    Character.Parent = workspace:FindFirstChild("Characters") or workspace

    World:set(Player_Entity, Components.Renderable, Character)
end

local function Update_Friend_Boosts()
    if UpdatingFriendBoosts then
        PendingFriendBoostUpdate = true
        return
    end

    UpdatingFriendBoosts = true

    repeat
        PendingFriendBoostUpdate = false

        local PlayerList = Players:GetPlayers()

        for _, Player in PlayerList do
            local Player_Entity = Registry.Get("Players", Player)

            if not Player_Entity or not World:contains(Player_Entity) then
                continue
            end

            local FriendCount = 0

            for _, TargetPlayer in PlayerList do
                if TargetPlayer == Player then
                    continue
                end

                local TargetPlayer_Entity = Registry.Get("Players", TargetPlayer)

                if not TargetPlayer_Entity or not World:contains(TargetPlayer_Entity) then
                    continue
                end

                local Success, IsFriend = pcall(function()
                    return Player:IsFriendsWithAsync(TargetPlayer.UserId)
                end)

                if Success and IsFriend then
                    FriendCount += 1
                end
            end

            World:set(Player_Entity, Components.FriendBoost, FriendCount * FRIEND_BOOST_PER_FRIEND)
        end
    until not PendingFriendBoostUpdate

    UpdatingFriendBoosts = false
end

local function Save_Back_To_Profile(Player_Entity: number, Profile_Data: Profile.ProfileData)
    World:set(Player_Entity, Components.LastPlayed, os.time())

    for _, Mapping in PROFILE_COMPONENT_MAP do
        Profile_Data[Mapping.ProfileKey] = World:get(Player_Entity, Mapping.Component)
    end

    if World:has(Player_Entity, Components.Tags.ClaimedGroupReward) then
        Profile_Data.ClaimedGroupReward = true
    end
end

local function Load_Profile_Data_To_Entity(Player_Entity: number, Profile_Data: Profile.ProfileData)
    for _, Mapping in PROFILE_COMPONENT_MAP do
        World:set(Player_Entity, Mapping.Component, Profile_Data[Mapping.ProfileKey])
    end

    if Profile_Data.ClaimedGroupReward then
        World:add(Player_Entity, Components.Tags.ClaimedGroupReward)
    end
end

local function Handle_New_Player(Player: Player)
    if Registry.Get("Players", Player) ~= nil then
        return
    end

    local Player_Profile = Profile.Load(Player)

    if not Player_Profile then
        return
    end

    local Profile_Data = Player_Profile.Data

    local Player_Entity = World:entity()
    Registry.Define("Players", Player, Player_Entity)

    World:set(Player_Entity, Components.Player, Player)
    World:set(Player_Entity, Components.Name, Player.Name)
    World:set(Player_Entity, Components.FriendBoost, 0)

    Load_Profile_Data_To_Entity(Player_Entity, Profile_Data)
    TutorialProgress.Initialize(Player_Entity)
    ProgressionFunnels.Initialize(Player_Entity)

    World:set(Player_Entity, Components.Cleanup, function()
        ProgressionFunnels.Cleanup(Player_Entity)
        Profile.Unload(Player)
        Registry.Undefine("Players", Player)
        Log.Info(`Cleaned up {Player.Name}'s entity`)
    end)

    if Player.Character then
        Character_Appearance_Loaded(Player_Entity, Player.Character)
    end

    Player.CharacterAppearanceLoaded:Connect(function(Character)
        if not World:contains(Player_Entity) then
            return
        end

        Character_Appearance_Loaded(Player_Entity, Character)
    end)

    Player.CharacterRemoving:Connect(function()
        if World:contains(Player_Entity) then
            World:remove(Player_Entity, Components.Renderable)
        end
    end)

    if _G.IN_DEV then
        Network.Notification.Fire(Player, {
            Text = "Development Mode Enabled",
            Type = "Info",
        })
    end

    if _G.Mock then
        Network.Notification.Fire(Player, {
            Text = "Mock Saving Active",
            Type = "Warning",
        })
    end

    Log.Info(`Setup {Player.Name}'s entity`)
    task.spawn(Update_Friend_Boosts)

    -- Update leaderboard in new thread when live saving is enabled.
end

local function Handle_Leaving_Player(Player: Player)
    local Player_Entity = Registry.Get("Players", Player)
    if not Player_Entity then
        return
    end

    local Player_Profile = Profile.Get(Player)

    if Player_Profile then
        Save_Back_To_Profile(Player_Entity, Player_Profile.Data)
    end

    TutorialProgress.Cleanup(Player_Entity)

    -- Update leaderboard data when live saving is enabled.

    Registry.Delete("Players", Player)
    task.spawn(Update_Friend_Boosts)
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = function()
        for _, Player: Player in Network.ClientLoaded.Iter() do
            if not RemoteCooldowns.Allow(Player, "ClientLoaded") then
                continue
            end

            task.spawn(Handle_New_Player, Player)
        end

        if not PlayerRemovingConnection then
            PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(Player)
                task.spawn(Handle_Leaving_Player, Player)
            end)
        end
    end,
}
