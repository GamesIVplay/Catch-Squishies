local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)

local Components = require(ReplicatedStorage.Shared.Components)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local World = require(ReplicatedStorage.Shared.World)

local CUSTOM_SLOT_MIN = 3
local CUSTOM_SLOT_MAX = 7

local function Is_Custom_Slot(Slot: any): boolean
    return type(Slot) == "number" and Slot >= CUSTOM_SLOT_MIN and Slot <= CUSTOM_SLOT_MAX and math.floor(Slot) == Slot
end

local function Get_Player_Entity(Player: Player): number?
    local Entity = Registry.Get("Players", Player)

    if Entity and World:contains(Entity) then
        return Entity
    end

    return nil
end

local function Copy_Array(Value): { any }
    local Result = {}

    if type(Value) ~= "table" then
        return Result
    end

    for _, Entry in Value do
        if type(Entry) == "table" then
            table.insert(Result, table.clone(Entry))
        end
    end

    return Result
end

local function Copy_Hotbar(Value): { [string]: any }
    local Result = {}

    if type(Value) ~= "table" then
        return Result
    end

    for Key, Entry in Value do
        if type(Entry) == "table" then
            Result[tostring(Entry.Slot or Key)] = {
                Slot = Entry.Slot,
                ItemId = Entry.ItemId,
                ItemType = Entry.ItemType,
            }
        end
    end

    return Result
end

local function Find_Item(Items: any, ItemId: string): any?
    if type(Items) ~= "table" then
        return nil
    end

    for _, Entry in Items do
        if type(Entry) == "table" and Entry.Id == ItemId then
            return Entry
        end
    end

    return nil
end

local function Clear_Hotbar_Fields(Items: { any })
    for _, Entry in Items do
        if type(Entry) == "table" then
            Entry.HotbarSlot = nil
        end
    end
end

local function Set_Hotbar_Field(Items: { any }, ItemId: string, Slot: number)
    local Item = Find_Item(Items, ItemId)

    if Item then
        Item.HotbarSlot = Slot
    end
end

local function Apply_Hotbar_To_Items(Squishies: { any }, Food: { any }, HotbarSlots: { [string]: any })
    Clear_Hotbar_Fields(Squishies)
    Clear_Hotbar_Fields(Food)

    for _, Assignment in HotbarSlots do
        if type(Assignment) ~= "table" or not Is_Custom_Slot(Assignment.Slot) then
            continue
        end

        if Assignment.ItemType == "Squishy" then
            Set_Hotbar_Field(Squishies, Assignment.ItemId, Assignment.Slot)
        elseif Assignment.ItemType == "Food" then
            Set_Hotbar_Field(Food, Assignment.ItemId, Assignment.Slot)
        end
    end
end

local function Owns_Item(PlayerEntity: number, ItemId: string, ItemType: string): boolean
    if ItemType == "Squishy" then
        return Find_Item(World:get(PlayerEntity, Components.OwnedSquishies), ItemId) ~= nil
    end

    if ItemType == "Food" then
        local Food = Find_Item(World:get(PlayerEntity, Components.OwnedFood), ItemId)

        return Food ~= nil and type(Food.Amount) == "number" and Food.Amount > 0
    end

    return false
end

local function Set_Item_Favorite_In_Array(Items: { any }, ItemId: string, Favorite: boolean): boolean
    for _, Entry in Items do
        if type(Entry) == "table" and Entry.Id == ItemId then
            Entry.Favorite = Favorite
            return true
        end
    end

    return false
end

local function Commit_Inventory_State(PlayerEntity: number, HotbarSlots: { [string]: any })
    local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))
    local OwnedFood = Copy_Array(World:get(PlayerEntity, Components.OwnedFood))

    Apply_Hotbar_To_Items(OwnedSquishies, OwnedFood, HotbarSlots)

    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
    World:set(PlayerEntity, Components.OwnedFood, OwnedFood)
end

local function Remove_Item_From_Hotbar(HotbarSlots: { [string]: any }, ItemId: string, ItemType: string)
    for Key, Assignment in HotbarSlots do
        if type(Assignment) == "table" and Assignment.ItemId == ItemId and Assignment.ItemType == ItemType then
            HotbarSlots[Key] = nil
        end
    end
end

local function Set_Slot(Player: Player, Slot: number, ItemId: string, ItemType: string)
    if not Is_Custom_Slot(Slot) or type(ItemId) ~= "string" or type(ItemType) ~= "string" then
        return
    end

    if ItemType ~= "Squishy" and ItemType ~= "Food" then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity or not Owns_Item(PlayerEntity, ItemId, ItemType) then
        return
    end

    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))

    Remove_Item_From_Hotbar(HotbarSlots, ItemId, ItemType)
    HotbarSlots[tostring(Slot)] = {
        Slot = Slot,
        ItemId = ItemId,
        ItemType = ItemType,
    }

    Commit_Inventory_State(PlayerEntity, HotbarSlots)
end

local function Clear_Slot(Player: Player, Slot: number)
    if not Is_Custom_Slot(Slot) then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))
    HotbarSlots[tostring(Slot)] = nil

    Commit_Inventory_State(PlayerEntity, HotbarSlots)
end

local function Swap_Slots(Player: Player, SourceSlot: number, TargetSlot: number)
    if not Is_Custom_Slot(SourceSlot) or not Is_Custom_Slot(TargetSlot) or SourceSlot == TargetSlot then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))
    local SourceKey = tostring(SourceSlot)
    local TargetKey = tostring(TargetSlot)
    local SourceAssignment = HotbarSlots[SourceKey]
    local TargetAssignment = HotbarSlots[TargetKey]

    if type(SourceAssignment) ~= "table" then
        return
    end

    if
        type(SourceAssignment.ItemId) ~= "string"
        or type(SourceAssignment.ItemType) ~= "string"
        or not Owns_Item(PlayerEntity, SourceAssignment.ItemId, SourceAssignment.ItemType)
    then
        HotbarSlots[SourceKey] = nil
        Commit_Inventory_State(PlayerEntity, HotbarSlots)
        return
    end

    SourceAssignment.Slot = TargetSlot
    HotbarSlots[TargetKey] = SourceAssignment

    if type(TargetAssignment) == "table" then
        if
            type(TargetAssignment.ItemId) == "string"
            and type(TargetAssignment.ItemType) == "string"
            and Owns_Item(PlayerEntity, TargetAssignment.ItemId, TargetAssignment.ItemType)
        then
            TargetAssignment.Slot = SourceSlot
            HotbarSlots[SourceKey] = TargetAssignment
        else
            HotbarSlots[SourceKey] = nil
        end
    else
        HotbarSlots[SourceKey] = nil
    end

    Commit_Inventory_State(PlayerEntity, HotbarSlots)
end

local function Compare_Best_Squishy(Left: any, Right: any): boolean
    local LeftValue = InventoryMath.GetFinalIncomePerSec(Left)
    local RightValue = InventoryMath.GetFinalIncomePerSec(Right)

    if LeftValue ~= RightValue then
        return LeftValue > RightValue
    end

    local LeftWeight = if type(Left.Weight) == "number" then Left.Weight else 0
    local RightWeight = if type(Right.Weight) == "number" then Right.Weight else 0

    if LeftWeight ~= RightWeight then
        return LeftWeight > RightWeight
    end

    local LeftRarity = InventoryMath.GetRarityRank(Left.Rarity)
    local RightRarity = InventoryMath.GetRarityRank(Right.Rarity)

    if LeftRarity ~= RightRarity then
        return LeftRarity > RightRarity
    end

    return tostring(Left.Id or "") < tostring(Right.Id or "")
end

local function Equip_Best_Squishies(Player: Player)
    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    local Squishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))
    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))

    table.sort(Squishies, Compare_Best_Squishy)

    for Slot = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
        HotbarSlots[tostring(Slot)] = nil
    end

    for Index, Item in Squishies do
        local Slot = CUSTOM_SLOT_MIN + Index - 1

        if Slot > CUSTOM_SLOT_MAX then
            break
        end

        if type(Item) == "table" and type(Item.Id) == "string" then
            HotbarSlots[tostring(Slot)] = {
                Slot = Slot,
                ItemId = Item.Id,
                ItemType = "Squishy",
            }
        end
    end

    Commit_Inventory_State(PlayerEntity, HotbarSlots)
end

local function Set_Favorite(Player: Player, ItemId: string, ItemType: string, Favorite: boolean)
    if type(ItemId) ~= "string" or type(ItemType) ~= "string" or type(Favorite) ~= "boolean" then
        return
    end

    if ItemType ~= "Squishy" and ItemType ~= "Food" then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity or not Owns_Item(PlayerEntity, ItemId, ItemType) then
        return
    end

    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))
    local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))
    local OwnedFood = Copy_Array(World:get(PlayerEntity, Components.OwnedFood))
    local Updated = if ItemType == "Squishy"
        then Set_Item_Favorite_In_Array(OwnedSquishies, ItemId, Favorite)
        else Set_Item_Favorite_In_Array(OwnedFood, ItemId, Favorite)

    if not Updated then
        return
    end

    Apply_Hotbar_To_Items(OwnedSquishies, OwnedFood, HotbarSlots)

    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
    World:set(PlayerEntity, Components.OwnedFood, OwnedFood)
end

local function Process_Remotes()
    for _, Player, Data in Network.SetHotbarSlot.Iter() do
        if not RemoteCooldowns.Allow(Player, "SetHotbarSlot") then
            continue
        end

        Set_Slot(Player, Data.Slot, Data.ItemId, Data.ItemType)
    end

    for _, Player, Data in Network.ClearHotbarSlot.Iter() do
        if not RemoteCooldowns.Allow(Player, "ClearHotbarSlot") then
            continue
        end

        Clear_Slot(Player, Data.Slot)
    end

    for _, Player in Network.EquipBestSquishies.Iter() do
        if not RemoteCooldowns.Allow(Player, "EquipBestSquishies") then
            continue
        end

        Equip_Best_Squishies(Player)
    end

    for _, Player, Data in Network.SwapHotbarSlots.Iter() do
        if not RemoteCooldowns.Allow(Player, "SwapHotbarSlots") then
            continue
        end

        Swap_Slots(Player, Data.SourceSlot, Data.TargetSlot)
    end

    for _, Player, Data in Network.SetInventoryFavorite.Iter() do
        if not RemoteCooldowns.Allow(Player, "SetInventoryFavorite") then
            continue
        end

        Set_Favorite(Player, Data.ItemId, Data.ItemType, Data.Favorite)
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = Process_Remotes,
    runConditions = {},
}
