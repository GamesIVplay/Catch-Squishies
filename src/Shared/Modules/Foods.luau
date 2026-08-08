export type FoodData = {
    Name: string,
    DisplayName: string,
    Rarity: string,
    Image: string,
    XPValue: number,
    XPMin: number,
    XPMax: number,
    Price: number,
    MinimumRestock: number,
    MaximumRestock: number,
    RestockChance: number,
    RobuxProductId: number?,
    ShopCardName: string?,
    Stackable: boolean?,
}

local FOOD_ORDER = {
    "Farmers Feed",
    "Hay",
    "Wheat",
    "Corn",
    "Carrot",
    "Berries",
    "Honey Treat",
    "Fruit Basket",
    "Rainbow Feed",
}

local FOOD_ALIASES: { [string]: string } = {
    Carrots = "Carrot",
}

local FOODS: { [string]: FoodData } = {
    ["Farmers Feed"] = {
        Name = "Farmers Feed",
        DisplayName = "Farmers Feed",
        Rarity = "Common",
        Image = "rbxassetid://104625061331123",
        XPValue = 1,
        XPMin = 1,
        XPMax = 1,
        Price = 75,
        MinimumRestock = 10,
        MaximumRestock = 20,
        RestockChance = 100 / 100,
        RobuxProductId = 3609095465,
        ShopCardName = "Common",
        Stackable = true,
    },
    Hay = {
        Name = "Hay",
        DisplayName = "Hay",
        Rarity = "Rare",
        Image = "rbxassetid://86030501419879",
        XPValue = 3,
        XPMin = 3,
        XPMax = 3,
        Price = 300,
        MinimumRestock = 8,
        MaximumRestock = 16,
        RestockChance = 90 / 100,
        RobuxProductId = 3609095497,
        ShopCardName = "Rare",
        Stackable = true,
    },
    Wheat = {
        Name = "Wheat",
        DisplayName = "Wheat",
        Rarity = "Epic",
        Image = "rbxassetid://88990322073599",
        XPValue = 5,
        XPMin = 5,
        XPMax = 5,
        Price = 800,
        MinimumRestock = 6,
        MaximumRestock = 12,
        RestockChance = 70 / 100,
        RobuxProductId = 3609095532,
        ShopCardName = "Epic",
        Stackable = true,
    },
    Corn = {
        Name = "Corn",
        DisplayName = "Corn",
        Rarity = "Legendary",
        Image = "rbxassetid://104723569348549",
        XPValue = 8,
        XPMin = 8,
        XPMax = 8,
        Price = 5_000,
        MinimumRestock = 4,
        MaximumRestock = 8,
        RestockChance = 45 / 100,
        RobuxProductId = 3609095575,
        ShopCardName = "Legendary",
        Stackable = true,
    },
    Carrot = {
        Name = "Carrot",
        DisplayName = "Carrot",
        Rarity = "Secret",
        Image = "rbxassetid://87870874588749",
        XPValue = 13,
        XPMin = 13,
        XPMax = 13,
        Price = 15_000,
        MinimumRestock = 2,
        MaximumRestock = 5,
        RestockChance = 25 / 100,
        RobuxProductId = 3609095618,
        ShopCardName = "Secret",
        Stackable = true,
    },
    Berries = {
        Name = "Berries",
        DisplayName = "Berries",
        Rarity = "Prismatic",
        Image = "rbxassetid://109909407954436",
        XPValue = 16,
        XPMin = 16,
        XPMax = 16,
        Price = 35_000,
        MinimumRestock = 1,
        MaximumRestock = 4,
        RestockChance = 20 / 100,
        RobuxProductId = 3609095668,
        ShopCardName = "Prismatic",
        Stackable = true,
    },
    ["Honey Treat"] = {
        Name = "Honey Treat",
        DisplayName = "Honey Treat",
        Rarity = "Divine",
        Image = "rbxassetid://71784216279367",
        XPValue = 20,
        XPMin = 20,
        XPMax = 20,
        Price = 75_000,
        MinimumRestock = 2,
        MaximumRestock = 4,
        RestockChance = 15 / 100,
        RobuxProductId = 3609095712,
        ShopCardName = "Divine",
        Stackable = true,
    },
    ["Fruit Basket"] = {
        Name = "Fruit Basket",
        DisplayName = "Fruit Basket",
        Rarity = "Exotic",
        Image = "rbxassetid://97172559954466",
        XPValue = 25,
        XPMin = 25,
        XPMax = 25,
        Price = 200_000,
        MinimumRestock = 1,
        MaximumRestock = 4,
        RestockChance = 10 / 100,
        RobuxProductId = 3609095796,
        ShopCardName = "Exotic",
        Stackable = true,
    },
    ["Rainbow Feed"] = {
        Name = "Rainbow Feed",
        DisplayName = "Rainbow Feed",
        Rarity = "Transcended",
        Image = "rbxassetid://81064544664030",
        XPValue = 30,
        XPMin = 30,
        XPMax = 30,
        Price = 1_000_000,
        MinimumRestock = 1,
        MaximumRestock = 4,
        RestockChance = 5 / 100,
        RobuxProductId = 3609095837,
        ShopCardName = "Transcendent",
        Stackable = true,
    },
}

local function Normalize_Name(Name: any): string
    if type(Name) ~= "string" then
        return ""
    end

    return FOOD_ALIASES[Name] or Name
end

local function Get(Name: any): FoodData?
    return FOODS[Normalize_Name(Name)]
end

local function Get_Rarity(Name: any): string
    local Food = Get(Name)

    return if Food then Food.Rarity else "Common"
end

local function Get_XP(Name: any): number
    local Food = Get(Name)

    return if Food then Food.XPValue else 0
end

local function Get_Price(Name: any): number
    local Food = Get(Name)

    return if Food then Food.Price else 0
end

local function Roll_XP(Name: any, RNG: Random?): number
    local Food = Get(Name)

    if not Food then
        return 0
    end

    local Minimum = math.max(0, math.floor(Food.XPMin))
    local Maximum = math.max(Minimum, math.floor(Food.XPMax))
    local Randomizer = RNG or Random.new()

    return Randomizer:NextInteger(Minimum, Maximum)
end

return table.freeze({
    Order = table.freeze(FOOD_ORDER),
    Data = table.freeze(FOODS),
    Get = Get,
    Get_Rarity = Get_Rarity,
    Get_XP = Get_XP,
    Get_Price = Get_Price,
    Roll_XP = Roll_XP,
})
