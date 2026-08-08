local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)

local Phases = require(ReplicatedStorage.Shared.Phases)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local RobuxGifts = require(ServerScriptService.Server.Modules.RobuxGifts)

local PREPARE_GIFT_COOLDOWN_SECONDS = 0.5

local function Handle_Prepare_Gift_Requests()
    for _, Player: Player, Data in Network.PrepareGift.Iter() do
        if not RemoteCooldowns.Allow(Player, "PrepareGift", PREPARE_GIFT_COOLDOWN_SECONDS) then
            continue
        end

        if type(Data) ~= "table" or type(Data.TargetUserId) ~= "number" or type(Data.ProductKey) ~= "string" then
            continue
        end

        local Prepared, ProductId = RobuxGifts.Prepare_Gift(Player, Data.TargetUserId, Data.ProductKey)

        if Prepared and type(ProductId) == "number" then
            Network.GiftPrepared.Fire(Player, {
                TargetUserId = Data.TargetUserId,
                ProductKey = Data.ProductKey,
                ProductId = ProductId,
            })
        end
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = Handle_Prepare_Gift_Requests,
}
