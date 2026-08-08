local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Network = require(ReplicatedFirst.Network)
local peek = Fusion.peek

local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local FusionValues = require(script.Parent.FusionValues)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local SquishyLevels = require(ReplicatedStorage.Shared.Modules.SquishyLevels)

local LocalPlayer = Players.LocalPlayer

local InventoryUI = {}

local CATCH_MINIGAME_ACTIVE_ATTRIBUTE = "CatchMinigameActive"
local CUSTOM_SLOT_MIN = 3
local CUSTOM_SLOT_MAX = 7
local CUSTOM_SLOTS = { 3, 4, 5, 6, 7 }
local CUSTOM_SLOT_NAMES = {
    [3] = "3",
    [4] = "4",
    [5] = "5",
    [6] = "6",
    [7] = "7",
}
local VALID_TEMPLATE_NAMES = {
    Common = true,
    Rare = true,
    Epic = true,
    Legendary = true,
    Secret = true,
    Prismatic = true,
    Divine = true,
    Exotic = true,
    Transcended = true,
}
local DRAG_THRESHOLD = 10
local CLICK_SUPPRESS_AFTER_DRAG_SECONDS = 0.12
local HOTBAR_HIT_PADDING = 14
local SEARCH_DEBOUNCE_SECONDS = 0.1
local ACTIVE_TAB_IMAGE = "rbxassetid://103702749230981"
local INACTIVE_TAB_IMAGE = "rbxassetid://104828562299505"
local EQUIP_STROKE_NAME = "InventoryEquipStroke"
local HOTBAR_SLOT_ATTRIBUTE = "InventoryHotbarSlot"
local INVENTORY_DRAG_ACTIVE_ATTRIBUTE = "InventoryDragActive"
local INVENTORY_SUPPRESS_SLOT_ACTIVATED_ATTRIBUTE = "InventorySuppressNextActivated"
local PENDING_HOTBAR_CONFIRM_TIMEOUT_SECONDS = 1
local CARD_MOTION_SCALE_NAME = "InventoryCardMotionScale"
local CARD_HOVER_SCALE = 1.04
local CARD_PRESS_SCALE = 0.94
local CARD_MOTION_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local SORT_MODES = {
    Size = true,
    Mutation = true,
    Favorite = true,
    Value = true,
}

local State = {
    Bound = false,
    Dirty = true,
    SearchText = "",
    ActiveTab = nil :: string?,
    SortMode = "Value",
    Inventory = nil :: GuiObject?,
    Content = nil :: GuiObject?,
    ItemButtons = nil :: Instance?,
    DragGui = nil :: ScreenGui?,
    Templates = {} :: { [string]: GuiObject },
    Cards = {} :: { [string]: GuiObject },
    CardItems = {} :: { [string]: any },
    HotbarIcons = {} :: { [number]: { GuiObject } },
    LastSquishiesRef = nil :: any,
    LastFoodRef = nil :: any,
    LastHotbarRef = nil :: any,
    LastSquishiesSignature = "",
    LastFoodSignature = "",
    LastHotbarSignature = "",
    LastVisibleCardsSignature = "",
    LastInventoryOnlySquishySignature = "",
    LastInventoryOnlySquishyCount = 0,
    PendingHotbarAssignments = {} :: { [number]: any },
    PendingHotbarExpiresAt = 0,
    PendingFavorites = {} :: { [string]: boolean },
    PendingFavoriteExpiresAt = 0,
    PendingDrag = nil :: any,
    ActiveDrag = nil :: any,
    DragGeneration = 0,
    LastDragEndTime = -math.huge,
    EquippedInventoryItemKey = nil :: string?,
    SearchBoxes = {} :: { TextBox },
    TabButtons = {} :: { [string]: { GuiButton } },
    SearchToken = 0,
}

local Clear_Hotbar_Icon: ((number) -> ())? = nil

local function Is_Custom_Slot(Slot: any): boolean
    return type(Slot) == "number" and Slot >= CUSTOM_SLOT_MIN and Slot <= CUSTOM_SLOT_MAX and math.floor(Slot) == Slot
end

local function Is_Catch_Minigame_Active(): boolean
    if LocalPlayer:GetAttribute(CATCH_MINIGAME_ACTIVE_ATTRIBUTE) == true then
        return true
    end

    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local MinigameGui = PlayerGui and PlayerGui:FindFirstChild("Minigame")

    return MinigameGui ~= nil and MinigameGui:IsA("ScreenGui") and MinigameGui.Enabled
end

local function Get_Player_Gui(): PlayerGui?
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function Get_Drag_Gui(): ScreenGui?
    if State.DragGui and State.DragGui.Parent then
        return State.DragGui
    end

    local PlayerGui = Get_Player_Gui()

    if not PlayerGui then
        return nil
    end

    local DragGui = Instance.new("ScreenGui")
    DragGui.Name = "InventoryDragGui"
    DragGui.DisplayOrder = 1_000
    DragGui.IgnoreGuiInset = true
    DragGui.ResetOnSpawn = false
    DragGui.Parent = PlayerGui

    State.DragGui = DragGui

    return DragGui
end

local function Set_Dirty()
    State.Dirty = true
end

local function Normalize_Name(Name: string): string
    return string.lower(string.gsub(Name, "%W", ""))
end

local function Get_Ui_Sound(SoundName: string): Sound?
    local UiSounds = SoundService:FindFirstChild("UI")

    if not UiSounds then
        return nil
    end

    local DirectSound = UiSounds:FindFirstChild(SoundName)

    if DirectSound and DirectSound:IsA("Sound") then
        return DirectSound
    end

    local NormalizedTarget = Normalize_Name(SoundName)

    for _, Child in UiSounds:GetChildren() do
        if Child:IsA("Sound") and Normalize_Name(Child.Name) == NormalizedTarget then
            return Child
        end
    end

    return nil
end

local function Play_Ui_Sound(SoundName: string)
    local Sound = Get_Ui_Sound(SoundName)

    if not Sound then
        return
    end

    Sound:Stop()
    Sound.TimePosition = 0
    Sound:Play()
end

local function Clear_Generated_UI()
    for Key, Card in State.Cards do
        if Card and Card.Parent then
            Card:Destroy()
        end

        State.Cards[Key] = nil
        State.CardItems[Key] = nil
    end

    for Slot in State.HotbarIcons do
        if Clear_Hotbar_Icon then
            Clear_Hotbar_Icon(Slot)
        end
    end

    State.LastVisibleCardsSignature = ""
    State.LastInventoryOnlySquishySignature = ""
    State.LastInventoryOnlySquishyCount = 0
end

local function Get_Id(Item: any): string
    if type(Item) ~= "table" or type(Item.Id) ~= "string" then
        return ""
    end

    return Item.Id
end

local function Get_Type(Item: any): string
    if type(Item) ~= "table" or type(Item.Type) ~= "string" then
        return ""
    end

    return Item.Type
end

local function Get_Card_Key(Item: any): string
    return Get_Type(Item) .. ":" .. Get_Id(Item)
end

local function Has_Pending_Favorites(): boolean
    return State.PendingFavoriteExpiresAt > 0 and os.clock() < State.PendingFavoriteExpiresAt
end

local function Clear_Pending_Favorites()
    State.PendingFavorites = {}
    State.PendingFavoriteExpiresAt = 0
end

local function Get_Item_Favorite(Item: any): boolean
    local Key = Get_Card_Key(Item)

    if Has_Pending_Favorites() and type(State.PendingFavorites[Key]) == "boolean" then
        return State.PendingFavorites[Key]
    end

    return type(Item) == "table" and Item.Favorite == true
end

local function Set_Pending_Favorite(Item: any, Favorite: boolean)
    State.PendingFavorites[Get_Card_Key(Item)] = Favorite
    State.PendingFavoriteExpiresAt = os.clock() + PENDING_HOTBAR_CONFIRM_TIMEOUT_SECONDS
    Set_Dirty()
end

local function Normalize_Search_Text(Text: any): string
    if type(Text) ~= "string" then
        return ""
    end

    return string.lower(Text)
end

local function Item_Matches_Active_Tab(Item: any): boolean
    local ItemType = Get_Type(Item)

    if State.ActiveTab == "Food" then
        return ItemType == "Food"
    end

    if State.ActiveTab == "Squishy" then
        return ItemType == "Squishy"
    end

    return ItemType == "Squishy" or ItemType == "Food"
end

local function Item_Matches_Search(Item: any): boolean
    local SearchText = Normalize_Search_Text(State.SearchText)

    if SearchText == "" then
        return true
    end

    local ItemName = if type(Item) == "table" and type(Item.Name) == "string" then Item.Name else ""

    return string.find(string.lower(ItemName), SearchText, 1, true) ~= nil
end

local function Should_Show_Inventory_Card(Item: any): boolean
    return Item_Matches_Active_Tab(Item) and Item_Matches_Search(Item)
end

local function Clear_Search_Filter()
    State.SearchText = ""
    State.SearchToken += 1

    for _, TextBox in State.SearchBoxes do
        if TextBox and TextBox.Parent and TextBox.Text ~= "" then
            TextBox.Text = ""
        end
    end
end

local function Set_Tab_Button_Active(Button: GuiButton, IsActive: boolean)
    if not Button:IsA("ImageButton") then
        return
    end

    Button.Image = if IsActive then ACTIVE_TAB_IMAGE else INACTIVE_TAB_IMAGE
end

local function Update_Tab_Button_Visuals()
    for Tab, Buttons in State.TabButtons do
        for _, Button in Buttons do
            if Button and Button.Parent then
                Set_Tab_Button_Active(Button, Tab == State.ActiveTab)
            end
        end
    end
end

local function Get_Template(Rarity: any): GuiObject?
    local NormalizedRarity = InventoryMath.NormalizeRarity(Rarity)

    return State.Templates[NormalizedRarity] or State.Templates.Common
end

local function Find_Image(Container: Instance?, Name: string): (ImageLabel | ImageButton)?
    local Child = Container and Container:FindFirstChild(Name, true)

    if Child and (Child:IsA("ImageLabel") or Child:IsA("ImageButton")) then
        return Child
    end

    return nil
end

local function Find_Text(Container: Instance?, Name: string): TextLabel?
    local Child = Container and Container:FindFirstChild(Name, true)

    if Child and Child:IsA("TextLabel") then
        return Child
    end

    return nil
end

local function Is_Favorite_Visual(InstanceToCheck: Instance): boolean
    local Name = string.lower(InstanceToCheck.Name)

    return string.find(Name, "favorite", 1, true) ~= nil or string.find(Name, "star", 1, true) ~= nil
end

local function Set_Favorite_Visuals(Container: GuiObject, IsFavorite: boolean)
    if Is_Favorite_Visual(Container) then
        Container.Visible = IsFavorite
    end

    for _, Descendant in Container:GetDescendants() do
        if Descendant:IsA("GuiObject") and Is_Favorite_Visual(Descendant) then
            Descendant.Visible = IsFavorite
        end
    end
end

local function Copy_Hotbar_Assignments(Assignments: any): { [number]: any }
    local Result = {}

    if type(Assignments) ~= "table" then
        return Result
    end

    for Slot, Assignment in Assignments do
        if
            Is_Custom_Slot(Slot)
            and type(Assignment) == "table"
            and type(Assignment.ItemId) == "string"
            and type(Assignment.ItemType) == "string"
        then
            Result[Slot] = {
                Slot = Slot,
                ItemId = Assignment.ItemId,
                ItemType = Assignment.ItemType,
            }
        end
    end

    return Result
end

local function Get_Authoritative_Hotbar_Assignments(): { [number]: any }
    local Result = {}
    local HotbarSlots = peek(FusionValues.HotbarSlots)

    if type(HotbarSlots) == "table" then
        for _, Assignment in HotbarSlots do
            if
                type(Assignment) == "table"
                and Is_Custom_Slot(Assignment.Slot)
                and type(Assignment.ItemId) == "string"
                and type(Assignment.ItemType) == "string"
            then
                Result[Assignment.Slot] = Assignment
            end
        end
    end

    return Result
end

local function Has_Pending_Hotbar_Assignments(): boolean
    return State.PendingHotbarExpiresAt > 0 and os.clock() < State.PendingHotbarExpiresAt
end

local function Clear_Pending_Hotbar_Assignments()
    State.PendingHotbarAssignments = {}
    State.PendingHotbarExpiresAt = 0
end

local function Set_Pending_Hotbar_Assignments(Assignments: { [number]: any })
    State.PendingHotbarAssignments = Copy_Hotbar_Assignments(Assignments)
    State.PendingHotbarExpiresAt = os.clock() + PENDING_HOTBAR_CONFIRM_TIMEOUT_SECONDS
    Set_Dirty()
end

local function Get_Hotbar_Assignments(): { [number]: any }
    if Has_Pending_Hotbar_Assignments() then
        return Copy_Hotbar_Assignments(State.PendingHotbarAssignments)
    end

    return Get_Authoritative_Hotbar_Assignments()
end

local function Normalize_Squishy_Item(Item: any): any?
    if type(Item) ~= "table" or type(Item.Id) ~= "string" or type(Item.Name) ~= "string" then
        return nil
    end

    return {
        Id = Item.Id,
        Type = "Squishy",
        Kind = if type(Item.Kind) == "string" then Item.Kind else "Slime",
        Name = Item.Name,
        Rarity = InventoryMath.NormalizeRarity(Item.Rarity),
        Image = if type(Item.Image) == "string" then Item.Image else "",
        BaseIncomePerSec = if type(Item.BaseIncomePerSec) == "number" then Item.BaseIncomePerSec else nil,
        FinalIncomePerSec = InventoryMath.GetFinalIncomePerSec(Item),
        Weight = if type(Item.Weight) == "number" then Item.Weight else 0,
        Mutation = InventoryMath.NormalizeMutation(
            Item.Mutation,
            if type(Item.Kind) == "string" then Item.Kind else "Slime"
        ),
        EventMutations = InventoryMath.NormalizeEventMutations(Item.EventMutations),
        Level = SquishyLevels.NormalizeLevel(Item.Level),
        XP = SquishyLevels.NormalizeXp(Item.XP),
        Equipped = Item.Equipped == true,
        Favorite = Item.Favorite == true,
        HotbarSlot = if Is_Custom_Slot(Item.HotbarSlot) then Item.HotbarSlot else nil,
    }
end

local function Normalize_Food_Item(Item: any): any?
    if type(Item) ~= "table" then
        return nil
    end

    local FoodData = Foods.Get(Item.Name or Item.Id)

    if not FoodData then
        return nil
    end

    local Amount = if type(Item.Amount) == "number" then math.max(0, math.floor(Item.Amount)) else 0

    if Amount <= 0 then
        return nil
    end

    return {
        Id = FoodData.Name,
        Type = "Food",
        Name = FoodData.Name,
        Rarity = FoodData.Rarity,
        Image = FoodData.Image,
        Amount = Amount,
        XPValue = FoodData.XPValue,
        Favorite = Item.Favorite == true,
        HotbarSlot = if Is_Custom_Slot(Item.HotbarSlot) then Item.HotbarSlot else nil,
    }
end

local function Get_Inventory_Table_Signature(Value: any): string
    if type(Value) ~= "table" then
        return "nil"
    end

    local Parts = {}

    for Key, Entry in Value do
        if type(Entry) == "table" then
            table.insert(
                Parts,
                table.concat({
                    tostring(Key),
                    tostring(Entry.Id),
                    tostring(Entry.Type),
                    tostring(Entry.Kind),
                    tostring(Entry.Name),
                    tostring(Entry.Rarity),
                    tostring(Entry.Image),
                    tostring(Entry.BaseIncomePerSec),
                    tostring(Entry.FinalIncomePerSec),
                    tostring(Entry.IncomePerSec),
                    tostring(Entry.Weight),
                    tostring(Entry.Mutation),
                    if type(Entry.EventMutations) == "table"
                        then table.concat(Entry.EventMutations, ",")
                        else tostring(Entry.EventMutations),
                    tostring(Entry.Level),
                    tostring(Entry.XP),
                    tostring(Entry.Equipped),
                    tostring(Entry.Favorite),
                    tostring(Entry.Slot),
                    tostring(Entry.HotbarSlot),
                    tostring(Entry.Amount),
                    tostring(Entry.XPValue),
                }, "\31")
            )
        else
            table.insert(Parts, `{Key}:{Entry}`)
        end
    end

    table.sort(Parts)

    return `{#Parts}:{table.concat(Parts, "\30")}`
end

local function Get_All_Items(): { any }
    local Result = {}
    local Squishies = peek(FusionValues.OwnedSquishies)
    local Food = peek(FusionValues.OwnedFood)
    local HotbarAssignments = Get_Hotbar_Assignments()
    local UsingPendingHotbar = Has_Pending_Hotbar_Assignments()
    local SlotByItem = {}

    for Slot, Assignment in HotbarAssignments do
        SlotByItem[Assignment.ItemType .. ":" .. Assignment.ItemId] = Slot
    end

    if type(Squishies) == "table" then
        for _, Entry in Squishies do
            local Item = Normalize_Squishy_Item(Entry)

            if Item then
                local PendingOrReplicatedSlot = SlotByItem[Get_Card_Key(Item)]

                Item.HotbarSlot = if PendingOrReplicatedSlot or not UsingPendingHotbar
                    then PendingOrReplicatedSlot or Item.HotbarSlot
                    else nil
                table.insert(Result, Item)
            end
        end
    end

    if type(Food) == "table" then
        for _, Entry in Food do
            local Item = Normalize_Food_Item(Entry)

            if Item then
                local PendingOrReplicatedSlot = SlotByItem[Get_Card_Key(Item)]

                Item.HotbarSlot = if PendingOrReplicatedSlot or not UsingPendingHotbar
                    then PendingOrReplicatedSlot or Item.HotbarSlot
                    else nil
                table.insert(Result, Item)
            end
        end
    end

    return Result
end

local function Get_Content_Layout(): UIGridLayout | UIListLayout?
    local Content = State.Content

    if not Content then
        return nil
    end

    local Grid = Content:FindFirstChildOfClass("UIGridLayout")

    if Grid then
        return Grid
    end

    return Content:FindFirstChildOfClass("UIListLayout")
end

local function Get_Content_Scrolling_Frame(): ScrollingFrame?
    local Current: Instance? = State.Content

    while Current do
        if Current:IsA("ScrollingFrame") then
            return Current
        end

        Current = Current.Parent
    end

    return nil
end

local function Update_Content_Canvas_Size()
    local Content = State.Content
    local Layout = Get_Content_Layout()
    local ScrollingFrame = Get_Content_Scrolling_Frame()

    if not Content or not Layout or not ScrollingFrame then
        return
    end

    task.defer(function()
        if not Content.Parent or not Layout.Parent or not ScrollingFrame.Parent then
            return
        end

        local ContentSize = Layout.AbsoluteContentSize
        local PaddingY = 12

        if Content ~= ScrollingFrame then
            Content.Size = UDim2.new(Content.Size.X.Scale, Content.Size.X.Offset, 0, ContentSize.Y + PaddingY)
        end

        ScrollingFrame.CanvasSize = UDim2.fromOffset(0, ContentSize.Y + PaddingY)
    end)
end

local function Find_Item_By_Assignment(Items: { any }, Assignment: any): any?
    if type(Assignment) ~= "table" then
        return nil
    end

    local Key = Assignment.ItemType .. ":" .. Assignment.ItemId

    for _, Item in Items do
        if Get_Card_Key(Item) == Key then
            return Item
        end
    end

    return nil
end

local function Set_Card_Text(Card: GuiObject, Item: any)
    local Icon = Find_Image(Card, "Icon")
    local IncomePerSec = Find_Text(Card, "IncomePerSec")
    local Weight = Find_Text(Card, "Weight")
    local Image = if type(Item.Image) == "string" then Item.Image else ""

    Set_Favorite_Visuals(Card, Get_Item_Favorite(Item))

    if Icon then
        Icon.Image = Image
    elseif Card:IsA("ImageLabel") or Card:IsA("ImageButton") then
        Card.Image = Image
    end

    if Get_Type(Item) == "Food" then
        if IncomePerSec then
            IncomePerSec.Visible = false
        end

        if Weight then
            local Amount = if type(Item.Amount) == "number" then math.max(1, math.floor(Item.Amount)) else 1
            Weight.Text = `x{InventoryMath.FormatCount(Amount)}`
            Weight.Visible = true
        end

        return
    end

    if IncomePerSec then
        IncomePerSec.Text = InventoryMath.FormatIncome(InventoryMath.GetFinalIncomePerSec(Item))
        IncomePerSec.Visible = true
    end

    if Weight then
        Weight.Text = InventoryMath.FormatWeightKg(Item.Weight)
        Weight.Visible = true
    end
end

local function Set_Inventory_Equipped_Stroke(Card: GuiObject, IsEquipped: boolean)
    local Existing = Card:FindFirstChild(EQUIP_STROKE_NAME)

    if not IsEquipped then
        if Existing then
            Existing:Destroy()
        end

        return
    end

    local Stroke = Existing

    if not Stroke or not Stroke:IsA("UIStroke") then
        if Existing then
            Existing:Destroy()
        end

        Stroke = Instance.new("UIStroke")
        Stroke.Name = EQUIP_STROKE_NAME
        Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        Stroke.Parent = Card
    end

    Stroke.Color = Color3.fromRGB(255, 255, 255)
    Stroke.Thickness = 2
    Stroke.Transparency = 0
    Stroke.Enabled = true
end

local function Get_Or_Create_Card_Motion_Scale(Card: GuiObject): UIScale
    local Existing = Card:FindFirstChild(CARD_MOTION_SCALE_NAME)

    if Existing and Existing:IsA("UIScale") then
        return Existing
    end

    local Scale = Instance.new("UIScale")

    Scale.Name = CARD_MOTION_SCALE_NAME
    Scale.Scale = 1
    Scale.Parent = Card

    return Scale
end

local function Tween_Card_Motion_Scale(Card: GuiObject, TargetScale: number)
    local Scale = Get_Or_Create_Card_Motion_Scale(Card)

    TweenService:Create(Scale, CARD_MOTION_TWEEN_INFO, {
        Scale = TargetScale,
    }):Play()
end

local function Reset_Card_Motion(Card: GuiObject?)
    if Card and Card.Parent then
        Tween_Card_Motion_Scale(Card, 1)
    end
end

local function Clone_Template_Display_Object(
    Template: GuiObject,
    ObjectName: string,
    Parent: GuiObject,
    ZIndex: number,
    Item: any
): GuiObject?
    local Object = Template:FindFirstChild(ObjectName, true)

    if not Object or not Object:IsA("GuiObject") then
        return nil
    end

    local Clone = Object:Clone()

    Clone:SetAttribute("InventoryGenerated", true)
    Clone:SetAttribute("InventoryItemId", Get_Id(Item))
    Clone:SetAttribute("InventoryItemType", Get_Type(Item))
    Clone.Visible = true
    Clone.Active = false
    Clone.ZIndex = math.max(Clone.ZIndex, ZIndex)
    Clone.Parent = Parent

    for _, Descendant in Clone:GetDescendants() do
        if Descendant:IsA("GuiObject") then
            Descendant.Active = false
            Descendant.ZIndex = math.max(Descendant.ZIndex, Clone.ZIndex + 1)
        end
    end

    return Clone
end

local function Set_Drag_Image_Transparency(Frame: GuiObject)
    if Frame:IsA("ImageLabel") or Frame:IsA("ImageButton") then
        Frame.ImageTransparency = 0.5
    end

    for _, Descendant in Frame:GetDescendants() do
        if Descendant:IsA("ImageLabel") or Descendant:IsA("ImageButton") then
            Descendant.ImageTransparency = 0.5
        end
    end
end

local function Create_Hotbar_Drag_Frame(SourceFrame: GuiObject, Item: any): GuiObject
    local Template = Get_Template(Item.Rarity)

    if Template then
        local DragCard = Template:Clone()

        DragCard.Name = "InventoryHotbarDragClone"
        DragCard:SetAttribute("InventoryGenerated", true)
        DragCard:SetAttribute("InventoryItemId", Get_Id(Item))
        DragCard:SetAttribute("InventoryItemType", Get_Type(Item))
        DragCard.Visible = true
        DragCard.Active = false
        Set_Card_Text(DragCard, Item)

        return DragCard
    end

    local DragFrame = Instance.new("Frame")

    DragFrame.Name = "InventoryHotbarDragClone"
    DragFrame.BackgroundTransparency = 1
    DragFrame.BorderSizePixel = 0
    DragFrame.Size = UDim2.fromOffset(SourceFrame.AbsoluteSize.X, SourceFrame.AbsoluteSize.Y)
    DragFrame:SetAttribute("InventoryGenerated", true)
    DragFrame:SetAttribute("InventoryItemId", Get_Id(Item))
    DragFrame:SetAttribute("InventoryItemType", Get_Type(Item))

    for _, Child in SourceFrame:GetChildren() do
        if Child:IsA("GuiObject") and Child:GetAttribute("InventoryGenerated") then
            local Clone = Child:Clone()

            Clone.Active = false
            Clone.Parent = DragFrame

            for _, Descendant in Clone:GetDescendants() do
                if Descendant:IsA("GuiObject") then
                    Descendant.Active = false
                end
            end
        end
    end

    return DragFrame
end

local function Set_Frame_Point(Frame: GuiObject, Point: Vector2)
    Frame.Position = UDim2.fromOffset(Point.X, Point.Y)
end

local function Get_Input_Point(Input: InputObject?): Vector2
    if Input and Input.UserInputType == Enum.UserInputType.Touch then
        return Vector2.new(Input.Position.X, Input.Position.Y)
    end

    return UserInputService:GetMouseLocation()
end

local function Point_In_Gui(Point: Vector2, GuiObject: GuiObject?): boolean
    if not GuiObject or not GuiObject.Visible then
        return false
    end

    local Position = GuiObject.AbsolutePosition
    local Size = GuiObject.AbsoluteSize

    return Point.X >= Position.X
        and Point.X <= Position.X + Size.X
        and Point.Y >= Position.Y
        and Point.Y <= Position.Y + Size.Y
end

local function Point_In_Gui_With_Padding(Point: Vector2, GuiObject: GuiObject?, Padding: number): boolean
    if not GuiObject or not GuiObject.Visible then
        return false
    end

    local Position = GuiObject.AbsolutePosition
    local Size = GuiObject.AbsoluteSize

    return Point.X >= Position.X - Padding
        and Point.X <= Position.X + Size.X + Padding
        and Point.Y >= Position.Y - Padding
        and Point.Y <= Position.Y + Size.Y + Padding
end

local function Is_Gui_Visible_In_Hierarchy(Object: GuiObject?): boolean
    local Current: Instance? = Object

    while Current do
        if Current:IsA("GuiObject") and not Current.Visible then
            return false
        end

        if Current:IsA("ScreenGui") and not Current.Enabled then
            return false
        end

        Current = Current.Parent
    end

    return Object ~= nil
end

local function Is_Inventory_Drag_Open(): boolean
    return Is_Gui_Visible_In_Hierarchy(State.Inventory) and Is_Gui_Visible_In_Hierarchy(State.Content)
end

local function Get_Custom_Slot_From_Instance(InstanceToCheck: Instance?): number?
    local Current = InstanceToCheck

    while Current and Current ~= State.ItemButtons do
        for Slot, ButtonName in CUSTOM_SLOT_NAMES do
            if Current.Name == ButtonName then
                return Slot
            end
        end

        Current = Current.Parent
    end

    return nil
end

local function Hit_Custom_Slot_From_Player_Gui(Point: Vector2): number?
    local PlayerGui = Get_Player_Gui()

    if not PlayerGui then
        return nil
    end

    local Success, Objects = pcall(function()
        return PlayerGui:GetGuiObjectsAtPosition(Point.X, Point.Y)
    end)

    if not Success then
        return nil
    end

    for _, Object in Objects do
        if Object and not Object:IsDescendantOf(State.DragGui) then
            local Slot = Get_Custom_Slot_From_Instance(Object)

            if Slot then
                return Slot
            end
        end
    end

    return nil
end

local function Hit_Custom_Slot(Point: Vector2): number?
    if not State.ItemButtons then
        return nil
    end

    for _, Slot in CUSTOM_SLOTS do
        local ButtonName = CUSTOM_SLOT_NAMES[Slot]
        local Button = State.ItemButtons:FindFirstChild(ButtonName)

        if Button and Button:IsA("GuiObject") and Point_In_Gui_With_Padding(Point, Button, HOTBAR_HIT_PADDING) then
            return Slot
        end
    end

    return Hit_Custom_Slot_From_Player_Gui(Point)
end

local function Set_Inventory_Drag_Active(IsActive: boolean)
    LocalPlayer:SetAttribute(INVENTORY_DRAG_ACTIVE_ATTRIBUTE, if IsActive then true else nil)
end

local function Clear_Inventory_Drag_Active_Soon(DragGeneration: number?)
    task.delay(CLICK_SUPPRESS_AFTER_DRAG_SECONDS, function()
        if DragGeneration and State.DragGeneration ~= DragGeneration then
            return
        end

        Set_Inventory_Drag_Active(false)
    end)
end

local function Is_Point_In_Content(Point: Vector2): boolean
    return State.Content ~= nil and State.Content:IsA("GuiObject") and Point_In_Gui(Point, State.Content)
end

local function Get_Item_Slot(Item: any): number?
    local DirectSlot = Item.HotbarSlot

    if Is_Custom_Slot(DirectSlot) then
        return DirectSlot
    end

    local Assignments = Get_Hotbar_Assignments()
    local Key = Get_Card_Key(Item)

    for Slot, Assignment in Assignments do
        if Assignment.ItemType .. ":" .. Assignment.ItemId == Key then
            return Slot
        end
    end

    return nil
end

local function Get_Expected_Visible_Cards_Signature(Items: { any }): string
    local Parts = {}

    for _, Item in Items do
        if Get_Item_Slot(Item) or not Should_Show_Inventory_Card(Item) then
            continue
        end

        table.insert(Parts, Get_Card_Key(Item))
    end

    table.sort(Parts)

    return table.concat(Parts, "\30")
end

local function Get_Rendered_Visible_Cards_Signature(): string
    local Parts = {}

    for Key, Card in State.Cards do
        if Card and Card.Parent and Card.Visible then
            table.insert(Parts, Key)
        end
    end

    table.sort(Parts)

    return table.concat(Parts, "\30")
end

local function Get_Inventory_Only_Squishy_State(Items: { any }): (string, number)
    local Parts = {}

    for _, Item in Items do
        if Get_Type(Item) ~= "Squishy" or Get_Item_Slot(Item) then
            continue
        end

        table.insert(Parts, Get_Card_Key(Item))
    end

    table.sort(Parts)

    return table.concat(Parts, "\30"), #Parts
end

local function Get_Custom_Slot_Number_From_Name(SlotName: string): number?
    for Slot, CandidateSlotName in CUSTOM_SLOT_NAMES do
        if CandidateSlotName == SlotName then
            return Slot
        end
    end

    return nil
end

local function Get_Equipped_Hotbar_Slot(): number?
    local EquippedKey = peek(FusionValues.EquippedInventorySlot)

    if type(EquippedKey) ~= "string" then
        return nil
    end

    return Get_Custom_Slot_Number_From_Name(EquippedKey)
end

local function Set_Equipped_Inventory_Item(Item: any)
    State.EquippedInventoryItemKey = Get_Card_Key(Item)
    FusionValues.EquippedInventoryItemId:set(if Get_Type(Item) == "Squishy" then Get_Id(Item) else nil)
    FusionValues.EquippedInventorySlot:set(nil)
    Set_Dirty()
end

local function Clear_Equipped_Inventory_Item()
    if State.EquippedInventoryItemKey == nil and peek(FusionValues.EquippedInventoryItemId) == nil then
        return
    end

    State.EquippedInventoryItemKey = nil
    FusionValues.EquippedInventoryItemId:set(nil)
    Set_Dirty()
end

local function Toggle_Hotbar_Source_Slot(Slot: number, SourceFrame: GuiObject?)
    if Is_Catch_Minigame_Active() or not Is_Custom_Slot(Slot) then
        return false
    end

    local SlotName = CUSTOM_SLOT_NAMES[Slot]

    if not SlotName then
        return false
    end

    if SourceFrame then
        SourceFrame:SetAttribute(INVENTORY_SUPPRESS_SLOT_ACTIVATED_ATTRIBUTE, true)
    end

    Clear_Equipped_Inventory_Item()

    local CurrentSlot = peek(FusionValues.EquippedInventorySlot)
    FusionValues.EquippedInventorySlot:set(if CurrentSlot == SlotName then nil else SlotName)
    Set_Dirty()

    return true
end

local function Is_Drag_Source_Equipped(Item: any, SourceSlot: number?): boolean
    if SourceSlot then
        return Get_Equipped_Hotbar_Slot() == SourceSlot
    end

    return State.EquippedInventoryItemKey == Get_Card_Key(Item)
end

local function Remove_Item_From_Assignments(Assignments: { [number]: any }, ItemId: string, ItemType: string)
    for Slot, Assignment in Assignments do
        if type(Assignment) == "table" and Assignment.ItemId == ItemId and Assignment.ItemType == ItemType then
            Assignments[Slot] = nil
        end
    end
end

local function Set_Item_Slot(Item: any, Slot: number)
    if Is_Catch_Minigame_Active() then
        return
    end

    if not Is_Custom_Slot(Slot) then
        return
    end

    local ItemId = Get_Id(Item)
    local ItemType = Get_Type(Item)

    if ItemId == "" or ItemType == "" then
        return
    end

    local Assignments = Copy_Hotbar_Assignments(Get_Hotbar_Assignments())

    Remove_Item_From_Assignments(Assignments, ItemId, ItemType)
    Assignments[Slot] = {
        Slot = Slot,
        ItemId = ItemId,
        ItemType = ItemType,
    }
    Set_Pending_Hotbar_Assignments(Assignments)

    Network.SetHotbarSlot.Fire({
        Slot = Slot,
        ItemId = ItemId,
        ItemType = ItemType,
    })
end

local function Swap_Hotbar_Slots(SourceSlot: number, TargetSlot: number)
    if Is_Catch_Minigame_Active() then
        return
    end

    if not Is_Custom_Slot(SourceSlot) or not Is_Custom_Slot(TargetSlot) or SourceSlot == TargetSlot then
        return
    end

    local Assignments = Copy_Hotbar_Assignments(Get_Hotbar_Assignments())
    local SourceAssignment = Assignments[SourceSlot]
    local TargetAssignment = Assignments[TargetSlot]

    if type(SourceAssignment) ~= "table" then
        return
    end

    Assignments[TargetSlot] = {
        Slot = TargetSlot,
        ItemId = SourceAssignment.ItemId,
        ItemType = SourceAssignment.ItemType,
    }

    if type(TargetAssignment) == "table" then
        Assignments[SourceSlot] = {
            Slot = SourceSlot,
            ItemId = TargetAssignment.ItemId,
            ItemType = TargetAssignment.ItemType,
        }
    else
        Assignments[SourceSlot] = nil
    end
    Set_Pending_Hotbar_Assignments(Assignments)

    Network.SwapHotbarSlots.Fire({
        SourceSlot = SourceSlot,
        TargetSlot = TargetSlot,
    })
end

local function Clear_Hotbar_Slot(Slot: number)
    if Is_Catch_Minigame_Active() then
        return
    end

    if not Is_Custom_Slot(Slot) then
        return
    end

    local Assignments = Copy_Hotbar_Assignments(Get_Hotbar_Assignments())

    Assignments[Slot] = nil
    Set_Pending_Hotbar_Assignments(Assignments)

    Network.ClearHotbarSlot.Fire({
        Slot = Slot,
    })
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

    return Get_Card_Key(Left) < Get_Card_Key(Right)
end

local function Equip_Best_Squishies()
    if Is_Catch_Minigame_Active() then
        return
    end

    local Items = Get_All_Items()
    local Squishies = {}

    for _, Item in Items do
        if Get_Type(Item) == "Squishy" then
            table.insert(Squishies, Item)
        end
    end

    table.sort(Squishies, Compare_Best_Squishy)

    local Assignments = {}

    for Index, Slot in CUSTOM_SLOTS do
        local Item = Squishies[Index]

        if Item then
            Assignments[Slot] = {
                Slot = Slot,
                ItemId = Get_Id(Item),
                ItemType = Get_Type(Item),
            }
        end
    end

    Set_Pending_Hotbar_Assignments(Assignments)
    Network.EquipBestSquishies.Fire()
end

local function Get_Frame_Item(Frame: GuiObject, Fallback: any): any
    local ItemId = Frame:GetAttribute("InventoryItemId")
    local ItemType = Frame:GetAttribute("InventoryItemType")

    if type(ItemId) == "string" and type(ItemType) == "string" then
        return State.CardItems[ItemType .. ":" .. ItemId] or Fallback
    end

    return Fallback
end

local function Find_Item_By_Key(Key: string): any?
    local CachedItem = State.CardItems[Key]

    if CachedItem then
        return CachedItem
    end

    for _, Item in Get_All_Items() do
        if Get_Card_Key(Item) == Key then
            return Item
        end
    end

    return nil
end

local function Reconcile_Equipped_Inventory_Item_Id(Items: { any })
    local EquippedItemId = peek(FusionValues.EquippedInventoryItemId)

    if type(EquippedItemId) ~= "string" or EquippedItemId == "" then
        return
    end

    local CurrentItem = if State.EquippedInventoryItemKey then Find_Item_By_Key(State.EquippedInventoryItemKey) else nil

    if CurrentItem and Get_Id(CurrentItem) == EquippedItemId and Get_Type(CurrentItem) == "Squishy" then
        return
    end

    for _, Item in Items do
        if Get_Type(Item) == "Squishy" and Get_Id(Item) == EquippedItemId then
            State.EquippedInventoryItemKey = Get_Card_Key(Item)
            Set_Dirty()
            return
        end
    end
end

local function Get_Selected_Inventory_Item(): any?
    if State.EquippedInventoryItemKey then
        local Item = Find_Item_By_Key(State.EquippedInventoryItemKey)

        if Item then
            return Item
        end
    end

    local EquippedHotbarSlot = Get_Equipped_Hotbar_Slot()

    if EquippedHotbarSlot then
        local Assignment = Get_Hotbar_Assignments()[EquippedHotbarSlot]

        if Assignment then
            return Find_Item_By_Assignment(Get_All_Items(), Assignment)
        end
    end

    return nil
end

local function Toggle_Selected_Favorite()
    if Is_Catch_Minigame_Active() then
        return
    end

    local Item = Get_Selected_Inventory_Item()

    if not Item then
        return
    end

    local Favorite = not Get_Item_Favorite(Item)

    Set_Pending_Favorite(Item, Favorite)
    Network.SetInventoryFavorite.Fire({
        ItemId = Get_Id(Item),
        ItemType = Get_Type(Item),
        Favorite = Favorite,
    })
end

local function Toggle_Inventory_Item_Equipped(Item: any)
    if Is_Catch_Minigame_Active() then
        return
    end

    local Key = Get_Card_Key(Item)

    if State.EquippedInventoryItemKey == Key then
        Clear_Equipped_Inventory_Item()
    else
        Set_Equipped_Inventory_Item(Item)
    end
end

local function Begin_Pending_Drag(Item: any, SourceSlot: number?, SourceFrame: GuiObject, Input: InputObject)
    if Is_Catch_Minigame_Active() then
        return
    end

    if Get_Id(Item) == "" or Get_Type(Item) == "" then
        return
    end

    local Point = Get_Input_Point(Input)

    State.PendingDrag = {
        Item = Item,
        SourceSlot = SourceSlot,
        SourceFrame = SourceFrame,
        StartPoint = Point,
        LastPoint = Point,
        WasEquipped = Is_Drag_Source_Equipped(Item, SourceSlot),
        CanDrag = SourceSlot == nil or Is_Inventory_Drag_Open(),
    }
end

local function Bind_Hotbar_Slot_Drag(Button: GuiObject, Slot: number)
    if Button:GetAttribute("InventoryHotbarDragBound") then
        return
    end

    Button:SetAttribute("InventoryHotbarDragBound", true)
    Button.Active = true

    if Button:IsA("GuiButton") then
        (Button :: GuiButton).AutoButtonColor = false
    end

    Button.InputBegan:Connect(function(Input: InputObject)
        if
            Input.UserInputType ~= Enum.UserInputType.MouseButton1
            and Input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end

        local Item = Get_Frame_Item(Button, nil)

        if not Item then
            return
        end

        Begin_Pending_Drag(Item, Slot, Button, Input)
    end)

    if Button:IsA("GuiButton") then
        (Button :: GuiButton).Activated:Connect(function()
            if State.PendingDrag or State.ActiveDrag or Is_Catch_Minigame_Active() then
                return
            end

            if Get_Frame_Item(Button, nil) then
                return
            end

            Toggle_Hotbar_Source_Slot(Slot, Button)
        end)
    end
end

local function Start_Drag(Point: Vector2)
    local PendingDrag = State.PendingDrag
    local DragGui = Get_Drag_Gui()

    if not PendingDrag or not DragGui then
        return
    end

    if PendingDrag.CanDrag == false then
        return
    end

    local SourceFrame = PendingDrag.SourceFrame

    if not SourceFrame or not SourceFrame.Parent then
        return
    end

    State.DragGeneration += 1
    Set_Inventory_Drag_Active(true)
    Reset_Card_Motion(SourceFrame)

    local Clone = if PendingDrag.SourceSlot
        then Create_Hotbar_Drag_Frame(SourceFrame, PendingDrag.Item)
        else SourceFrame:Clone()

    Clone.Name = "InventoryDragClone"
    Clone:SetAttribute("InventoryGenerated", true)
    Clone:SetAttribute("InventoryItemId", Get_Id(PendingDrag.Item))
    Clone:SetAttribute("InventoryItemType", Get_Type(PendingDrag.Item))
    Clone.AnchorPoint = Vector2.new(0.5, 0.5)
    Clone.Size = UDim2.fromOffset(SourceFrame.AbsoluteSize.X, SourceFrame.AbsoluteSize.Y)
    Clone.ZIndex = 1_000
    Clone.Active = false
    Set_Card_Text(Clone, PendingDrag.Item)
    Set_Drag_Image_Transparency(Clone)

    for _, Descendant in Clone:GetDescendants() do
        if Descendant:IsA("GuiObject") then
            Descendant.ZIndex += 1_000
            Descendant.Active = false
        end
    end

    Clone.Parent = DragGui
    Set_Frame_Point(Clone, Point)

    State.ActiveDrag = {
        Item = PendingDrag.Item,
        SourceSlot = PendingDrag.SourceSlot,
        Clone = Clone,
        LastPoint = Point,
        DragGeneration = State.DragGeneration,
        WasEquipped = PendingDrag.WasEquipped == true,
    }
end

local function Finish_Drag(Point: Vector2)
    local ActiveDrag = State.ActiveDrag

    State.PendingDrag = nil
    State.ActiveDrag = nil

    if not ActiveDrag then
        return
    end

    if ActiveDrag.Clone then
        ActiveDrag.Clone:Destroy()
    end

    State.LastDragEndTime = os.clock()
    Clear_Inventory_Drag_Active_Soon(ActiveDrag.DragGeneration)

    if Is_Catch_Minigame_Active() then
        return
    end

    local TargetSlot = Hit_Custom_Slot(Point)

    if TargetSlot then
        if ActiveDrag.SourceSlot then
            Swap_Hotbar_Slots(ActiveDrag.SourceSlot, TargetSlot)
        else
            Set_Item_Slot(ActiveDrag.Item, TargetSlot)
        end

        return
    end

    if ActiveDrag.SourceSlot and Is_Point_In_Content(Point) then
        State.ActiveTab = if Get_Type(ActiveDrag.Item) == "Food" then "Food" else "Squishy"
        Update_Tab_Button_Visuals()
        Clear_Search_Filter()

        Clear_Hotbar_Slot(ActiveDrag.SourceSlot)
    end
end

local function End_Pending_Click()
    local PendingDrag = State.PendingDrag

    State.PendingDrag = nil

    if not PendingDrag then
        return
    end

    if Is_Catch_Minigame_Active() then
        return
    end

    if PendingDrag.SourceSlot then
        Toggle_Hotbar_Source_Slot(PendingDrag.SourceSlot, PendingDrag.SourceFrame)
        return
    end

    Play_Ui_Sound("Click")
    Toggle_Inventory_Item_Equipped(PendingDrag.Item)
end

local function Bind_Item_Card_Motion(Frame: GuiObject)
    if Frame:GetAttribute("InventoryCardMotionBound") then
        return
    end

    Frame:SetAttribute("InventoryCardMotionBound", true)

    local Hovering = false
    local Pressing = false

    Frame.MouseEnter:Connect(function()
        if Is_Catch_Minigame_Active() or State.ActiveDrag then
            return
        end

        Hovering = true
        Play_Ui_Sound("Hover")

        if not Pressing then
            Tween_Card_Motion_Scale(Frame, CARD_HOVER_SCALE)
        end
    end)

    Frame.MouseLeave:Connect(function()
        Hovering = false

        if not Pressing then
            Tween_Card_Motion_Scale(Frame, 1)
        end
    end)

    Frame.InputBegan:Connect(function(Input: InputObject)
        if
            Is_Catch_Minigame_Active()
            or (
                Input.UserInputType ~= Enum.UserInputType.MouseButton1
                and Input.UserInputType ~= Enum.UserInputType.Touch
            )
        then
            return
        end

        Pressing = true
        Tween_Card_Motion_Scale(Frame, CARD_PRESS_SCALE)
    end)

    Frame.InputEnded:Connect(function(Input: InputObject)
        if
            Input.UserInputType ~= Enum.UserInputType.MouseButton1
            and Input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end

        Pressing = false

        if State.ActiveDrag then
            Tween_Card_Motion_Scale(Frame, 1)
            return
        end

        Tween_Card_Motion_Scale(Frame, if Hovering then CARD_HOVER_SCALE else 1)
    end)
end

local function Bind_Draggable_Frame(Frame: GuiObject, Item: any, SourceSlot: number?)
    Frame.Active = true

    if not SourceSlot then
        Bind_Item_Card_Motion(Frame)
    end

    if Frame:GetAttribute("InventoryDragBound") then
        return
    end

    Frame:SetAttribute("InventoryDragBound", true)
    Frame.InputBegan:Connect(function(Input: InputObject)
        if
            Input.UserInputType ~= Enum.UserInputType.MouseButton1
            and Input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end

        Begin_Pending_Drag(Get_Frame_Item(Frame, Item), SourceSlot, Frame, Input)
    end)
end

local function Create_Card(Item: any): GuiObject?
    local Template = Get_Template(Item.Rarity)

    if not Template or not State.Content then
        return nil
    end

    local Card = Template:Clone()
    Card.Name = "InventoryCard_" .. Get_Type(Item) .. "_" .. Get_Id(Item)
    Card:SetAttribute("InventoryGenerated", true)
    Card:SetAttribute("InventoryItemId", Get_Id(Item))
    Card:SetAttribute("InventoryItemType", Get_Type(Item))
    Card.Visible = true
    Card.Parent = State.Content

    Bind_Draggable_Frame(Card, Item, nil)

    return Card
end

local function Get_Sort_Value(Item: any, SortMode: string): number
    if SortMode == "Size" then
        return if type(Item.Weight) == "number" then Item.Weight else 0
    end

    if SortMode == "Mutation" then
        return InventoryMath.GetMutationRank(Item.Mutation, Item.Kind)
    end

    if SortMode == "Favorite" then
        return if Get_Item_Favorite(Item) then 1 else 0
    end

    if Get_Type(Item) == "Food" then
        return if type(Item.XPValue) == "number" then Item.XPValue else 0
    end

    return InventoryMath.GetFinalIncomePerSec(Item)
end

local function Sort_Items(Items: { any })
    local SortMode = if SORT_MODES[State.SortMode] then State.SortMode else "Value"

    table.sort(Items, function(Left, Right)
        local LeftValue = Get_Sort_Value(Left, SortMode)
        local RightValue = Get_Sort_Value(Right, SortMode)

        if LeftValue ~= RightValue then
            return LeftValue > RightValue
        end

        local LeftRarity = InventoryMath.GetRarityRank(Left.Rarity)
        local RightRarity = InventoryMath.GetRarityRank(Right.Rarity)

        if LeftRarity ~= RightRarity then
            return LeftRarity > RightRarity
        end

        local LeftName = if type(Left.Name) == "string" then Left.Name else ""
        local RightName = if type(Right.Name) == "string" then Right.Name else ""

        if LeftName ~= RightName then
            return LeftName < RightName
        end

        return Get_Card_Key(Left) < Get_Card_Key(Right)
    end)
end

local function Update_Cards(Items: { any })
    local AliveCards = {}
    local VisibleIndex = 0

    for _, Item in Items do
        local Key = Get_Card_Key(Item)
        local Card = State.Cards[Key]

        State.CardItems[Key] = Item

        if Get_Item_Slot(Item) then
            if Card then
                Card:Destroy()
                State.Cards[Key] = nil
            end

            continue
        end

        if not Should_Show_Inventory_Card(Item) then
            if Card then
                Card.Visible = false
                Set_Inventory_Equipped_Stroke(Card, false)
            end

            AliveCards[Key] = true
            continue
        end

        if not Card or not Card.Parent then
            Card = Create_Card(Item)
            State.Cards[Key] = Card
        end

        if Card then
            VisibleIndex += 1
            Card.LayoutOrder = VisibleIndex
            Card.Visible = true
            Card:SetAttribute("InventoryItemId", Get_Id(Item))
            Card:SetAttribute("InventoryItemType", Get_Type(Item))
            Set_Card_Text(Card, Item)
            Set_Inventory_Equipped_Stroke(Card, State.EquippedInventoryItemKey == Key)
            Bind_Draggable_Frame(Card, Item, nil)
        end

        AliveCards[Key] = true
    end

    for Key, Card in State.Cards do
        if not AliveCards[Key] then
            Card:Destroy()
            State.Cards[Key] = nil
            State.CardItems[Key] = nil
        end
    end

    Update_Content_Canvas_Size()
    State.LastVisibleCardsSignature = Get_Rendered_Visible_Cards_Signature()
end

Clear_Hotbar_Icon = function(Slot: number)
    local Icons = State.HotbarIcons[Slot]

    if Icons then
        for _, Icon in Icons do
            if Icon and Icon.Parent then
                Icon:Destroy()
            end
        end

        State.HotbarIcons[Slot] = nil
    end

    if State.ItemButtons then
        local ButtonName = CUSTOM_SLOT_NAMES[Slot]
        local Button = State.ItemButtons:FindFirstChild(ButtonName)

        if Button and Button:IsA("GuiObject") then
            for _, Child in Button:GetChildren() do
                if Child:IsA("GuiObject") and Child:GetAttribute(HOTBAR_SLOT_ATTRIBUTE) == Slot then
                    Child:Destroy()
                end
            end

            Button:SetAttribute("InventoryItemId", nil)
            Button:SetAttribute("InventoryItemType", nil)
        end
    end
end

local function Find_Favorite_Template_Visual(Template: GuiObject?): GuiObject?
    if not Template then
        return nil
    end

    if Is_Favorite_Visual(Template) then
        return Template
    end

    for _, Descendant in Template:GetDescendants() do
        if Descendant:IsA("GuiObject") and Is_Favorite_Visual(Descendant) then
            return Descendant
        end
    end

    return nil
end

local function Setup_Hotbar_Favorite_Icon(Star: GuiObject, Button: GuiObject, Slot: number): GuiObject
    Star.Name = "FavoriteStar"
    Star:SetAttribute("InventoryGenerated", true)
    Star:SetAttribute(HOTBAR_SLOT_ATTRIBUTE, Slot)
    Star.Active = false
    Star.Visible = true
    Star.ZIndex = math.max(Star.ZIndex, Button.ZIndex + 12)
    Star.Parent = Button

    for _, Descendant in Star:GetDescendants() do
        if Descendant:IsA("GuiObject") then
            Descendant.Active = false
            Descendant.Visible = true
            Descendant.ZIndex = math.max(Descendant.ZIndex, Star.ZIndex + 1)
        end
    end

    return Star
end

local function Create_Hotbar_Favorite_Icon(Button: GuiObject, Slot: number, Template: GuiObject?): GuiObject
    local TemplateStar = Find_Favorite_Template_Visual(Template)

    if TemplateStar then
        return Setup_Hotbar_Favorite_Icon(TemplateStar:Clone(), Button, Slot)
    end

    local Star = Instance.new("ImageLabel")

    Star.AnchorPoint = Vector2.new(0.5, 0.5)
    Star.BackgroundTransparency = 1
    Star.BorderSizePixel = 0
    Star.Image = "rbxassetid://113915775951610"
    Star.Position = UDim2.fromScale(0.8, 0.2)
    Star.ScaleType = Enum.ScaleType.Fit
    Star.Size = UDim2.fromScale(0.344, 0.452)

    return Setup_Hotbar_Favorite_Icon(Star, Button, Slot)
end

local function Create_Hotbar_Icon(Button: GuiObject, Item: any, Slot: number): { GuiObject }
    local Template = Get_Template(Item.Rarity)
    local Icons = {}

    Button:SetAttribute("InventoryItemId", Get_Id(Item))
    Button:SetAttribute("InventoryItemType", Get_Type(Item))

    if Template then
        for _, ObjectName in { "Icon", "IncomePerSec", "Weight" } do
            local Clone = Clone_Template_Display_Object(Template, ObjectName, Button, Button.ZIndex + 1, Item)

            if Clone then
                Clone:SetAttribute(HOTBAR_SLOT_ATTRIBUTE, Slot)
                table.insert(Icons, Clone)
            end
        end
    else
        local Icon = Instance.new("ImageLabel")
        Icon.Name = "Icon"
        Icon:SetAttribute("InventoryGenerated", true)
        Icon:SetAttribute(HOTBAR_SLOT_ATTRIBUTE, Slot)
        Icon:SetAttribute("InventoryItemId", Get_Id(Item))
        Icon:SetAttribute("InventoryItemType", Get_Type(Item))
        Icon.BackgroundTransparency = 1
        Icon.BorderSizePixel = 0
        Icon.AnchorPoint = Vector2.new(0.5, 0.5)
        Icon.Position = UDim2.fromScale(0.5, 0.5)
        Icon.Size = UDim2.fromScale(0.75, 0.75)
        Icon.ZIndex = Button.ZIndex + 1
        Icon.Parent = Button
        table.insert(Icons, Icon)
    end

    Set_Card_Text(Button, Item)

    if Get_Item_Favorite(Item) then
        table.insert(Icons, Create_Hotbar_Favorite_Icon(Button, Slot, Template))
    end

    Bind_Hotbar_Slot_Drag(Button, Slot)

    return Icons
end

local function Update_Hotbar(Items: { any })
    if not State.ItemButtons then
        return
    end

    local Assignments = Get_Hotbar_Assignments()

    for _, Slot in CUSTOM_SLOTS do
        if Clear_Hotbar_Icon then
            Clear_Hotbar_Icon(Slot)
        end

        local Assignment = Assignments[Slot]
        local ButtonName = CUSTOM_SLOT_NAMES[Slot]
        local Button = State.ItemButtons:FindFirstChild(ButtonName)

        if not Assignment or not Button or not Button:IsA("GuiObject") then
            if Button and Button:IsA("GuiObject") then
                Bind_Hotbar_Slot_Drag(Button, Slot)
            end

            continue
        end

        local Item = Find_Item_By_Assignment(Items, Assignment)

        if Item then
            State.HotbarIcons[Slot] = Create_Hotbar_Icon(Button, Item, Slot)
        end
    end
end

local function Refresh()
    if not State.Content then
        return
    end

    local Items = Get_All_Items()

    Sort_Items(Items)
    Update_Cards(Items)
    Update_Hotbar(Items)
end

local function Get_Template_Cell_Size(): UDim2
    for _, Template in State.Templates do
        if Template.Size ~= UDim2.new() then
            return Template.Size
        end
    end

    return UDim2.fromOffset(120, 120)
end

local function Ensure_Grid_Layout(Content: GuiObject)
    local ExistingGrid = Content:FindFirstChildOfClass("UIGridLayout")

    if ExistingGrid then
        ExistingGrid.SortOrder = Enum.SortOrder.LayoutOrder
        return
    end

    if Content:FindFirstChildOfClass("UIListLayout") then
        return
    end

    local Grid = Instance.new("UIGridLayout")
    Grid.Name = "InventoryGeneratedGridLayout"
    Grid.SortOrder = Enum.SortOrder.LayoutOrder
    Grid.CellSize = Get_Template_Cell_Size()
    Grid.CellPadding = UDim2.fromOffset(8, 8)
    Grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Grid.Parent = Content
end

local function Cache_Templates(Inventory: GuiObject)
    local Items = Inventory:FindFirstChild("Items")
    local Content = Items and Items:FindFirstChild("content")

    if not Content or not Content:IsA("GuiObject") then
        return
    end

    State.Content = Content

    for _, Child in Content:GetChildren() do
        if
            Child:IsA("GuiObject")
            and VALID_TEMPLATE_NAMES[Child.Name]
            and not Child:GetAttribute("InventoryGenerated")
        then
            State.Templates[Child.Name] = Child
            Child.Visible = false
        end
    end

    Ensure_Grid_Layout(Content)
end

local function Get_Button_Text(Button: GuiButton): string
    local TextParts = { Button.Name }

    if Button:IsA("TextButton") then
        table.insert(TextParts, Button.Text)
    end

    for _, Descendant in Button:GetDescendants() do
        if Descendant:IsA("TextLabel") or Descendant:IsA("TextButton") then
            table.insert(TextParts, Descendant.Text)
        end
    end

    return string.lower(table.concat(TextParts, " "))
end

local function Bind_Gui_Buttons(Root: Instance?, AttributeName: string, Callback: () -> ())
    if not Root then
        return
    end

    if Root:IsA("GuiButton") and not Root:GetAttribute(AttributeName) then
        Root:SetAttribute(AttributeName, true)
        Root.Activated:Connect(Callback)
    end

    for _, Descendant in Root:GetDescendants() do
        if not Descendant:IsA("GuiButton") or Descendant:GetAttribute(AttributeName) then
            continue
        end

        Descendant:SetAttribute(AttributeName, true)
        Descendant.Activated:Connect(Callback)
    end
end

local function Queue_Search_Text(Text: string)
    State.SearchText = Text
    State.SearchToken += 1

    local Token = State.SearchToken

    task.delay(SEARCH_DEBOUNCE_SECONDS, function()
        if State.SearchToken ~= Token then
            return
        end

        Set_Dirty()
    end)
end

local function Bind_Search_Bar(Inventory: GuiObject)
    local SearchBar = Inventory:FindFirstChild("Search Bar")

    if not SearchBar then
        return
    end

    local function Bind_Text_Box(TextBox: TextBox)
        if TextBox:GetAttribute("InventorySearchBound") then
            return
        end

        TextBox:SetAttribute("InventorySearchBound", true)
        table.insert(State.SearchBoxes, TextBox)
        Queue_Search_Text(TextBox.Text)
        TextBox:GetPropertyChangedSignal("Text"):Connect(function()
            Queue_Search_Text(TextBox.Text)
        end)
    end

    if SearchBar:IsA("TextBox") then
        Bind_Text_Box(SearchBar)
    end

    for _, Descendant in SearchBar:GetDescendants() do
        if Descendant:IsA("TextBox") then
            Bind_Text_Box(Descendant)
        end
    end
end

local function Get_Tab_For_Button(Button: GuiButton): string?
    local ButtonText = Get_Button_Text(Button)

    if string.find(ButtonText, "food", 1, true) then
        return "Food"
    end

    if
        string.find(ButtonText, "squishy", 1, true)
        or string.find(ButtonText, "squish", 1, true)
        or string.find(ButtonText, "pets", 1, true)
    then
        return "Squishy"
    end

    return nil
end

local function Track_Tab_Button(Tab: string, Button: GuiButton)
    local Buttons = State.TabButtons[Tab]

    if not Buttons then
        Buttons = {}
        State.TabButtons[Tab] = Buttons
    end

    for _, Existing in Buttons do
        if Existing == Button then
            return
        end
    end

    table.insert(Buttons, Button)
end

local function Bind_Tab_Buttons(Inventory: GuiObject)
    local Tabs = Inventory:FindFirstChild("Tabs")

    if not Tabs then
        return
    end

    for _, Descendant in Tabs:GetDescendants() do
        if not Descendant:IsA("GuiButton") then
            continue
        end

        local Tab = Get_Tab_For_Button(Descendant)

        if not Tab then
            continue
        end

        Track_Tab_Button(Tab, Descendant)

        if Descendant:GetAttribute("InventoryTabBound") then
            continue
        end

        Descendant:SetAttribute("InventoryTabBound", true)
        Descendant.Activated:Connect(function()
            State.ActiveTab = if State.ActiveTab == Tab then nil else Tab
            Update_Tab_Button_Visuals()
            Set_Dirty()
        end)
    end

    Update_Tab_Button_Visuals()
end

local function Bind_Favorite_Button(Inventory: GuiObject)
    Bind_Gui_Buttons(Inventory:FindFirstChild("Favorite"), "InventoryFavoriteBound", Toggle_Selected_Favorite)
end

local function Bind_Equip_Best_Button(Inventory: GuiObject)
    Bind_Gui_Buttons(Inventory:FindFirstChild("Equip Best Pet"), "InventoryEquipBestBound", Equip_Best_Squishies)
end

local function Get_Sort_Mode_For_Button(Button: GuiButton): string?
    local ButtonText = Get_Button_Text(Button)

    for SortMode in SORT_MODES do
        if string.find(ButtonText, string.lower(SortMode), 1, true) then
            return SortMode
        end
    end

    return nil
end

local function Bind_Sort_Buttons(Inventory: GuiObject)
    local SortTabs = Inventory:FindFirstChild("Sort Tabs")

    if not SortTabs then
        return
    end

    for _, Descendant in SortTabs:GetDescendants() do
        if not Descendant:IsA("GuiButton") or Descendant:GetAttribute("InventorySortBound") then
            continue
        end

        local SortMode = Get_Sort_Mode_For_Button(Descendant)

        if not SortMode then
            continue
        end

        Descendant:SetAttribute("InventorySortBound", true)
        Descendant.Activated:Connect(function()
            State.SortMode = SortMode
            Set_Dirty()
        end)
    end
end

local function Bind_Global_Drag_Input()
    if State.Bound then
        return
    end

    State.Bound = true

    UserInputService.InputChanged:Connect(function(Input: InputObject)
        if not State.PendingDrag and not State.ActiveDrag then
            return
        end

        if
            Input.UserInputType ~= Enum.UserInputType.MouseMovement
            and Input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end

        local Point = Get_Input_Point(Input)

        if State.ActiveDrag then
            State.ActiveDrag.LastPoint = Point
            Set_Frame_Point(State.ActiveDrag.Clone, Point)
            return
        end

        local PendingDrag = State.PendingDrag

        if PendingDrag then
            PendingDrag.LastPoint = Point
        end

        if PendingDrag and (Point - PendingDrag.StartPoint).Magnitude >= DRAG_THRESHOLD then
            Start_Drag(Point)
        end
    end)

    UserInputService.InputEnded:Connect(function(Input: InputObject)
        if
            Input.UserInputType ~= Enum.UserInputType.MouseButton1
            and Input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end

        local Point = Get_Input_Point(Input)

        if State.ActiveDrag then
            Finish_Drag(Point)
        elseif State.PendingDrag and (Point - State.PendingDrag.StartPoint).Magnitude >= DRAG_THRESHOLD then
            Start_Drag(Point)

            if State.ActiveDrag then
                Finish_Drag(Point)
            else
                End_Pending_Click()
            end
        else
            End_Pending_Click()
        end
    end)
end

function InventoryUI.Initialize(Inventory: GuiObject)
    if State.Inventory == Inventory then
        return
    end

    Clear_Generated_UI()
    State.Templates = {}
    State.Content = nil
    State.ItemButtons = nil
    State.SearchBoxes = {}
    State.TabButtons = {}
    State.ActiveTab = nil
    State.Inventory = Inventory
    State.ItemButtons = Inventory:FindFirstChild("Item Buttons")
    State.LastSquishiesRef = peek(FusionValues.OwnedSquishies)
    State.LastFoodRef = peek(FusionValues.OwnedFood)
    State.LastHotbarRef = peek(FusionValues.HotbarSlots)
    State.LastSquishiesSignature = Get_Inventory_Table_Signature(State.LastSquishiesRef)
    State.LastFoodSignature = Get_Inventory_Table_Signature(State.LastFoodRef)
    State.LastHotbarSignature = Get_Inventory_Table_Signature(State.LastHotbarRef)
    State.LastInventoryOnlySquishySignature = ""
    State.LastInventoryOnlySquishyCount = 0
    Clear_Pending_Hotbar_Assignments()
    Clear_Pending_Favorites()

    Cache_Templates(Inventory)
    Bind_Search_Bar(Inventory)
    Bind_Tab_Buttons(Inventory)
    Bind_Favorite_Button(Inventory)
    Bind_Equip_Best_Button(Inventory)
    Bind_Sort_Buttons(Inventory)
    Bind_Global_Drag_Input()
    Set_Dirty()
end

function InventoryUI.ClearInventorySelection()
    Clear_Equipped_Inventory_Item()
end

function InventoryUI.ClearTabSelection()
    if State.ActiveTab == nil then
        Update_Tab_Button_Visuals()
        return
    end

    State.ActiveTab = nil
    Update_Tab_Button_Visuals()
    Set_Dirty()
end

function InventoryUI.ToggleHotbarSlotName(SlotName: string): boolean
    local Slot = Get_Custom_Slot_Number_From_Name(SlotName)

    return if Slot then Toggle_Hotbar_Source_Slot(Slot, nil) else false
end

function InventoryUI.ShouldSuppressSlotActivated(): boolean
    if LocalPlayer:GetAttribute(INVENTORY_DRAG_ACTIVE_ATTRIBUTE) == true then
        return true
    end

    if os.clock() - State.LastDragEndTime <= CLICK_SUPPRESS_AFTER_DRAG_SECONDS then
        return true
    end

    if State.ActiveDrag then
        return true
    end

    local PendingDrag = State.PendingDrag

    if not PendingDrag then
        return false
    end

    return (Get_Input_Point(nil) - PendingDrag.StartPoint).Magnitude >= DRAG_THRESHOLD
end

function InventoryUI.Step()
    local SquishiesRef = peek(FusionValues.OwnedSquishies)
    local FoodRef = peek(FusionValues.OwnedFood)
    local HotbarRef = peek(FusionValues.HotbarSlots)
    local SquishiesSignature = Get_Inventory_Table_Signature(SquishiesRef)
    local FoodSignature = Get_Inventory_Table_Signature(FoodRef)
    local HotbarSignature = Get_Inventory_Table_Signature(HotbarRef)
    local CurrentItems = Get_All_Items()
    local ExpectedVisibleCardsSignature = Get_Expected_Visible_Cards_Signature(CurrentItems)
    local InventoryOnlySquishySignature, InventoryOnlySquishyCount = Get_Inventory_Only_Squishy_State(CurrentItems)
    local EquippedItemId = peek(FusionValues.EquippedInventoryItemId)
    local EquippedSlot = peek(FusionValues.EquippedInventorySlot)
    local EquippedHotbarSlot = if type(EquippedSlot) == "string"
        then Get_Custom_Slot_Number_From_Name(EquippedSlot)
        else nil

    if EquippedHotbarSlot then
        local Assignment = Get_Hotbar_Assignments()[EquippedHotbarSlot]

        if Assignment and not Find_Item_By_Assignment(CurrentItems, Assignment) then
            FusionValues.EquippedInventorySlot:set(nil)
            Set_Dirty()
        end
    end

    if
        State.EquippedInventoryItemKey
        and type(EquippedSlot) == "string"
        and (type(EquippedItemId) ~= "string" or EquippedItemId == "")
    then
        Clear_Equipped_Inventory_Item()
    else
        Reconcile_Equipped_Inventory_Item_Id(CurrentItems)
    end

    if State.PendingHotbarExpiresAt > 0 and os.clock() >= State.PendingHotbarExpiresAt then
        Clear_Pending_Hotbar_Assignments()
        Set_Dirty()
    end

    if State.PendingFavoriteExpiresAt > 0 and os.clock() >= State.PendingFavoriteExpiresAt then
        Clear_Pending_Favorites()
        Set_Dirty()
    end

    if State.EquippedInventoryItemKey and not Find_Item_By_Key(State.EquippedInventoryItemKey) then
        Clear_Equipped_Inventory_Item()
    end

    local HotbarChanged = HotbarRef ~= State.LastHotbarRef or HotbarSignature ~= State.LastHotbarSignature

    local InventoryChanged = SquishiesRef ~= State.LastSquishiesRef
        or FoodRef ~= State.LastFoodRef
        or SquishiesSignature ~= State.LastSquishiesSignature
        or FoodSignature ~= State.LastFoodSignature

    if InventoryChanged or HotbarChanged then
        State.LastSquishiesRef = SquishiesRef
        State.LastFoodRef = FoodRef
        State.LastHotbarRef = HotbarRef
        State.LastSquishiesSignature = SquishiesSignature
        State.LastFoodSignature = FoodSignature
        State.LastHotbarSignature = HotbarSignature

        if HotbarChanged then
            Clear_Pending_Hotbar_Assignments()
        end

        if InventoryChanged then
            Clear_Pending_Favorites()
        end

        Set_Dirty()
    end

    if InventoryOnlySquishySignature ~= State.LastInventoryOnlySquishySignature then
        if InventoryOnlySquishyCount > State.LastInventoryOnlySquishyCount then
            State.ActiveTab = nil
            Update_Tab_Button_Visuals()
            Clear_Search_Filter()
        end

        State.LastInventoryOnlySquishySignature = InventoryOnlySquishySignature
        State.LastInventoryOnlySquishyCount = InventoryOnlySquishyCount
        Set_Dirty()
    end

    if
        ExpectedVisibleCardsSignature ~= State.LastVisibleCardsSignature
        or ExpectedVisibleCardsSignature ~= Get_Rendered_Visible_Cards_Signature()
    then
        Set_Dirty()
    end

    if not State.Dirty then
        return
    end

    State.Dirty = false
    Refresh()
end

return InventoryUI
