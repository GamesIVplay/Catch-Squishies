local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local FusionValues = require(script.Parent.FusionValues)
local Network = require(ReplicatedFirst.Network)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local peek = Fusion.peek

local TutorialAutoEquip = {}

local CUSTOM_SLOT_MIN = 3
local CUSTOM_SLOT_MAX = 7
local HOTBAR_REQUEST_RETRY_SECONDS = 0.45

local LastAppliedKey: string? = nil
local LastHotbarRequestKey: string? = nil
local LastHotbarRequestAt = 0

local function Is_Tutorial_Active(): (boolean, number)
    if peek(FusionValues.ProfileDataReceived) ~= true or peek(FusionValues.TutorialStepReceived) ~= true then
        return false, TutorialSteps.StartStep
    end

    local Step = TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep))

    return not TutorialSteps.Is_Complete(Step), Step
end

local function Get_Current_Slot(): string?
    local Slot = peek(FusionValues.EquippedInventorySlot)

    return if type(Slot) == "string" then Slot else nil
end

local function Equip_Once(Key: string, SlotName: string, EquipInventorySlot: (string) -> ())
    if LastAppliedKey == Key then
        return
    end

    LastAppliedKey = Key

    if Get_Current_Slot() ~= SlotName then
        EquipInventorySlot(SlotName)
    end
end

local function Get_Assignment_Slot(ItemId: string, ItemType: string): number?
    local HotbarSlots = peek(FusionValues.HotbarSlots)

    if type(HotbarSlots) ~= "table" then
        return nil
    end

    for Key, Assignment in HotbarSlots do
        if type(Assignment) == "table" and Assignment.ItemId == ItemId and Assignment.ItemType == ItemType then
            local Slot = if type(Assignment.Slot) == "number" then Assignment.Slot else tonumber(Key)

            if Slot and Slot >= CUSTOM_SLOT_MIN and Slot <= CUSTOM_SLOT_MAX then
                return Slot
            end
        end
    end

    return nil
end

local function Get_Open_Custom_Slot(): number?
    local HotbarSlots = peek(FusionValues.HotbarSlots)
    local Used = {}

    if type(HotbarSlots) == "table" then
        for Key, Assignment in HotbarSlots do
            if type(Assignment) ~= "table" then
                continue
            end

            local Slot = if type(Assignment.Slot) == "number" then Assignment.Slot else tonumber(Key)

            if Slot then
                Used[Slot] = true
            end
        end
    end

    for Slot = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
        if not Used[Slot] then
            return Slot
        end
    end

    return nil
end

local function Request_Hotbar_Assignment(ItemId: string, ItemType: string)
    local RequestKey = `{ItemType}:{ItemId}`
    local Now = os.clock()

    if LastHotbarRequestKey == RequestKey and Now - LastHotbarRequestAt < HOTBAR_REQUEST_RETRY_SECONDS then
        return
    end

    LastHotbarRequestKey = RequestKey
    LastHotbarRequestAt = Now

    Network.SetHotbarSlot.Fire({
        Slot = Get_Open_Custom_Slot() or CUSTOM_SLOT_MIN,
        ItemId = ItemId,
        ItemType = ItemType,
    })
end

local function Equip_Hotbar_Item_Once(
    Key: string,
    ItemId: string?,
    ItemType: string,
    EquipInventorySlot: (string) -> ()
)
    if not ItemId or ItemId == "" then
        return
    end

    local AssignedSlot = Get_Assignment_Slot(ItemId, ItemType)

    if not AssignedSlot then
        Request_Hotbar_Assignment(ItemId, ItemType)
        return
    end

    Equip_Once(Key, tostring(AssignedSlot), EquipInventorySlot)
end

local function Get_Owned_Tutorial_Squishy_Id(Role: string): string?
    local OwnedSquishies = peek(FusionValues.OwnedSquishies)

    if type(OwnedSquishies) ~= "table" then
        return nil
    end

    for _, Item in OwnedSquishies do
        if type(Item) == "table" and Item.TutorialRole == Role and type(Item.Id) == "string" then
            return Item.Id
        end
    end

    return nil
end

local function Owns_Tutorial_Food(): boolean
    local OwnedFood = peek(FusionValues.OwnedFood)

    if type(OwnedFood) ~= "table" then
        return false
    end

    for _, Item in OwnedFood do
        if
            type(Item) == "table"
            and Item.Id == TutorialSteps.FeedName
            and type(Item.Amount) == "number"
            and Item.Amount > 0
        then
            return true
        end
    end

    return false
end

function TutorialAutoEquip.Step(EquipInventorySlot: (string) -> ())
    local Active, Step = Is_Tutorial_Active()

    if not Active then
        LastAppliedKey = nil
        LastHotbarRequestKey = nil
        return
    end

    if Step == TutorialSteps.EquipLasso or Step == TutorialSteps.CatchFirst then
        Equip_Once(`{Step}:Lasso`, "Lasso", EquipInventorySlot)
        return
    end

    if Step == TutorialSteps.CatchStrong then
        local StrongItemId = Get_Owned_Tutorial_Squishy_Id(TutorialSteps.StrongRole)

        if StrongItemId then
            Equip_Hotbar_Item_Once(`{Step}:PlaceStrong`, StrongItemId, "Squishy", EquipInventorySlot)
        else
            Equip_Once(`{Step}:Lasso`, "Lasso", EquipInventorySlot)
        end

        return
    end

    if Step == TutorialSteps.PlaceFirst then
        Equip_Hotbar_Item_Once(
            `{Step}:PlaceFirst`,
            Get_Owned_Tutorial_Squishy_Id(TutorialSteps.FirstRole),
            "Squishy",
            EquipInventorySlot
        )
        return
    end

    if Step == TutorialSteps.PlaceStrong then
        Equip_Hotbar_Item_Once(
            `{Step}:PlaceStrong`,
            Get_Owned_Tutorial_Squishy_Id(TutorialSteps.StrongRole),
            "Squishy",
            EquipInventorySlot
        )
        return
    end

    if Step == TutorialSteps.FeedStrong then
        if Owns_Tutorial_Food() then
            Equip_Hotbar_Item_Once(`{Step}:Food`, TutorialSteps.FeedName, "Food", EquipInventorySlot)
        end

        return
    end

    if Step == TutorialSteps.SellOld then
        local FirstItemId = Get_Owned_Tutorial_Squishy_Id(TutorialSteps.FirstRole)

        if FirstItemId then
            Equip_Hotbar_Item_Once(`{Step}:SellOld`, FirstItemId, "Squishy", EquipInventorySlot)
        else
            Equip_Once(`{Step}:Hammer`, "Hammer", EquipInventorySlot)
        end
    end
end

return table.freeze(TutorialAutoEquip)
