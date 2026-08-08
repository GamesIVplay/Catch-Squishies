local Foods = require(script.Parent.Foods)

export type StockMap = { [string]: number }

local FoodStock = {}

local function Normalize_Chance(Value: any): number
    if type(Value) ~= "number" or Value ~= Value then
        return 0
    end

    return math.clamp(Value, 0, 1)
end

local function Normalize_Stock_Bounds(MinimumRestock: any, MaximumRestock: any): (number, number)
    local Minimum = if type(MinimumRestock) == "number" then math.max(0, math.floor(MinimumRestock)) else 0
    local Maximum = if type(MaximumRestock) == "number" then math.max(Minimum, math.floor(MaximumRestock)) else Minimum

    return Minimum, Maximum
end

local function Get_Raw_Stock_Value(Stock: any, FoodName: string): any
    if type(Stock) ~= "table" then
        return nil
    end

    local FoodData = Foods.Get(FoodName)
    local NormalizedName = if FoodData then FoodData.Name else FoodName
    local Value = Stock[NormalizedName]

    if Value == nil and NormalizedName == "Carrot" then
        Value = Stock.Carrots
    end

    return Value
end

function FoodStock.Roll_Food(FoodData: Foods.FoodData, RNG: Random?): number
    if type(FoodData) ~= "table" then
        return 0
    end

    local Randomizer = RNG or Random.new()

    if Randomizer:NextNumber() > Normalize_Chance(FoodData.RestockChance) then
        return 0
    end

    local MinimumRestock, MaximumRestock = Normalize_Stock_Bounds(FoodData.MinimumRestock, FoodData.MaximumRestock)

    if MaximumRestock <= 0 then
        return 0
    end

    return Randomizer:NextInteger(MinimumRestock, MaximumRestock)
end

function FoodStock.Roll_All(RNG: Random?): StockMap
    local Result = {}
    local Randomizer = RNG or Random.new()

    for _, FoodName in Foods.Order do
        local FoodData = Foods.Get(FoodName)

        if FoodData then
            Result[FoodData.Name] = FoodStock.Roll_Food(FoodData, Randomizer)
        end
    end

    return Result
end

function FoodStock.Has_Stock_Data(Stock: any): boolean
    if type(Stock) ~= "table" then
        return false
    end

    for _, FoodName in Foods.Order do
        if Get_Raw_Stock_Value(Stock, FoodName) ~= nil then
            return true
        end
    end

    return false
end

function FoodStock.Normalize(Stock: any): (StockMap, boolean)
    local Result = {}
    local Changed = type(Stock) ~= "table"

    for _, FoodName in Foods.Order do
        local RawValue = Get_Raw_Stock_Value(Stock, FoodName)

        if type(RawValue) == "number" and RawValue == RawValue then
            local NormalizedValue = math.max(0, math.floor(RawValue))
            Result[FoodName] = NormalizedValue

            if NormalizedValue ~= RawValue then
                Changed = true
            end
        else
            Result[FoodName] = 0
            Changed = true
        end
    end

    return Result, Changed
end

function FoodStock.Get_Stock(Stock: any, FoodName: string): number
    local Value = Get_Raw_Stock_Value(Stock, FoodName)

    if type(Value) ~= "number" or Value ~= Value then
        return 0
    end

    return math.max(0, math.floor(Value))
end

return table.freeze(FoodStock)
