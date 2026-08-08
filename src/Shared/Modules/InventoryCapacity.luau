local Config = require(script.Parent.Parent.Config)

local InventoryCapacity = {}

InventoryCapacity.SquishyInventoryFullMessage = "Inventory full, sell Squishies to make room."

function InventoryCapacity.GetSquishyInventoryCap(): number
    local Cap = Config.SquishyInventoryCap

    return if type(Cap) == "number" then math.max(math.floor(Cap), 0) else math.huge
end

function InventoryCapacity.CountSquishies(OwnedSquishies: any): number
    if type(OwnedSquishies) ~= "table" then
        return 0
    end

    local Count = 0

    for _, Item in OwnedSquishies do
        if type(Item) == "table" and type(Item.Id) == "string" then
            Count += 1
        end
    end

    return Count
end

function InventoryCapacity.CanAddSquishies(OwnedSquishies: any, Amount: number?): boolean
    local AddAmount = if type(Amount) == "number" then math.max(math.floor(Amount), 1) else 1

    return InventoryCapacity.CountSquishies(OwnedSquishies) + AddAmount <= InventoryCapacity.GetSquishyInventoryCap()
end

function InventoryCapacity.IsSquishyInventoryFull(OwnedSquishies: any): boolean
    return not InventoryCapacity.CanAddSquishies(OwnedSquishies, 1)
end

return table.freeze(InventoryCapacity)
