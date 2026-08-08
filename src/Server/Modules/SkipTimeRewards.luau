local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)

local Components = require(ReplicatedStorage.Shared.Components)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Log = require(ReplicatedStorage.Shared.Log)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local Util = require(ReplicatedStorage.Shared.Modules.Util)
local World = require(ReplicatedStorage.Shared.World)

local PROMPT_COOLDOWN = 2
local LastPromptAtByPlayer: { [Player]: number } = {}

local SkipTimeRewards = {}

local function Format_Cash(Value: number): string
    return "$" .. Util.Abbreviate_Number(math.max(0, math.floor(Value + 0.5)), 1)
end

local function Format_Minutes(Seconds: number): string
    return `{math.max(1, math.floor(Seconds / 60 + 0.5))}m`
end

local function Add_Cash(PlayerEntity: number, Amount: number)
    local Cash = World:get(PlayerEntity, Components.Cash) or 0

    World:set(PlayerEntity, Components.Cash, math.max(0, math.floor(Cash + Amount)))
end

function SkipTimeRewards.Calculate_Player_Production_Value(PlayerEntity: number?, Seconds: number): number
    if not PlayerEntity or not World:contains(PlayerEntity) then
        return 0
    end

    local Duration = math.max(0, tonumber(Seconds) or 0)

    if Duration <= 0 then
        return 0
    end

    local PlotSquishies = World:get(PlayerEntity, Components.PlotSquishies)

    if type(PlotSquishies) ~= "table" then
        return 0
    end

    local Multiplier = RobuxProducts.NormalizeMoneyMultiplier(World:get(PlayerEntity, Components.MoneyMultiplier))
    local Total = 0

    for _, Item in PlotSquishies do
        if type(Item) == "table" then
            Total += InventoryMath.GetFinalIncomePerSec(Item) * Multiplier * Duration
        end
    end

    return math.max(0, math.floor(Total + 0.5))
end

function SkipTimeRewards.Grant(Player: Player, PlayerEntity: number, Seconds: number): boolean
    local Generated = SkipTimeRewards.Calculate_Player_Production_Value(PlayerEntity, Seconds)

    Add_Cash(PlayerEntity, Generated)
    Network.Notification.Fire(Player, {
        Text = `Skipped {Format_Minutes(Seconds)} and added {Format_Cash(Generated)}.`,
        Duration = 4,
        Type = "Success" :: any,
    })

    return true
end

local function Select_Time_Offer(PlayerEntity: number, MissingCash: number)
    local BestOffer = RobuxProducts.SkipTimeOffers[#RobuxProducts.SkipTimeOffers]
    local BestGenerated = -1

    for _, Offer in RobuxProducts.SkipTimeOffers do
        local Generated = SkipTimeRewards.Calculate_Player_Production_Value(PlayerEntity, Offer.Seconds)

        if Generated >= MissingCash then
            return Offer
        end

        if Generated > BestGenerated then
            BestOffer = Offer
            BestGenerated = Generated
        end
    end

    return BestOffer
end

function SkipTimeRewards.PromptShortfall(
    Player: Player,
    PlayerEntity: number,
    CurrentCash: number?,
    Cost: number?
): boolean
    local Cash = math.max(0, math.floor(tonumber(CurrentCash) or 0))
    local Price = math.max(0, math.floor(tonumber(Cost) or 0))
    local MissingCash = Price - Cash

    if MissingCash <= 0 then
        return false
    end

    local Now = os.clock()

    if LastPromptAtByPlayer[Player] and Now - LastPromptAtByPlayer[Player] < PROMPT_COOLDOWN then
        return false
    end

    local Offer = Select_Time_Offer(PlayerEntity, MissingCash)
    local Product = Offer and RobuxProducts.Get(Offer.Key)

    if not Product or type(Product.ProductId) ~= "number" then
        return false
    end

    LastPromptAtByPlayer[Player] = Now

    task.spawn(function()
        local Success, Error =
            pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Player, Product.ProductId)

        if not Success then
            Log.Warn(`[SkipTimeRewards] Failed to prompt {Product.DisplayName}: {Error}`)
        end
    end)

    return true
end

Players.PlayerRemoving:Connect(function(Player)
    LastPromptAtByPlayer[Player] = nil
end)

return table.freeze(SkipTimeRewards)
