export type LassoData = {
    Name: string,
    DisplayName: string,
    ModelName: string,
    Image: string,
    Price: number,
    Strength: number,
    RobuxOnly: boolean?,
    RobuxProductId: number?,
}

local DEFAULT_LASSO = "Basic"

local LASSO_ORDER = {
    "Basic",
    "Metal",
    "Ruby",
    "Iron",
    "Elmerald",
    "Diamond",
    "Gold",
    "Void",
}

local LASSO_ICONS: { [string]: string } = {
    Basic = "rbxassetid://140166662618245",
    Metal = "rbxassetid://131838824367363",
    Iron = "rbxassetid://136439144083857",
    Gold = "rbxassetid://93451768700020",
    Ruby = "rbxassetid://80994127735680",
    Elmerald = "rbxassetid://126139903936253",
    Diamond = "rbxassetid://77003358835384",
    Void = "rbxassetid://106899053185811",
}

local LASSOS: { [string]: LassoData } = {
    Basic = {
        Name = "Basic",
        DisplayName = "Basic Lasso",
        ModelName = "Basic",
        Image = LASSO_ICONS.Basic,
        Price = 0,
        Strength = 30,
        RobuxProductId = 3609094822,
    },
    Metal = {
        Name = "Metal",
        DisplayName = "Metal Lasso",
        ModelName = "Metal",
        Image = LASSO_ICONS.Metal,
        Price = 1000,
        Strength = 85,
        RobuxProductId = 3609094867,
    },
    Iron = {
        Name = "Iron",
        DisplayName = "Iron Lasso",
        ModelName = "Iron",
        Image = LASSO_ICONS.Iron,
        Price = 250_000,
        Strength = 550,
        RobuxProductId = 3609094932,
    },
    Gold = {
        Name = "Gold",
        DisplayName = "Gold Lasso",
        ModelName = "Gold",
        Image = LASSO_ICONS.Gold,
        Price = 750_000_000,
        Strength = 6_500,
        RobuxProductId = 3609095162,
    },
    Ruby = {
        Name = "Ruby",
        DisplayName = "Ruby Lasso",
        ModelName = "Ruby",
        Image = LASSO_ICONS.Ruby,
        Price = 15_000,
        Strength = 220,
        RobuxProductId = 3609094895,
    },
    Elmerald = {
        Name = "Elmerald",
        DisplayName = "Elmerald Lasso",
        ModelName = "Elmerald",
        Image = LASSO_ICONS.Elmerald,
        Price = 5_000_000,
        Strength = 1_200,
        RobuxProductId = 3609094994,
    },
    Diamond = {
        Name = "Diamond",
        DisplayName = "Diamond Lasso",
        ModelName = "Diamond",
        Image = LASSO_ICONS.Diamond,
        Price = 65_000_000,
        Strength = 2_800,
        RobuxProductId = 3609095107,
    },
    Void = {
        Name = "Void",
        DisplayName = "Void Lasso",
        ModelName = "Void",
        Image = LASSO_ICONS.Void,
        Price = 1_000_000_000,
        Strength = 12_000,
        RobuxOnly = true,
    },
}

local function Get(Name: string?): LassoData?
    if type(Name) ~= "string" then
        return nil
    end

    return LASSOS[Name]
end

local function Is_Owned(OwnedLassos: { string }?, LassoName: string): boolean
    if type(OwnedLassos) ~= "table" then
        return false
    end

    for _, OwnedLasso in OwnedLassos do
        if OwnedLasso == LassoName then
            return true
        end
    end

    return false
end

local function Normalize_Owned(OwnedLassos: { any }?): { string }
    local Result = {}
    local Seen = {}

    if type(OwnedLassos) == "table" then
        for _, LassoName in OwnedLassos do
            if type(LassoName) ~= "string" or Seen[LassoName] or not LASSOS[LassoName] then
                continue
            end

            Seen[LassoName] = true
            table.insert(Result, LassoName)
        end
    end

    if not Seen[DEFAULT_LASSO] then
        table.insert(Result, 1, DEFAULT_LASSO)
    end

    return Result
end

local function Normalize_Selected(LassoName: string?, OwnedLassos: { string }?): string
    if type(LassoName) ~= "string" or not LASSOS[LassoName] then
        return DEFAULT_LASSO
    end

    if not Is_Owned(OwnedLassos, LassoName) then
        return DEFAULT_LASSO
    end

    return LassoName
end

local function Add_Owned(OwnedLassos: { string }?, LassoName: string): { string }
    local Result = Normalize_Owned(OwnedLassos)

    if LASSOS[LassoName] and not Is_Owned(Result, LassoName) then
        table.insert(Result, LassoName)
    end

    return Result
end

return table.freeze({
    Default = DEFAULT_LASSO,
    Order = table.freeze(LASSO_ORDER),
    Icons = table.freeze(LASSO_ICONS),
    Data = table.freeze(LASSOS),
    Get = Get,
    Is_Owned = Is_Owned,
    Normalize_Owned = Normalize_Owned,
    Normalize_Selected = Normalize_Selected,
    Add_Owned = Add_Owned,
})
