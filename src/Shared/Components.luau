local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventMutations = require(ReplicatedStorage.Shared.Modules.EventMutations)
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local World = require("./World")

local Components: {
    Player: Jecs.Entity<Player>,
    Renderable: Jecs.Entity<Model>,
    Cleanup: Jecs.Entity<() -> ()>,

    Name: Jecs.Entity<string>,
    Kind: Jecs.Entity<string>,
    SpawnTime: Jecs.Entity<number>,
    Lifetime: Jecs.Entity<number>,
    BaseY: Jecs.Entity<number>,
    Weight: Jecs.Entity<number>,
    Mutation: Jecs.Entity<string>,
    EventMutations: Jecs.Entity<{ string }>,

    Cash: Jecs.Entity<number>,
    MoneyMultiplier: Jecs.Entity<number>,
    Lasso: Jecs.Entity<string>,
    OwnedLassos: Jecs.Entity<{ string }>,
    OwnedSquishies: Jecs.Entity<{ any }>,
    OwnedFood: Jecs.Entity<{ any }>,
    FoodStock: Jecs.Entity<{ [string]: number }>,
    LastFoodRestock: Jecs.Entity<number>,
    HotbarSlots: Jecs.Entity<{ any }>,
    Index: Jecs.Entity<{ string }>,
    ClaimedIndexRewards: Jecs.Entity<{ string }>,
    ClaimedDailyRewards: Jecs.Entity<{ number }>,
    LastDailyRewardClaim: Jecs.Entity<number>,
    LastPlayed: Jecs.Entity<number>,
    PendingOfflineCash: Jecs.Entity<number>,
    PendingOfflineSeconds: Jecs.Entity<number>,
    TutorialStep: Jecs.Entity<number>,
    PlotAreas: Jecs.Entity<{ [string]: boolean }>,
    PlotSquishies: Jecs.Entity<{ any }>,
    FriendBoost: Jecs.Entity<number>,

    LockedBy: Jecs.Entity<number>,
    CatchProgress: Jecs.Entity<number>,
    CatchId: Jecs.Entity<string>,

    Text: Jecs.Entity<string>,
    Duration: Jecs.Entity<number>,
    NotificationType: Jecs.Entity<string>,
    Gradient: Jecs.Entity<string>,

    Singletons: {
        EventState: Jecs.Entity<any>,
    },
    Tags: {
        Networked: Jecs.Entity,
        Plot: Jecs.Entity,
        Notification: Jecs.Entity,
        VoidCollector: Jecs.Entity,
        Roaming: Jecs.Entity,
        WildSquishy: Jecs.Entity,
        ClaimedGroupReward: Jecs.Entity,
    },
    Relationships: {
        Owner: Jecs.Entity,
        Plot: Jecs.Entity,
        Previous: Jecs.Entity,
    },
} =
    {
        Player = World:component(),
        Renderable = World:component(),
        Cleanup = World:component(),

        Name = World:component(),
        Kind = World:component(),
        SpawnTime = World:component(),
        Lifetime = World:component(),
        BaseY = World:component(),
        Weight = World:component(),
        Mutation = World:component(),
        EventMutations = World:component(),

        Cash = World:component(),
        MoneyMultiplier = World:component(),
        Lasso = World:component(),
        OwnedLassos = World:component(),
        OwnedSquishies = World:component(),
        OwnedFood = World:component(),
        FoodStock = World:component(),
        LastFoodRestock = World:component(),
        HotbarSlots = World:component(),
        Index = World:component(),
        ClaimedIndexRewards = World:component(),
        ClaimedDailyRewards = World:component(),
        LastDailyRewardClaim = World:component(),
        LastPlayed = World:component(),
        PendingOfflineCash = World:component(),
        PendingOfflineSeconds = World:component(),
        TutorialStep = World:component(),
        PlotAreas = World:component(),
        PlotSquishies = World:component(),
        FriendBoost = World:component(),

        LockedBy = World:component(),
        CatchProgress = World:component(),
        CatchId = World:component(),

        Text = World:component(),
        Duration = World:component(),
        NotificationType = World:component(),
        Gradient = World:component(),

        Singletons = {
            EventState = World:component(),
        },
        Tags = {
            Networked = World:component(),
            Plot = World:component(),
            Notification = World:component(),
            VoidCollector = World:component(),
            Roaming = World:component(),
            WildSquishy = World:component(),
            ClaimedGroupReward = World:component(),
        },
        Relationships = {
            Owner = World:component(),
            Plot = World:component(),
            Previous = World:component(),
        },
    }

local NETWORKED_ATTRIBUTE_COMPONENTS = {
    {
        Component = Components.Name,
        Attribute = "Name",
    },
    {
        Component = Components.Kind,
        Attribute = "Kind",
    },
    {
        Component = Components.SpawnTime,
        Attribute = "SpawnTime",
    },
    {
        Component = Components.Lifetime,
        Attribute = "Lifetime",
    },
    {
        Component = Components.BaseY,
        Attribute = "BaseY",
    },
    {
        Component = Components.Weight,
        Attribute = "Weight",
    },
    {
        Component = Components.Mutation,
        Attribute = "Mutation",
    },
    {
        Component = Components.LockedBy,
        Attribute = "LockedBy",
    },
    {
        Component = Components.CatchProgress,
        Attribute = "CatchProgress",
    },
    {
        Component = Components.CatchId,
        Attribute = "CatchId",
    },
}

local function Get_Renderable(Entity): Model?
    return World:get(Entity, Components.Renderable)
end

local function Sync_Networked_Attribute(Entity, Component, Attribute: string)
    if not World:has(Entity, Components.Tags.Networked) then
        return
    end

    local Model = Get_Renderable(Entity)

    if not Model then
        return
    end

    Model:SetAttribute(Attribute, World:get(Entity, Component))
end

local function Sync_Networked_Attributes(Entity)
    if not World:has(Entity, Components.Tags.Networked) then
        return
    end

    local Model = Get_Renderable(Entity)

    if not Model then
        return
    end

    Model:SetAttribute("ServerEntity", Entity)

    for _, Mapping in NETWORKED_ATTRIBUTE_COMPONENTS do
        Model:SetAttribute(Mapping.Attribute, World:get(Entity, Mapping.Component))
    end
end

local function Clear_Networked_Attributes(Entity)
    local Model = Get_Renderable(Entity)

    if not Model then
        return
    end

    Model:SetAttribute("ServerEntity", nil)

    for _, Mapping in NETWORKED_ATTRIBUTE_COMPONENTS do
        Model:SetAttribute(Mapping.Attribute, nil)
    end

    Model:SetAttribute("EventMutations", nil)
end

local function Sync_Event_Mutations_Attribute(Entity)
    if not World:has(Entity, Components.Tags.Networked) then
        return
    end

    local Model = Get_Renderable(Entity)

    if Model then
        Model:SetAttribute(
            "EventMutations",
            EventMutations.EncodeAttribute(World:get(Entity, Components.EventMutations))
        )
    end
end

local function Setup_Hooks()
    World:set(Components.Renderable, Jecs.OnAdd, function(Entity)
        Sync_Networked_Attributes(Entity)
        Sync_Event_Mutations_Attribute(Entity)
    end)

    World:set(Components.Renderable, Jecs.OnChange, function(Entity)
        Sync_Networked_Attributes(Entity)
        Sync_Event_Mutations_Attribute(Entity)
    end)

    World:set(Components.Tags.Networked, Jecs.OnAdd, function(Entity)
        Sync_Networked_Attributes(Entity)
        Sync_Event_Mutations_Attribute(Entity)
    end)

    World:set(Components.Tags.Networked, Jecs.OnRemove, function(Entity)
        Clear_Networked_Attributes(Entity)
    end)

    for _, Mapping in NETWORKED_ATTRIBUTE_COMPONENTS do
        World:set(Mapping.Component, Jecs.OnAdd, function(Entity)
            Sync_Networked_Attribute(Entity, Mapping.Component, Mapping.Attribute)
        end)

        World:set(Mapping.Component, Jecs.OnChange, function(Entity)
            Sync_Networked_Attribute(Entity, Mapping.Component, Mapping.Attribute)
        end)

        World:set(Mapping.Component, Jecs.OnRemove, function(Entity)
            local Model = Get_Renderable(Entity)

            if Model then
                Model:SetAttribute(Mapping.Attribute, nil)
            end
        end)
    end

    World:set(Components.EventMutations, Jecs.OnAdd, Sync_Event_Mutations_Attribute)
    World:set(Components.EventMutations, Jecs.OnChange, Sync_Event_Mutations_Attribute)
    World:set(Components.EventMutations, Jecs.OnRemove, function(Entity)
        local Model = Get_Renderable(Entity)

        if Model then
            Model:SetAttribute("EventMutations", nil)
        end
    end)

    World:set(Components.Cleanup, Jecs.OnRemove, function(Entity)
        local Cleanup = World:get(Entity, Components.Cleanup)

        if Cleanup then
            Cleanup()
        end
    end)
end

local function Name_Components(Cts)
    for Name, Component in Cts do
        if type(Component) == "table" then
            Name_Components(Component)
        else
            World:set(Component, Jecs.Name, Name)
        end
    end
end

local function Init_Components()
    World:set(Components.Singletons.EventState, Components.Singletons.EventState, {
        NextEventAt = 0,
        ActiveEvents = {},
    })
end

Setup_Hooks()

Name_Components(Components)

Init_Components()

return table.freeze(Components)
