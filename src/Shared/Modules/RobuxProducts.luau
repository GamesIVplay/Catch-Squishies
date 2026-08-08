export type PurchaseKind = "Product" | "GamePass"
export type GrantKind =
    "Cash"
    | "Food"
    | "Lasso"
    | "Squishies"
    | "LuckyBlock"
    | "MoneyMultiplier"
    | "SkipTime"
    | "Restock"
    | "OfflineRewardX5"
    | "ClaimAllDailyRewards"
    | "Pending"

export type SquishyGrantConfig = {
    Kind: "Slime" | "Dumpling",
    Name: string,
}

export type LuckyBlockRewardConfig = SquishyGrantConfig & {
    Weight: number,
}

export type PurchaseConfig = {
    Key: string,
    Kind: PurchaseKind,
    DisplayName: string,
    ProductId: number?,
    GamePassId: number?,
    PriceRobux: number?,
    GrantKind: GrantKind,
    CashAmount: number?,
    FoodName: string?,
    LassoName: string?,
    Squishies: { SquishyGrantConfig }?,
    LuckyBlockRolls: number?,
    LuckyBlockRewards: { LuckyBlockRewardConfig }?,
    MoneyMultiplier: number?,
    SkipTimeSeconds: number?,
}

export type ShopButtonConfig = {
    Key: string,
    Path: { string },
}

local GOLDEN_LUCKY_BLOCK_REWARDS: { LuckyBlockRewardConfig } = {
    { Kind = "Slime", Name = "Ring", Weight = 50 },
    { Kind = "Dumpling", Name = "Snow", Weight = 25 },
    { Kind = "Slime", Name = "Meow", Weight = 15 },
    { Kind = "Slime", Name = "Icicle", Weight = 9 },
    { Kind = "Dumpling", Name = "Mushroom", Weight = 1 },
}

local MONEY_MULTIPLIER_TIERS = table.freeze({ 2, 4, 8, 16, 32, 64 })
local SKIP_TIME_OFFERS = table.freeze({
    {
        Key = "SkipTime5m",
        Label = "Skip 5m",
        Seconds = 60 * 5,
    },
    {
        Key = "SkipTime10m",
        Label = "Skip 10m",
        Seconds = 60 * 10,
    },
    {
        Key = "SkipTime30m",
        Label = "Skip 30m",
        Seconds = 60 * 30,
    },
})

local PRODUCTS: { [string]: PurchaseConfig } = {
    Restock = {
        Key = "Restock",
        Kind = "Product",
        DisplayName = "Restock",
        ProductId = 3609102284,
        GrantKind = "Restock",
    },
    OfflineRewardX5 = {
        Key = "OfflineRewardX5",
        Kind = "Product",
        DisplayName = "x5 Offline Rewards",
        ProductId = 3609175299,
        PriceRobux = 49,
        GrantKind = "OfflineRewardX5",
    },
    ClaimAllDailyRewards = {
        Key = "ClaimAllDailyRewards",
        Kind = "Product",
        DisplayName = "Claim All Daily Rewards",
        ProductId = 3609175316,
        PriceRobux = 49,
        GrantKind = "ClaimAllDailyRewards",
    },
    Cash500K = {
        Key = "Cash500K",
        Kind = "Product",
        DisplayName = "500,000 Cash",
        ProductId = 3608034353,
        GrantKind = "Cash",
        CashAmount = 500_000,
    },
    Cash100K = {
        Key = "Cash100K",
        Kind = "Product",
        DisplayName = "100,000 Cash",
        ProductId = 3608034329,
        GrantKind = "Cash",
        CashAmount = 100_000,
    },
    Cash10K = {
        Key = "Cash10K",
        Kind = "Product",
        DisplayName = "10,000 Cash",
        ProductId = 3608034308,
        GrantKind = "Cash",
        CashAmount = 10_000,
    },
    ProPack = {
        Key = "ProPack",
        Kind = "Product",
        DisplayName = "Lucky Pro Pack",
        ProductId = 3608034181,
        GrantKind = "Squishies",
        Squishies = {
            { Kind = "Slime", Name = "Monke" },
            { Kind = "Dumpling", Name = "Fox" },
            { Kind = "Dumpling", Name = "Catus" },
        },
    },
    StarterPack = {
        Key = "StarterPack",
        Kind = "Product",
        DisplayName = "Starter Pack",
        ProductId = 3608034105,
        GrantKind = "Squishies",
        Squishies = {
            { Kind = "Dumpling", Name = "White" },
            { Kind = "Slime", Name = "Franken" },
            { Kind = "Slime", Name = "Shark" },
        },
    },
    VoidLasso = {
        Key = "VoidLasso",
        Kind = "GamePass",
        DisplayName = "Void Lasso",
        GamePassId = 1899265625,
        GrantKind = "Lasso",
        LassoName = "Void",
    },
    VoidLassoGift = {
        Key = "VoidLassoGift",
        Kind = "Product",
        DisplayName = "Void Lasso",
        ProductId = 3609140992,
        GrantKind = "Lasso",
        LassoName = "Void",
    },
    FarmersFeedFood = {
        Key = "FarmersFeedFood",
        Kind = "Product",
        DisplayName = "Farmers Feed",
        ProductId = 3609095465,
        PriceRobux = 9,
        GrantKind = "Food",
        FoodName = "Farmers Feed",
    },
    HayFood = {
        Key = "HayFood",
        Kind = "Product",
        DisplayName = "Hay",
        ProductId = 3609095497,
        PriceRobux = 19,
        GrantKind = "Food",
        FoodName = "Hay",
    },
    WheatFood = {
        Key = "WheatFood",
        Kind = "Product",
        DisplayName = "Wheat",
        ProductId = 3609095532,
        PriceRobux = 29,
        GrantKind = "Food",
        FoodName = "Wheat",
    },
    CornFood = {
        Key = "CornFood",
        Kind = "Product",
        DisplayName = "Corn",
        ProductId = 3609095575,
        PriceRobux = 39,
        GrantKind = "Food",
        FoodName = "Corn",
    },
    CarrotFood = {
        Key = "CarrotFood",
        Kind = "Product",
        DisplayName = "Carrot",
        ProductId = 3609095618,
        PriceRobux = 49,
        GrantKind = "Food",
        FoodName = "Carrot",
    },
    BerriesFood = {
        Key = "BerriesFood",
        Kind = "Product",
        DisplayName = "Berries",
        ProductId = 3609095668,
        PriceRobux = 59,
        GrantKind = "Food",
        FoodName = "Berries",
    },
    HoneyTreatFood = {
        Key = "HoneyTreatFood",
        Kind = "Product",
        DisplayName = "Honey Treat",
        ProductId = 3609095712,
        PriceRobux = 69,
        GrantKind = "Food",
        FoodName = "Honey Treat",
    },
    FruitBasketFood = {
        Key = "FruitBasketFood",
        Kind = "Product",
        DisplayName = "Fruit Basket",
        ProductId = 3609095796,
        PriceRobux = 79,
        GrantKind = "Food",
        FoodName = "Fruit Basket",
    },
    RainbowFeedFood = {
        Key = "RainbowFeedFood",
        Kind = "Product",
        DisplayName = "Rainbow Feed",
        ProductId = 3609095837,
        PriceRobux = 89,
        GrantKind = "Food",
        FoodName = "Rainbow Feed",
    },
    BasicLasso = {
        Key = "BasicLasso",
        Kind = "Product",
        DisplayName = "Basic Lasso",
        ProductId = 3609094822,
        PriceRobux = 9,
        GrantKind = "Lasso",
        LassoName = "Basic",
    },
    MetalLasso = {
        Key = "MetalLasso",
        Kind = "Product",
        DisplayName = "Metal Lasso",
        ProductId = 3609094867,
        PriceRobux = 19,
        GrantKind = "Lasso",
        LassoName = "Metal",
    },
    RubyLasso = {
        Key = "RubyLasso",
        Kind = "Product",
        DisplayName = "Ruby Lasso",
        ProductId = 3609094895,
        PriceRobux = 39,
        GrantKind = "Lasso",
        LassoName = "Ruby",
    },
    IronLasso = {
        Key = "IronLasso",
        Kind = "Product",
        DisplayName = "Iron Lasso",
        ProductId = 3609094932,
        PriceRobux = 79,
        GrantKind = "Lasso",
        LassoName = "Iron",
    },
    ElmeraldLasso = {
        Key = "ElmeraldLasso",
        Kind = "Product",
        DisplayName = "Elmerald Lasso",
        ProductId = 3609094994,
        PriceRobux = 149,
        GrantKind = "Lasso",
        LassoName = "Elmerald",
    },
    DiamondLasso = {
        Key = "DiamondLasso",
        Kind = "Product",
        DisplayName = "Diamond Lasso",
        ProductId = 3609095107,
        PriceRobux = 299,
        GrantKind = "Lasso",
        LassoName = "Diamond",
    },
    GoldLasso = {
        Key = "GoldLasso",
        Kind = "Product",
        DisplayName = "Gold Lasso",
        ProductId = 3609095162,
        PriceRobux = 499,
        GrantKind = "Lasso",
        LassoName = "Gold",
    },
    LuckyBlock1 = {
        Key = "LuckyBlock1",
        Kind = "Product",
        DisplayName = "x1 Lucky Block",
        ProductId = 3608035904,
        PriceRobux = 199,
        GrantKind = "LuckyBlock",
        LuckyBlockRolls = 1,
        LuckyBlockRewards = GOLDEN_LUCKY_BLOCK_REWARDS,
    },
    LuckyBlock3 = {
        Key = "LuckyBlock3",
        Kind = "Product",
        DisplayName = "x3 Lucky Block",
        ProductId = 3608035945,
        PriceRobux = 400,
        GrantKind = "LuckyBlock",
        LuckyBlockRolls = 3,
        LuckyBlockRewards = GOLDEN_LUCKY_BLOCK_REWARDS,
    },
    LuckyBlock10 = {
        Key = "LuckyBlock10",
        Kind = "Product",
        DisplayName = "x10 Lucky Block",
        ProductId = 3608035965,
        GrantKind = "LuckyBlock",
        LuckyBlockRolls = 10,
        LuckyBlockRewards = GOLDEN_LUCKY_BLOCK_REWARDS,
    },
    SkipTime5m = {
        Key = "SkipTime5m",
        Kind = "Product",
        DisplayName = "Skip 5m",
        ProductId = 3609012958,
        PriceRobux = 16,
        GrantKind = "SkipTime",
        SkipTimeSeconds = 60 * 5,
    },
    SkipTime10m = {
        Key = "SkipTime10m",
        Kind = "Product",
        DisplayName = "Skip 10m",
        ProductId = 3609012976,
        PriceRobux = 32,
        GrantKind = "SkipTime",
        SkipTimeSeconds = 60 * 10,
    },
    SkipTime30m = {
        Key = "SkipTime30m",
        Kind = "Product",
        DisplayName = "Skip 30m",
        ProductId = 3609012991,
        PriceRobux = 64,
        GrantKind = "SkipTime",
        SkipTimeSeconds = 60 * 30,
    },
    MoneyMultiplier2 = {
        Key = "MoneyMultiplier2",
        Kind = "Product",
        DisplayName = "2x Money",
        ProductId = 3609008636,
        PriceRobux = 9,
        GrantKind = "MoneyMultiplier",
        MoneyMultiplier = 2,
    },
    MoneyMultiplier4 = {
        Key = "MoneyMultiplier4",
        Kind = "Product",
        DisplayName = "4x Money",
        ProductId = 3609008662,
        PriceRobux = 39,
        GrantKind = "MoneyMultiplier",
        MoneyMultiplier = 4,
    },
    MoneyMultiplier8 = {
        Key = "MoneyMultiplier8",
        Kind = "Product",
        DisplayName = "8x Money",
        ProductId = 3609008708,
        PriceRobux = 69,
        GrantKind = "MoneyMultiplier",
        MoneyMultiplier = 8,
    },
    MoneyMultiplier16 = {
        Key = "MoneyMultiplier16",
        Kind = "Product",
        DisplayName = "16x Money",
        ProductId = 3609008781,
        PriceRobux = 99,
        GrantKind = "MoneyMultiplier",
        MoneyMultiplier = 16,
    },
    MoneyMultiplier32 = {
        Key = "MoneyMultiplier32",
        Kind = "Product",
        DisplayName = "32x Money",
        ProductId = 3609008800,
        PriceRobux = 129,
        GrantKind = "MoneyMultiplier",
        MoneyMultiplier = 32,
    },
    MoneyMultiplier64 = {
        Key = "MoneyMultiplier64",
        Kind = "Product",
        DisplayName = "64x Money",
        ProductId = 3609008827,
        PriceRobux = 159,
        GrantKind = "MoneyMultiplier",
        MoneyMultiplier = 64,
    },
}

local SHOP_BUTTONS: { ShopButtonConfig } = {
    {
        Key = "LuckyBlock1",
        Path = { "Golden Lucky Block", "Buy 1" },
    },
    {
        Key = "LuckyBlock3",
        Path = { "Golden Lucky Block", "Buy 3" },
    },
    {
        Key = "LuckyBlock10",
        Path = { "Golden Lucky Block", "Buy 10" },
    },
    {
        Key = "StarterPack",
        Path = { "Starter Pack" },
    },
    {
        Key = "VoidLasso",
        Path = { "Void Lasso" },
    },
    {
        Key = "ProPack",
        Path = { "Lucky Pro Pack" },
    },
    {
        Key = "Cash10K",
        Path = { "Cash", "10000 Cash" },
    },
    {
        Key = "Cash100K",
        Path = { "Cash", "100000 Cash" },
    },
    {
        Key = "Cash500K",
        Path = { "Cash", "500000 Cash" },
    },
}

local LASSO_SHOP_BUTTONS: { ShopButtonConfig } = {
    {
        Key = "BasicLasso",
        Path = { "Basic" },
    },
    {
        Key = "MetalLasso",
        Path = { "Metal" },
    },
    {
        Key = "RubyLasso",
        Path = { "Ruby" },
    },
    {
        Key = "IronLasso",
        Path = { "Iron" },
    },
    {
        Key = "ElmeraldLasso",
        Path = { "Elmerald" },
    },
    {
        Key = "DiamondLasso",
        Path = { "Diamond" },
    },
    {
        Key = "GoldLasso",
        Path = { "Gold" },
    },
    {
        Key = "VoidLasso",
        Path = { "Void" },
    },
}

local FOOD_SHOP_BUTTONS: { ShopButtonConfig } = {
    {
        Key = "FarmersFeedFood",
        Path = { "Common" },
    },
    {
        Key = "HayFood",
        Path = { "Rare" },
    },
    {
        Key = "WheatFood",
        Path = { "Epic" },
    },
    {
        Key = "CornFood",
        Path = { "Legendary" },
    },
    {
        Key = "CarrotFood",
        Path = { "Secret" },
    },
    {
        Key = "BerriesFood",
        Path = { "Prismatic" },
    },
    {
        Key = "HoneyTreatFood",
        Path = { "Divine" },
    },
    {
        Key = "FruitBasketFood",
        Path = { "Exotic" },
    },
    {
        Key = "RainbowFeedFood",
        Path = { "Transcendent" },
    },
}

local ProductByProductId: { [number]: PurchaseConfig } = {}
local ProductByGamePassId: { [number]: PurchaseConfig } = {}

for _, Product in PRODUCTS do
    if Product.ProductId then
        ProductByProductId[Product.ProductId] = Product
    end

    if Product.GamePassId then
        ProductByGamePassId[Product.GamePassId] = Product
    end
end

local RobuxProducts = {}

RobuxProducts.Products = table.freeze(PRODUCTS)
RobuxProducts.ShopButtons = table.freeze(SHOP_BUTTONS)
RobuxProducts.LassoShopButtons = table.freeze(LASSO_SHOP_BUTTONS)
RobuxProducts.FoodShopButtons = table.freeze(FOOD_SHOP_BUTTONS)
RobuxProducts.MoneyMultiplierTiers = MONEY_MULTIPLIER_TIERS
RobuxProducts.SkipTimeOffers = SKIP_TIME_OFFERS

function RobuxProducts.Get(Key: string): PurchaseConfig?
    return PRODUCTS[Key]
end

function RobuxProducts.GetByProductId(ProductId: number): PurchaseConfig?
    return ProductByProductId[ProductId]
end

function RobuxProducts.GetByGamePassId(GamePassId: number): PurchaseConfig?
    return ProductByGamePassId[GamePassId]
end

function RobuxProducts.NormalizeMoneyMultiplier(Value: any): number
    if type(Value) ~= "number" then
        return 1
    end

    local Normalized = math.max(1, math.floor(Value))
    local Result = 1

    for _, Tier in MONEY_MULTIPLIER_TIERS do
        if Normalized >= Tier then
            Result = Tier
        end
    end

    return Result
end

function RobuxProducts.GetNextMoneyMultiplier(Value: any): number?
    local CurrentMultiplier = RobuxProducts.NormalizeMoneyMultiplier(Value)

    for _, Tier in MONEY_MULTIPLIER_TIERS do
        if Tier > CurrentMultiplier then
            return Tier
        end
    end

    return nil
end

function RobuxProducts.GetMoneyMultiplierProduct(Multiplier: number): PurchaseConfig?
    return PRODUCTS[`MoneyMultiplier{Multiplier}`]
end

return table.freeze(RobuxProducts)
