local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local ProgressionFunnels = require(ServerScriptService.Server.Modules.ProgressionFunnels)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local TutorialProgress = require(ServerScriptService.Server.Modules.TutorialProgress)

local Components = require(ReplicatedStorage.Shared.Components)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local SkipTimeRewards = require(ServerScriptService.Server.Modules.SkipTimeRewards)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local World = require(ReplicatedStorage.Shared.World)

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

local function Normalize_Player_Lassos(Entity: number): (string, { string })
    local OwnedLassos = Lassos.Normalize_Owned(World:get(Entity, Components.OwnedLassos))
    local SelectedLasso = Lassos.Normalize_Selected(World:get(Entity, Components.Lasso), OwnedLassos)

    World:set(Entity, Components.OwnedLassos, OwnedLassos)
    World:set(Entity, Components.Lasso, SelectedLasso)

    return SelectedLasso, OwnedLassos
end

local function Complete_Tutorial(Player: Player, Entity: number)
    if not TutorialProgress.Complete_Step(Entity, TutorialSteps.BuyNextLasso, TutorialSteps.Complete) then
        return
    end

    Network.TutorialCompleteEffect.FireAll({
        PlayerUserId = Player.UserId,
    })
end

local function Can_Use_Lasso_Shop(Entity: number, LassoName: string): boolean
    if TutorialProgress.Is_Complete(Entity) then
        return true
    end

    return TutorialProgress.Get(Entity) == TutorialSteps.BuyNextLasso and LassoName == TutorialSteps.NextLasso
end

local function Handle_Equip_Lasso(Player: Player, LassoName: string)
    local LassoData = Lassos.Get(LassoName)

    if not LassoData then
        Notify(Player, "Unknown lasso.", "Error")
        return
    end

    local Entity = Get_Player_Entity(Player)

    if not Entity then
        return
    end

    if not Can_Use_Lasso_Shop(Entity, LassoData.Name) then
        Notify(Player, TutorialSteps.BlockedMessage, "Error")
        return
    end

    local SelectedLasso, OwnedLassos = Normalize_Player_Lassos(Entity)

    if not Lassos.Is_Owned(OwnedLassos, LassoData.Name) then
        Notify(Player, "You do not own that lasso yet.", "Error")
        return
    end

    if SelectedLasso == LassoData.Name then
        if LassoData.Name == TutorialSteps.NextLasso then
            Complete_Tutorial(Player, Entity)
        end

        return
    end

    World:set(Entity, Components.Lasso, LassoData.Name)
    if LassoData.Name == TutorialSteps.NextLasso then
        Complete_Tutorial(Player, Entity)
    end
    Notify(Player, `Equipped {LassoData.DisplayName}.`, "Success")
end

local function Handle_Buy_Lasso(Player: Player, LassoName: string)
    local LassoData = Lassos.Get(LassoName)

    if not LassoData then
        Notify(Player, "Unknown lasso.", "Error")
        return
    end

    local Entity = Get_Player_Entity(Player)

    if not Entity then
        return
    end

    if not Can_Use_Lasso_Shop(Entity, LassoData.Name) then
        Notify(Player, TutorialSteps.BlockedMessage, "Error")
        return
    end

    local _, OwnedLassos = Normalize_Player_Lassos(Entity)

    if Lassos.Is_Owned(OwnedLassos, LassoData.Name) then
        Handle_Equip_Lasso(Player, LassoData.Name)
        return
    end

    if LassoData.RobuxOnly then
        Notify(Player, "This lasso is limited.", "Error")
        return
    end

    local Cash = World:get(Entity, Components.Cash) or 0
    local IsTutorialBuy = TutorialProgress.Get(Entity) == TutorialSteps.BuyNextLasso
        and LassoData.Name == TutorialSteps.NextLasso
    local Price = if IsTutorialBuy then 0 else LassoData.Price

    if Cash < Price then
        SkipTimeRewards.PromptShortfall(Player, Entity, Cash, Price)
        Notify(Player, "Not enough cash.", "Error")
        return
    end

    if Price > 0 then
        World:set(Entity, Components.Cash, Cash - Price)
    end

    local UpdatedOwnedLassos = Lassos.Add_Owned(OwnedLassos, LassoData.Name)

    World:set(Entity, Components.OwnedLassos, UpdatedOwnedLassos)
    World:set(Entity, Components.Lasso, LassoData.Name)
    ProgressionFunnels.Log_Lassos(Entity, UpdatedOwnedLassos)

    if LassoData.Name == TutorialSteps.NextLasso then
        Complete_Tutorial(Player, Entity)
    end
    Notify(Player, `Bought and equipped {LassoData.DisplayName}.`, "Success")
    Network.CollectEffect.FireAll({
        PlayerUserId = Player.UserId,
        ItemId = "",
    })
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = function()
        for _, Player, LassoName in Network.BuyLasso.Iter() do
            if not RemoteCooldowns.Allow(Player, "BuyLasso") then
                continue
            end

            Handle_Buy_Lasso(Player, LassoName)
        end

        for _, Player, LassoName in Network.EquipLasso.Iter() do
            if not RemoteCooldowns.Allow(Player, "EquipLasso") then
                continue
            end

            Handle_Equip_Lasso(Player, LassoName)
        end
    end,
    runConditions = {},
}
