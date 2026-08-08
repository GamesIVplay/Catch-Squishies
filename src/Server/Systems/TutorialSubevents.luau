local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local TutorialProgress = require(ServerScriptService.Server.Modules.TutorialProgress)

local Components = require(ReplicatedStorage.Shared.Components)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local World = require(ReplicatedStorage.Shared.World)

local REACHED_TARGET_DISTANCE = 28
local REACHED_PLOT_DISTANCE = 22
local REACHED_FEED_DISTANCE = 20
local SELECTED_INVENTORY_SLOT_ATTRIBUTE = "ServerEquippedInventorySlot"
local PLOT_SQUISHY_FOLDER_NAME = "PlotSquishies"

local SUBEVENT_ALLOWED_STEPS = {
    ReachedFirstTutorialSquishy = {
        TutorialSteps.CatchFirst,
        TutorialSteps.PlaceFirst,
    },
    ReachedPlotFirst = {
        TutorialSteps.PlaceFirst,
        TutorialSteps.CollectCash,
    },
    OpenedLassoShop = {
        TutorialSteps.BuyNextLasso,
        TutorialSteps.CatchStrong,
    },
    ReachedStrongTutorialSquishy = {
        TutorialSteps.CatchStrong,
    },
    ReachedPlotStrong = {
        TutorialSteps.CatchStrong,
    },
    OpenedFoodShop = {
        TutorialSteps.FeedStrong,
    },
    EquippedFarmersFeed = {
        TutorialSteps.FeedStrong,
    },
    ReachedFeedTarget = {
        TutorialSteps.FeedStrong,
    },
}

local function Get_Player_Entity(Player: Player): number?
    local Entity = Registry.Get("Players", Player)

    if not Entity or not World:contains(Entity) then
        return nil
    end

    return Entity
end

local function Get_Character_Root(Player: Player): BasePart?
    local Character = Player.Character
    local Root = Character and (Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart)

    return if Root and Root:IsA("BasePart") then Root else nil
end

local function Get_Flat_Distance(Left: Vector3, Right: Vector3): number
    return Vector3.new(Left.X - Right.X, 0, Left.Z - Right.Z).Magnitude
end

local function Is_Step_Allowed(CurrentStep: number, SubeventName: string): boolean
    local AllowedSteps = SUBEVENT_ALLOWED_STEPS[SubeventName]

    if type(AllowedSteps) ~= "table" then
        return false
    end

    for _, Step in AllowedSteps do
        if CurrentStep == Step then
            return true
        end
    end

    return false
end

local function Get_Instance_Position(InstanceToCheck: Instance?): Vector3?
    if not InstanceToCheck then
        return nil
    end

    if InstanceToCheck:IsA("BasePart") then
        return InstanceToCheck.Position
    end

    if InstanceToCheck:IsA("Attachment") then
        return InstanceToCheck.WorldPosition
    end

    if InstanceToCheck:IsA("Model") then
        return InstanceToCheck:GetPivot().Position
    end

    local Part = InstanceToCheck:FindFirstChildWhichIsA("BasePart", true)

    return if Part then Part.Position else nil
end

local function Is_Player_Near_Position(Player: Player, Position: Vector3?, MaxDistance: number): boolean
    local Root = Get_Character_Root(Player)

    return Root ~= nil and Position ~= nil and Get_Flat_Distance(Root.Position, Position) <= MaxDistance
end

local function Find_Tutorial_Target(Player: Player, TargetStep: number): Model?
    local Folder = workspace:FindFirstChild("RoamingSquishies")

    if not Folder then
        return nil
    end

    for _, Child in Folder:GetChildren() do
        if
            Child:IsA("Model")
            and Child:GetAttribute(TutorialSteps.TargetUserIdAttribute) == Player.UserId
            and Child:GetAttribute(TutorialSteps.TargetStepAttribute) == TargetStep
        then
            return Child
        end
    end

    return nil
end

local function Get_Player_Plot(PlayerEntity: number): Instance?
    local PlotEntity = World:target(PlayerEntity, Components.Relationships.Plot)
    local Plot = PlotEntity and World:get(PlotEntity, Components.Renderable)

    return if Plot and Plot:IsA("Model") then Plot else nil
end

local function Get_Plot_Spawn_Target(Plot: Instance?): Instance?
    local Spawn = Plot and Plot:FindFirstChild("Spawn", true)

    if not Spawn or not Spawn:IsA("BasePart") then
        return nil
    end

    for _, Name in { "TutorialTargetAttachment", "TutorialAttachment", "Attachment" } do
        local Attachment = Spawn:FindFirstChild(Name)

        if Attachment and Attachment:IsA("Attachment") then
            return Attachment
        end
    end

    return Spawn
end

local function Get_Selected_Hotbar_Assignment(PlayerEntity: number, Player: Player): any?
    local SlotName = Player:GetAttribute(SELECTED_INVENTORY_SLOT_ATTRIBUTE)

    if type(SlotName) ~= "string" then
        return nil
    end

    local Slot = tonumber(SlotName) or tonumber(string.match(SlotName, "^Item%s+(%d+)$"))

    if not Slot then
        return nil
    end

    local HotbarSlots = World:get(PlayerEntity, Components.HotbarSlots)

    if type(HotbarSlots) ~= "table" then
        return nil
    end

    local Direct = HotbarSlots[tostring(Slot)] or HotbarSlots[Slot]

    if type(Direct) == "table" then
        return Direct
    end

    for _, Assignment in HotbarSlots do
        if type(Assignment) == "table" and Assignment.Slot == Slot then
            return Assignment
        end
    end

    return nil
end

local function Is_Farmers_Feed_Equipped(Player: Player, PlayerEntity: number): boolean
    local Assignment = Get_Selected_Hotbar_Assignment(PlayerEntity, Player)

    return type(Assignment) == "table" and Assignment.ItemType == "Food" and Assignment.ItemId == TutorialSteps.FeedName
end

local function Find_Tutorial_Plot_Squishy(Player: Player, Role: string): Model?
    local Folder = workspace:FindFirstChild(PLOT_SQUISHY_FOLDER_NAME)

    if not Folder then
        return nil
    end

    for _, Child in Folder:GetChildren() do
        if
            Child:IsA("Model")
            and Child:GetAttribute("PlotSquishyOwnerUserId") == Player.UserId
            and Child:GetAttribute("TutorialRole") == Role
        then
            return Child
        end
    end

    return nil
end

local function Has_Tutorial_Role(PlayerEntity: number, Component: any, Role: string): boolean
    local Items = World:get(PlayerEntity, Component)

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

local function Validate_Subevent(Player: Player, PlayerEntity: number, SubeventName: string): boolean
    local CurrentStep = TutorialProgress.Get(PlayerEntity)

    if TutorialSteps.Is_Complete(CurrentStep) or not Is_Step_Allowed(CurrentStep, SubeventName) then
        return false
    end

    if SubeventName == "ReachedFirstTutorialSquishy" then
        return Is_Player_Near_Position(
            Player,
            Get_Instance_Position(Find_Tutorial_Target(Player, TutorialSteps.CatchFirst)),
            REACHED_TARGET_DISTANCE
        )
    end

    if SubeventName == "ReachedStrongTutorialSquishy" then
        if Has_Tutorial_Role(PlayerEntity, Components.OwnedSquishies, TutorialSteps.StrongRole) then
            return false
        end

        return Is_Player_Near_Position(
            Player,
            Get_Instance_Position(Find_Tutorial_Target(Player, TutorialSteps.CatchStrong)),
            REACHED_TARGET_DISTANCE
        )
    end

    if
        SubeventName == "ReachedPlotStrong"
        and not Has_Tutorial_Role(PlayerEntity, Components.OwnedSquishies, TutorialSteps.StrongRole)
    then
        return false
    end

    if SubeventName == "ReachedPlotFirst" or SubeventName == "ReachedPlotStrong" then
        local Plot = Get_Player_Plot(PlayerEntity)

        return Is_Player_Near_Position(
            Player,
            Get_Instance_Position(Get_Plot_Spawn_Target(Plot)),
            REACHED_PLOT_DISTANCE
        )
    end

    if SubeventName == "EquippedFarmersFeed" then
        return Is_Farmers_Feed_Equipped(Player, PlayerEntity)
    end

    if SubeventName == "ReachedFeedTarget" then
        return Is_Player_Near_Position(
            Player,
            Get_Instance_Position(Find_Tutorial_Plot_Squishy(Player, TutorialSteps.StrongRole)),
            REACHED_FEED_DISTANCE
        )
    end

    return SubeventName == "OpenedLassoShop" or SubeventName == "OpenedFoodShop"
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = function()
        for _, Player, SubeventName in Network.TutorialSubevent.Iter() do
            if not TutorialSteps.Get_Subevent_Data(SubeventName) then
                continue
            end

            if not RemoteCooldowns.Allow(Player, `TutorialSubevent:{SubeventName}`, 0.5) then
                continue
            end

            local PlayerEntity = Get_Player_Entity(Player)

            if not PlayerEntity then
                continue
            end

            if Validate_Subevent(Player, PlayerEntity, SubeventName) then
                TutorialProgress.Log_Subevent(PlayerEntity, SubeventName)
            end
        end
    end,
    runConditions = {},
}
