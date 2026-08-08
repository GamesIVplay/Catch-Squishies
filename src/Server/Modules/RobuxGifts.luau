local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)

local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)

local RobuxGifts = {}

local PENDING_GIFT_EXPIRY_SECONDS = 120

type PendingGift = {
    TargetUserId: number,
    ProductKey: string,
    ProductId: number,
    CreatedAt: number,
}

local PendingGiftsByBuyerUserId: { [number]: PendingGift } = {}

local function Notify_Player(Player: Player?, Text: string, NotificationType: string?)
    if not Player then
        return
    end

    Network.Notification.Fire(Player, {
        Text = Text,
        Type = NotificationType or "Success",
    })
end

function RobuxGifts.Is_Giftable_Product(Product): boolean
    if type(Product) ~= "table" or Product.Kind ~= "Product" or type(Product.ProductId) ~= "number" then
        return false
    end

    if Product.GrantKind == "Food" and type(Product.FoodName) == "string" then
        return true
    end

    if Product.GrantKind == "Lasso" and type(Product.LassoName) == "string" then
        return true
    end

    return false
end

function RobuxGifts.Prepare_Gift(Player: Player, TargetUserId: number, ProductKey: string): (boolean, number?)
    if type(ProductKey) ~= "string" or ProductKey == "" then
        Notify_Player(Player, "That gift is unavailable.", "Error")
        return false, nil
    end

    local Product = RobuxProducts.Get(ProductKey)

    if not RobuxGifts.Is_Giftable_Product(Product) then
        Notify_Player(Player, "That gift is unavailable.", "Error")
        return false, nil
    end

    TargetUserId = math.floor(TargetUserId)

    if TargetUserId == Player.UserId then
        Notify_Player(Player, "You can't gift yourself.", "Error")
        return false, nil
    end

    local TargetPlayer = Players:GetPlayerByUserId(TargetUserId)

    if not TargetPlayer then
        Notify_Player(Player, "That player left.", "Error")
        return false, nil
    end

    PendingGiftsByBuyerUserId[Player.UserId] = {
        TargetUserId = TargetUserId,
        ProductKey = Product.Key,
        ProductId = Product.ProductId,
        CreatedAt = os.time(),
    }

    return true, Product.ProductId
end

function RobuxGifts.Consume_Pending_Gift(Player: Player, Product): PendingGift?
    if not RobuxGifts.Is_Giftable_Product(Product) then
        return nil
    end

    local PendingGift = PendingGiftsByBuyerUserId[Player.UserId]

    if not PendingGift then
        return nil
    end

    if os.time() - PendingGift.CreatedAt > PENDING_GIFT_EXPIRY_SECONDS then
        PendingGiftsByBuyerUserId[Player.UserId] = nil
        return nil
    end

    if PendingGift.ProductId ~= Product.ProductId or PendingGift.ProductKey ~= Product.Key then
        return nil
    end

    PendingGiftsByBuyerUserId[Player.UserId] = nil
    return PendingGift
end

function RobuxGifts.Notify_Gifted(Buyer: Player, Target: Player, DisplayName: string)
    Notify_Player(Buyer, `Gifted {DisplayName} to {Target.DisplayName}!`)
    Notify_Player(Target, `{Buyer.DisplayName} gifted you {DisplayName}!`)
end

function RobuxGifts.Notify_Purchased(Player: Player, DisplayName: string)
    Notify_Player(Player, `Purchased {DisplayName}!`)
end

Players.PlayerRemoving:Connect(function(Player)
    PendingGiftsByBuyerUserId[Player.UserId] = nil
end)

return table.freeze(RobuxGifts)
