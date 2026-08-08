local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CatchConfig = require(ReplicatedStorage.Shared.Modules.CatchConfig)
local Components = require(ReplicatedStorage.Shared.Components)
local InventoryCapacity = require(ReplicatedStorage.Shared.Modules.InventoryCapacity)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local Mutations = require(ReplicatedStorage.Shared.Modules.Mutations)
local PlotZones = require(ServerScriptService.Server.Systems.Plot_Zones)
local Registry = require(ReplicatedStorage.Shared.Registry)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local Util = require(ReplicatedStorage.Shared.Modules.Util)
local World = require(ReplicatedStorage.Shared.World)

local U32_MAX = 4_294_967_295
local CUSTOM_HOTBAR_SLOTS = table.freeze({ 3, 4, 5, 6, 7 })
local GIVE_ALL_PLAYERS_SQUISHY_TOPIC = "CatchSquishies_GiveAllPlayersSquishy"
local DidSubscribeToGlobalSquishyGrants = false
local ProcessedGlobalGrantMessages: { [string]: number } = {}

local function Is_Finite_Integer(Value: number): boolean
    return type(Value) == "number" and Value == Value and Value ~= math.huge and Value ~= -math.huge and Value % 1 == 0
end

local function Validate_Non_Negative_Integer(Value: number): (boolean, string?)
    if not Is_Finite_Integer(Value) then
        return false, "Amount must be a finite whole number."
    end

    if Value < 0 then
        return false, "Amount cannot be negative."
    end

    return true, nil
end

local function Clamp_Cash(Value: number): number
    if type(Value) ~= "number" or Value ~= Value then
        return 0
    end

    return math.clamp(math.floor(Value), 0, U32_MAX)
end

local function Format_Cash(Value: number): string
    return Util.Abbreviate_Number(Clamp_Cash(Value), 1)
end

local function Format_Income(Value: number): string
    return "$" .. Util.Abbreviate_Number(math.max(0, math.floor(Value + 0.5)), 1) .. "/s"
end

local function Format_Weight(Weight: number): string
    return Util.Abbreviate_Number(math.max(0, Weight), 1) .. "kg"
end

local function Get_Player_Entity(Player: Player): (number?, string?)
    if not Player or not Player:IsDescendantOf(Players) then
        return nil, "Player is no longer in the game."
    end

    local Entity = Registry.Get("Players", Player)

    if not Entity or not World:contains(Entity) then
        return nil, `{Player.Name} does not have loaded player data yet.`
    end

    return Entity, nil
end

local function Get_Cash(Entity: number): number
    return Clamp_Cash(World:get(Entity, Components.Cash) or 0)
end

local function Set_Cash(Player: Player, Amount: number): string
    local IsValid, ErrorText = Validate_Non_Negative_Integer(Amount)

    if not IsValid then
        return ErrorText :: string
    end

    local Entity, EntityError = Get_Player_Entity(Player)

    if not Entity then
        return EntityError :: string
    end

    local NewCash = Clamp_Cash(Amount)

    World:set(Entity, Components.Cash, NewCash)

    return `Set {Player.Name}'s cash to {Format_Cash(NewCash)}.`
end

local function Add_Cash(Player: Player, Amount: number): string
    local IsValid, ErrorText = Validate_Non_Negative_Integer(Amount)

    if not IsValid then
        return ErrorText :: string
    end

    local Entity, EntityError = Get_Player_Entity(Player)

    if not Entity then
        return EntityError :: string
    end

    local CurrentCash = Get_Cash(Entity)
    local NewCash = Clamp_Cash(CurrentCash + Amount)

    World:set(Entity, Components.Cash, NewCash)

    return `Added {Format_Cash(Amount)} cash to {Player.Name}. New balance: {Format_Cash(NewCash)}.`
end

local function Remove_Cash(Player: Player, Amount: number): string
    local IsValid, ErrorText = Validate_Non_Negative_Integer(Amount)

    if not IsValid then
        return ErrorText :: string
    end

    local Entity, EntityError = Get_Player_Entity(Player)

    if not Entity then
        return EntityError :: string
    end

    local CurrentCash = Get_Cash(Entity)
    local NewCash = Clamp_Cash(CurrentCash - Amount)

    World:set(Entity, Components.Cash, NewCash)

    return `Removed {Format_Cash(Amount)} cash from {Player.Name}. New balance: {Format_Cash(NewCash)}.`
end

local function Add_Lasso(Player: Player, LassoName: string): string
    local LassoData = Lassos.Get(LassoName)

    if not LassoData then
        return `Unknown lasso "{LassoName}".`
    end

    local Entity, EntityError = Get_Player_Entity(Player)

    if not Entity then
        return EntityError :: string
    end

    local OwnedLassos = Lassos.Normalize_Owned(World:get(Entity, Components.OwnedLassos))
    local AlreadyOwned = Lassos.Is_Owned(OwnedLassos, LassoData.Name)

    World:set(Entity, Components.OwnedLassos, Lassos.Add_Owned(OwnedLassos, LassoData.Name))
    World:set(Entity, Components.Lasso, LassoData.Name)

    if AlreadyOwned then
        return `{Player.Name} already owned {LassoData.DisplayName}; equipped it.`
    end

    return `Added {LassoData.DisplayName} to {Player.Name} and equipped it.`
end

local function Copy_Owned_Squishies(Value: any): { any }
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

local function Copy_Hotbar_And_Get_Occupied(PlayerEntity: number): ({ [string]: any }, { [number]: boolean })
    local HotbarSlots = {}
    local OccupiedSlots = {}
    local ExistingHotbarSlots = World:get(PlayerEntity, Components.HotbarSlots)

    if type(ExistingHotbarSlots) == "table" then
        for Key, Assignment in ExistingHotbarSlots do
            if type(Assignment) ~= "table" then
                continue
            end

            local Slot = if type(Assignment.Slot) == "number" then Assignment.Slot else tonumber(Key)

            if
                type(Slot) == "number"
                and Slot >= 3
                and Slot <= 7
                and math.floor(Slot) == Slot
                and type(Assignment.ItemId) == "string"
                and type(Assignment.ItemType) == "string"
            then
                HotbarSlots[tostring(Slot)] = {
                    Slot = Slot,
                    ItemId = Assignment.ItemId,
                    ItemType = Assignment.ItemType,
                }
                OccupiedSlots[Slot] = true
            end
        end
    end

    return HotbarSlots, OccupiedSlots
end

local function Get_First_Open_Slot_From_Occupied(OccupiedSlots: { [number]: boolean }): number?
    for _, Slot in CUSTOM_HOTBAR_SLOTS do
        if not OccupiedSlots[Slot] then
            OccupiedSlots[Slot] = true
            return Slot
        end
    end

    return nil
end

local function Get_First_Open_Custom_Hotbar_Slot(PlayerEntity: number): (number?, { [string]: any })
    local HotbarSlots, OccupiedSlots = Copy_Hotbar_And_Get_Occupied(PlayerEntity)

    return Get_First_Open_Slot_From_Occupied(OccupiedSlots), HotbarSlots
end

local function Normalize_Weight(Weight: number?): (number?, string?)
    if Weight == nil then
        return CatchConfig.MinWeight, nil
    end

    if type(Weight) ~= "number" or Weight ~= Weight or Weight == math.huge or Weight == -math.huge then
        return nil, "Weight must be a finite number."
    end

    if Weight < CatchConfig.MinWeight or Weight > CatchConfig.MaxWeight then
        return nil, `Weight must be between {CatchConfig.MinWeight} and {CatchConfig.MaxWeight}.`
    end

    return math.floor(Weight * 10 + 0.5) / 10, nil
end

local function Normalize_Primary_Mutation(Kind: string, PrimaryMutation: string?): (string?, string?)
    if PrimaryMutation == nil or PrimaryMutation == "" or PrimaryMutation == "Random" then
        return nil, nil
    end

    if PrimaryMutation == "Normal" then
        return Mutations.Normal, nil
    end

    local NormalizedMutation = Mutations.Normalize(Kind, PrimaryMutation)

    if NormalizedMutation == Mutations.Normal then
        return nil, `{PrimaryMutation} is not a valid primary mutation for {Kind}.`
    end

    return NormalizedMutation, nil
end

local function Cleanup_Global_Grant_Messages()
    local Now = os.clock()

    for MessageId, SeenAt in ProcessedGlobalGrantMessages do
        if Now - SeenAt > 120 then
            ProcessedGlobalGrantMessages[MessageId] = nil
        end
    end
end

local function Was_Global_Grant_Message_Processed(MessageId: any): boolean
    if type(MessageId) ~= "string" or MessageId == "" then
        return false
    end

    if ProcessedGlobalGrantMessages[MessageId] then
        return true
    end

    ProcessedGlobalGrantMessages[MessageId] = os.clock()
    Cleanup_Global_Grant_Messages()

    return false
end

local function Add_Index_Keys(PlayerEntity: number, IndexKeys: { string }): number
    local CurrentIndex = World:get(PlayerEntity, Components.Index)
    local NewIndex = {}
    local Seen = {}
    local AddedCount = 0

    if type(CurrentIndex) == "table" then
        for _, Key in CurrentIndex do
            if type(Key) == "string" and Key ~= "" and not Seen[Key] then
                Seen[Key] = true
                table.insert(NewIndex, Key)
            end
        end
    end

    for _, IndexKey in IndexKeys do
        if type(IndexKey) ~= "string" or Seen[IndexKey] or not Squishies.GetDataFromKey(IndexKey) then
            continue
        end

        Seen[IndexKey] = true
        AddedCount += 1
        table.insert(NewIndex, IndexKey)
    end

    if AddedCount > 0 then
        table.sort(NewIndex)
        World:set(PlayerEntity, Components.Index, NewIndex)
    end

    return AddedCount
end

local function Add_Index_Key(PlayerEntity: number, IndexKey: string): boolean
    return Add_Index_Keys(PlayerEntity, { IndexKey }) > 0
end

local function Build_Squishy_Item(
    Kind: string,
    SquishyName: string,
    SquishyData: any,
    Weight: number,
    HotbarSlot: number?,
    PrimaryMutation: string?
): { [string]: any }
    local Mutation = PrimaryMutation or Mutations.Roll(Kind)
    local NewItem = {
        Id = HttpService:GenerateGUID(false),
        Type = "Squishy",
        Kind = Kind,
        Name = SquishyName,
        Rarity = SquishyData.Rarity,
        Image = SquishyData.Image,
        BaseIncomePerSec = SquishyData.IncomePerSec,
        FinalIncomePerSec = 0,
        Weight = Weight,
        IncomePerSec = 0,
        Mutation = Mutation,
        EventMutations = {},
        Level = 0,
        XP = 0,
        Equipped = false,
        Favorite = false,
        HotbarSlot = HotbarSlot,
        CaughtAt = os.time(),
    }

    NewItem.FinalIncomePerSec = InventoryMath.GetFinalIncomePerSec(NewItem)
    NewItem.IncomePerSec = NewItem.FinalIncomePerSec

    return NewItem
end

local function Add_Squishy(Player: Player, SquishyKey: string, PrimaryMutation: string?, Weight: number?): string
    local SquishyData, Kind, SquishyName = Squishies.GetDataFromKey(SquishyKey)

    if not SquishyData or not Kind or not SquishyName then
        return `Unknown squishy "{SquishyKey}". Use getSquishies to see valid names.`
    end

    local NormalizedWeight, WeightError = Normalize_Weight(Weight)

    if not NormalizedWeight then
        return WeightError :: string
    end

    local NormalizedMutation, MutationError = Normalize_Primary_Mutation(Kind, PrimaryMutation)

    if MutationError then
        return MutationError
    end

    local PlayerEntity, EntityError = Get_Player_Entity(Player)

    if not PlayerEntity then
        return EntityError :: string
    end

    local NewHotbarSlot, HotbarSlots = Get_First_Open_Custom_Hotbar_Slot(PlayerEntity)
    local NewItem =
        Build_Squishy_Item(Kind, SquishyName, SquishyData, NormalizedWeight, NewHotbarSlot, NormalizedMutation)

    local OwnedSquishies = Copy_Owned_Squishies(World:get(PlayerEntity, Components.OwnedSquishies))

    if not InventoryCapacity.CanAddSquishies(OwnedSquishies, 1) then
        return InventoryCapacity.SquishyInventoryFullMessage
    end

    table.insert(OwnedSquishies, NewItem)

    if NewHotbarSlot then
        HotbarSlots[tostring(NewHotbarSlot)] = {
            Slot = NewHotbarSlot,
            ItemId = NewItem.Id,
            ItemType = "Squishy",
        }
        World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    end

    World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
    Add_Index_Key(PlayerEntity, Squishies.GetKey(Kind, SquishyName))

    local SlotText = if NewHotbarSlot then ` Hotbar slot: {NewHotbarSlot}.` else " Hotbar full; added to inventory."

    local MutationText = if NewItem.Mutation ~= Mutations.Normal then ` {NewItem.Mutation}` else ""

    return `Gave {Player.Name}{MutationText} {Kind}:{SquishyName} ({SquishyData.Rarity}) at {Format_Weight(
        NormalizedWeight
    )}. Income: {Format_Income(NewItem.FinalIncomePerSec)}.{SlotText}`
end

local function Give_All_Players_Squishy(SquishyKey: string, PrimaryMutation: string?, Weight: number?): string
    local PlayersList = Players:GetPlayers()
    local AddedCount = 0
    local LastMessage = ""

    if #PlayersList == 0 then
        return "There are no players in this server."
    end

    for _, Player in PlayersList do
        local Message = Add_Squishy(Player, SquishyKey, PrimaryMutation, Weight)

        LastMessage = Message

        if string.sub(Message, 1, 5) == "Gave " then
            AddedCount += 1
        end
    end

    if AddedCount <= 0 then
        return LastMessage ~= "" and LastMessage or "No squishies were given."
    end

    return `Gave {SquishyKey} to {AddedCount} player(s).`
end

local function Handle_Global_Give_All_Squishy(Data: any)
    if type(Data) ~= "table" or Was_Global_Grant_Message_Processed(Data.MessageId) then
        return
    end

    Give_All_Players_Squishy(Data.SquishyKey, Data.PrimaryMutation, Data.Weight)
end

local function Subscribe_Global_Squishy_Grants()
    if DidSubscribeToGlobalSquishyGrants then
        return
    end

    DidSubscribeToGlobalSquishyGrants = true

    task.spawn(function()
        pcall(function()
            MessagingService:SubscribeAsync(GIVE_ALL_PLAYERS_SQUISHY_TOPIC, function(Message)
                Handle_Global_Give_All_Squishy(Message.Data)
            end)
        end)
    end)
end

local function Publish_Give_All_Players_Squishy(SquishyKey: string, PrimaryMutation: string?, Weight: number?): string
    local SquishyData, Kind = Squishies.GetDataFromKey(SquishyKey)

    if not SquishyData or not Kind then
        return `Unknown squishy "{SquishyKey}". Use getSquishies to see valid names.`
    end

    local NormalizedWeight, WeightError = Normalize_Weight(Weight)

    if not NormalizedWeight then
        return WeightError :: string
    end

    local NormalizedMutation, MutationError = Normalize_Primary_Mutation(Kind, PrimaryMutation)

    if MutationError then
        return MutationError
    end

    local Payload = {
        MessageId = HttpService:GenerateGUID(false),
        SquishyKey = SquishyKey,
        PrimaryMutation = NormalizedMutation or "Random",
        Weight = NormalizedWeight,
    }

    local Success, Error = pcall(function()
        MessagingService:PublishAsync(GIVE_ALL_PLAYERS_SQUISHY_TOPIC, Payload)
    end)

    if not Success then
        return `Failed to publish global squishy grant: {Error}`
    end

    Handle_Global_Give_All_Squishy(Payload)

    return `Published global squishy grant for {SquishyKey}.`
end

local function Get_Squishies(Player: Player, Weight: number?): string
    local NormalizedWeight, WeightError = Normalize_Weight(Weight)

    if not NormalizedWeight then
        return WeightError :: string
    end

    local PlayerEntity, EntityError = Get_Player_Entity(Player)

    if not PlayerEntity then
        return EntityError :: string
    end

    local OwnedSquishies = Copy_Owned_Squishies(World:get(PlayerEntity, Components.OwnedSquishies))
    local HotbarSlots, OccupiedSlots = Copy_Hotbar_And_Get_Occupied(PlayerEntity)
    local IndexKeys = {}
    local AddedCount = 0
    local HotbarAddedCount = 0
    local Entries = Squishies.GetIndexEntries()

    if not InventoryCapacity.CanAddSquishies(OwnedSquishies, #Entries) then
        return InventoryCapacity.SquishyInventoryFullMessage
    end

    for _, Entry in Entries do
        local SquishyData = Squishies.GetData(Entry.Kind, Entry.Name)

        if not SquishyData then
            continue
        end

        local HotbarSlot = Get_First_Open_Slot_From_Occupied(OccupiedSlots)
        local NewItem = Build_Squishy_Item(Entry.Kind, Entry.Name, SquishyData, NormalizedWeight, HotbarSlot, nil)

        table.insert(OwnedSquishies, NewItem)
        table.insert(IndexKeys, Entry.Key)
        AddedCount += 1

        if HotbarSlot then
            HotbarAddedCount += 1
            HotbarSlots[tostring(HotbarSlot)] = {
                Slot = HotbarSlot,
                ItemId = NewItem.Id,
                ItemType = "Squishy",
            }
        end
    end

    if AddedCount <= 0 then
        return "No squishies were found in config."
    end

    World:set(PlayerEntity, Components.OwnedSquishies, OwnedSquishies)
    World:set(PlayerEntity, Components.HotbarSlots, HotbarSlots)
    Add_Index_Keys(PlayerEntity, IndexKeys)

    local InventoryAddedCount = AddedCount - HotbarAddedCount

    return `Gave {Player.Name} all {AddedCount} squishies at {Format_Weight(NormalizedWeight)}. Hotbar: {HotbarAddedCount}. Inventory: {InventoryAddedCount}.`
end

local function Reset_Areas(Player: Player): string
    return PlotZones.Reset_Player_Areas(Player)
end

local function Unlock_Areas(Player: Player): string
    return PlotZones.Unlock_Player_Areas(Player)
end

return table.freeze({
    Add_Cash = Add_Cash,
    Add_Lasso = Add_Lasso,
    Add_Squishy = Add_Squishy,
    Give_All_Players_Squishy = Give_All_Players_Squishy,
    Get_Squishies = Get_Squishies,
    Publish_Give_All_Players_Squishy = Publish_Give_All_Players_Squishy,
    Remove_Cash = Remove_Cash,
    Reset_Areas = Reset_Areas,
    Set_Cash = Set_Cash,
    Subscribe_Global_Squishy_Grants = Subscribe_Global_Squishy_Grants,
    Unlock_Areas = Unlock_Areas,
})
