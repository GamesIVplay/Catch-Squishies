local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedFirst.Network)
local Phases = require(ReplicatedStorage.Shared.Phases)

local PlayBuyEffect = require(script.Parent.Parent.Modules.BuyEffect)
local PlayRobuxPurchaseEffect = require(script.Parent.Parent.Modules.RobuxPurchaseEffect)
local LocalPlayer = Players.LocalPlayer

local function Play_Effect_For_Player(UserId: number, PlayEffect: (Model?, any?) -> ())
    local Player = Players:GetPlayerByUserId(UserId)

    if not Player then
        return
    end

    PlayEffect(Player.Character, {
        PlaySound = UserId == LocalPlayer.UserId,
    })
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = function()
        for _, Data in Network.BuyEffect.Iter() do
            Play_Effect_For_Player(Data.PlayerUserId, PlayBuyEffect)
        end

        for _, Data in Network.RobuxPurchaseEffect.Iter() do
            Play_Effect_For_Player(Data.PlayerUserId, PlayRobuxPurchaseEffect)
        end
    end,
    runConditions = {},
}
