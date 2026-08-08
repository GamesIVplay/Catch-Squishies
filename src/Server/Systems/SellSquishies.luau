local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local TutorialProgress = require(ServerScriptService.Server.Modules.TutorialProgress)

local Components = require(ReplicatedStorage.Shared.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local Util = require(ReplicatedStorage.Shared.Modules.Util)
local World = require(ReplicatedStorage.Shared.World)

local SELECTED_INVENTORY_SLOT_ATTRIBUTE = "ServerEquippedInventorySlot"
local CUSTOM_SLOT_MIN = 3
local CUSTOM_SLOT_MAX = 7
local SELL_VALUE_SECONDS = if type(Config.SellValueSeconds) == "number" then Config.SellValueSeconds else 60
local CASH_RICH_TEXT_COLOR = "rgb(0,206,7)"

local function Get_Player_Plot_Spawn(PlayerEntity: number): BasePart?
    local PlotEntity = World:target(PlayerEntity, Components.Relationships.Plot)
    local Plot = PlotEntity and World:get(PlotEntity, Components.Renderable)
    local Spawn = Plot and Plot:FindFirstChild("Spawn")

    return if Spawn and Spawn:IsA("BasePart") then Spawn else nil
end

local function Complete_Tutorial(Player: Player, PlayerEntity: number)
    if not TutorialProgress.Complete_Step(PlayerEntity, TutorialSteps.SellOld, TutorialSteps.Complete) then
        return
    end

    local Character = Player.Character
    local Spawn = Get_Player_Plot_Spawn(PlayerEntity)

    if Character and Spawn then
        Character:PivotTo(Spawn.CFrame + Vector3.yAxis * 3)
    end

    Network.TutorialCompleteEffect.FireAll({
        PlayerUserId = Player.UserId,
    })
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

    for Key, Assignment in Value do
        if type(Assignment) ~= "table" then
            continue
        end

        local Slot = if type(Assignment.Slot) == "number" then Assignment.Slot else tonumber(Key)

        if
            type(Slot) == "number"
            and Slot >= CUSTOM_SLOT_MIN
            and Slot <= CUSTOM_SLOT_MAX
            and math.floor(Slot) == Slot
            and type(Assignment.ItemId) == "string"
            and type(Assignment.ItemType) == "string"
        then
            Result[tostring(Slot)] = {
                Slot = Slot,
                ItemId = Assignment.ItemId,
                ItemType = Assignment.ItemType,
            }
        end
    end

    return Result
end

local function Get_Selected_Custom_Slot(Player: Player): number?
    local SlotName = Player:GetAttribute(SELECTED_INVENTORY_SLOT_ATTRIBUTE)

    if type(SlotName) ~= "string" then
        return nil
    end

    local Slot = tonumber(SlotName) or tonumber(string.match(SlotName, "^Item%s+(%d+)$"))

    if type(Slot) == "number" and Slot >= CUSTOM_SLOT_MIN and Slot <= CUSTOM_SLOT_MAX and math.floor(Slot) == Slot then
        return Slot
    end

    return nil
end

local function Find_Squishy_Index(OwnedSquishies: { any }, ItemId: string): (number?, any?)
    for Index, Item in OwnedSquishies do
        if type(Item) == "table" and Item.Id == ItemId then
            return Index, Item
        end
    end

    return nil, nil
end

local function Remove_Hotbar_Item(HotbarSlots: { [string]: any }, ItemId: string)
    for Key, Assignment in HotbarSlots do
        if type(Assignment) == "table" and Assignment.ItemType == "Squishy" and Assignment.ItemId == ItemId then
            HotbarSlots[Key] = nil
        end
    end
end

local function Remove_Sold_Hotbar_Items(HotbarSlots: { [string]: any }, SoldItemIds: { [string]: boolean })
    for Key, Assignment in HotbarSlots do
        if
            type(Assignment) == "table"
            and Assignment.ItemType == "Squishy"
            and type(Assignment.ItemId) == "string"
            and SoldItemIds[Assignment.ItemId]
        then
            HotbarSlots[Key] = nil
        end
    end
end

local function Apply_Hotbar_To_Squishies(OwnedSquishies: { any }, HotbarSlots: { [string]: any })
    local SquishyById = {}

    for _, Item in OwnedSquishies do
        if type(Item) ~= "table" then
            continue
        end

        Item.HotbarSlot = nil

        if type(Item.Id) == "string" then
            SquishyById[Item.Id] = Item
        end
    end

    for _, Assignment in HotbarSlots do
        if type(Assignment) ~= "table" or Assignment.ItemType ~= "Squishy" then
            continue
        end

        local Item = SquishyById[Assignment.ItemId]

        if Item and type(Assignment.Slot) == "number" then
            Item.HotbarSlot = Assignment.Slot
        end
    end
end

local function Get_Money_Multiplier(PlayerEntity: number): number
    return RobuxProducts.NormalizeMoneyMultiplier(World:get(PlayerEntity, Components.MoneyMultiplier))
end

local function Get_Sell_Value(PlayerEntity: number, Item: any): number
    return math.max(
        0,
        math.floor(
            InventoryMath.GetFinalIncomePerSec(Item) * SELL_VALUE_SECONDS * Get_Money_Multiplier(PlayerEntity) + 0.5
        )
    )
end

local function Format_Cash(Value: number): string
    return "$" .. Util.Abbreviate_Number(math.max(0, math.floor(Value + 0.5)), 1)
end

local function Format_Cash_Rich(Value: number): string
    return `<font color="{CASH_RICH_TEXT_COLOR}">{Format_Cash(Value)}</font>`
end

local function Get_Display_Name(Item: any): string
    if type(Item) ~= "table" then
        return "squishy"
    end

    local DisplayName = InventoryMath.FormatSquishyDisplayName(Item.Kind, Item.Name, Item.Mutation)

    if DisplayName == "" then
        return "squishy"
    end

    return DisplayName
end

local function Add_Cash(PlayerEntity: number, Amount: number)
    local Cash = World:get(PlayerEntity, Components.Cash)

    if type(Cash) ~= "number" or Cash ~= Cash then
        Cash = 0
    end

    World:set(PlayerEntity, Components.Cash, Cash + math.max(0, math.floor(Amount + 0.5)))
end

local function Send_Dialog_Message(Player: Player, Message: string)
    Network.SellDialogMessage.Fire(Player, Message)
end

local function Play_Sell_Effect(Player: Player)
    Network.SellEffect.Fire(Player)
end

local function Sell_Equipped(Player: Player, PlayerEntity: number)
    local Slot = Get_Selected_Custom_Slot(Player)

    if not Slot then
        Send_Dialog_Message(Player, "You're not holding a squishy.")
        return
    end

    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))
    local Assignment = HotbarSlots[tostring(Slot)]

    if type(Assignment) ~= "table" or Assignment.ItemType ~= "Squishy" or type(Assignment.ItemId) ~= "string" then
        Send_Dialog_Message(Player, "You're not holding a squishy.")
        return
    end

    local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))
    local ItemIndex, Item = Find_Squishy_Index(OwnedSquishies, Assignment.ItemId)

    if not Item then
        Send_Dialog_Message(Player, "You're not holding a squishy.")
        return
    end

    if Item.Favorite == true then
        Send_Dialog_Message(Player, "I can't buy favorited Squishies.")
        return
    end

    if
        not TutorialProgress.Is_Complete(PlayerEntity)
        and (
            TutorialProgress.Get(PlayerEntity) ~= TutorialSteps.SellOld
            or Item.TutorialRole ~= TutorialSteps.FirstRole
        )
    then
        Send_Dialog_Message(Player, TutorialSteps.BlockedMessage)
        return
    end

    local Value = Get_Sell_Value(PlayerEntity, Item)

    table.remove(OwnedSquishies, ItemIndex :: number)
    Remove_Hotbar_Item(HotbarSlots, Assignment.ItemId)
    Apply_Hotbar_To_Squishies(OwnedSquishies, HotbarSlots)

    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
    Add_Cash(PlayerEntity, Value)
    Play_Sell_Effect(Player)
    if Item.TutorialRole == TutorialSteps.FirstRole then
        Complete_Tutorial(Player, PlayerEntity)
    end

    Send_Dialog_Message(Player, `I bought {Get_Display_Name(Item)} for {Format_Cash_Rich(Value)}.`)
end

local function Sell_All(Player: Player, PlayerEntity: number)
    if not TutorialProgress.Is_Complete(PlayerEntity) then
        Send_Dialog_Message(Player, TutorialSteps.BlockedMessage)
        return
    end

    local OwnedSquishies = Copy_Array(World:get(PlayerEntity, Components.OwnedSquishies))

    if #OwnedSquishies == 0 then
        Send_Dialog_Message(Player, "You don't have anything to sell.")
        return
    end

    local TotalValue = 0
    local SoldCount = 0
    local RemainingSquishies = {}
    local SoldItemIds = {}

    for _, Item in OwnedSquishies do
        if type(Item) == "table" and (Item.Type == nil or Item.Type == "Squishy") and Item.Favorite ~= true then
            TotalValue += Get_Sell_Value(PlayerEntity, Item)
            SoldCount += 1
            if type(Item.Id) == "string" then
                SoldItemIds[Item.Id] = true
            end
        else
            table.insert(RemainingSquishies, Item)
        end
    end

    if SoldCount == 0 then
        Send_Dialog_Message(Player, "I can't buy favorited Squishies.")
        return
    end

    local HotbarSlots = Copy_Hotbar(World:get(PlayerEntity, Components.HotbarSlots))

    Remove_Sold_Hotbar_Items(HotbarSlots, SoldItemIds)
    Apply_Hotbar_To_Squishies(RemainingSquishies, HotbarSlots)

    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    World:set(PlayerEntity, Components.OwnedSquishies, RemainingSquishies)
    Add_Cash(PlayerEntity, TotalValue)
    Play_Sell_Effect(Player)

    Send_Dialog_Message(Player, `I bought {SoldCount} Squishies for {Format_Cash_Rich(TotalValue)}.`)
end

local function Process_Remotes()
    for _, Player, Mode in Network.SellSquishies.Iter() do
        if not RemoteCooldowns.Allow(Player, "SellSquishies", 0.25) then
            Send_Dialog_Message(Player, "One second.")
            continue
        end

        local PlayerEntity = Get_Player_Entity(Player)

        if not PlayerEntity then
            continue
        end

        if Mode == "Equipped" then
            Sell_Equipped(Player, PlayerEntity)
        elseif Mode == "All" then
            Sell_All(Player, PlayerEntity)
        else
            Send_Dialog_Message(Player, "I can't buy that.")
        end
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = Process_Remotes,
    runConditions = {},
}
