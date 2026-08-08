local MarketPlaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Network = require(ReplicatedFirst.Network)
local peek = Fusion.peek

local Config = require(ReplicatedStorage.Shared.Config)
local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local FusionValues = require(script.Parent.FusionValues)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local BUY_BOUND_ATTRIBUTE = "FoodShopBuyBound"
local MOTION_BOUND_ATTRIBUTE = "FoodShopMotionBound"
local RESTOCK_BOUND_ATTRIBUTE = "FoodShopRestockBound"
local SERVER_EQUIPPED_SLOT_ATTRIBUTE = "ServerEquippedInventorySlot"
local RESTOCK_TIME = Config.FoodRestockTime or (60 * 5)
local TIMER_UPDATE_INTERVAL = 0.2
local CUSTOM_SLOT_MIN = 3
local CUSTOM_SLOT_MAX = 7

local MainGui: ScreenGui? = nil
local BindButtonMotion: ((GuiButton) -> ())? = nil
local IsUiBlocked: (() -> boolean)? = nil
local CloseTutorialFrame: (() -> ())? = nil
local EquipInventorySlot: ((string) -> ())? = nil
local LastTimerUpdate = 0
local RestockEndsAt = 0
local PendingEquipFoodName: string? = nil
local PendingEquipSlotName: string? = nil
local PendingEquipFoodExpiresAt = 0
local PendingEquipLastAttemptAt = 0
local LastFoodStockRef = nil
local LastOwnedFoodRef = nil
local LastTutorialStep: number? = nil
local LastTutorialStepReceived: boolean? = nil

local function Get_Frame(): Instance?
    if not MainGui then
        return nil
    end

    local Frames = MainGui:FindFirstChild("Frames")

    return Frames and Frames:FindFirstChild("FoodShop") or nil
end

local function Get_Content(): Instance?
    local Frame = Get_Frame()

    return Frame and (Frame:FindFirstChild("content") or Frame:FindFirstChild("Content")) or nil
end

local function Format_Cash(Amount: number): string
    return "$" .. Util.Abbreviate_Number(math.max(0, math.floor(Amount)), 1)
end

local function Format_Timer(Seconds: number): string
    local Remaining = math.max(0, math.floor(Seconds))
    local Minutes = math.floor(Remaining / 60)
    local SecondsLeft = Remaining % 60

    return string.format("Restocks in: %02d:%02d", Minutes, SecondsLeft)
end

local function Find_Card(FoodData: Foods.FoodData): Instance?
    local Content = Get_Content()

    if not Content then
        return nil
    end

    local CardName = FoodData.ShopCardName or FoodData.Rarity

    return Content:FindFirstChild(CardName)
end

local function Find_Text_Label(Parent: Instance?, Name: string): TextLabel?
    local Child = Parent and Parent:FindFirstChild(Name)

    if Child and Child:IsA("TextLabel") then
        return Child
    end

    return nil
end

local function Find_Stock_Label(Card: Instance): TextLabel?
    local Direct = Card:FindFirstChild("Stock : 5")

    if Direct and Direct:IsA("TextLabel") then
        return Direct
    end

    for _, Child in Card:GetChildren() do
        if Child:IsA("TextLabel") and string.find(string.lower(Child.Name), "stock", 1, true) then
            return Child
        end
    end

    return nil
end

local function Get_Food_Stock(FoodName: string): number
    local Stock = peek(FusionValues.FoodStock)
    local Value = if type(Stock) == "table" then Stock[FoodName] else nil

    if type(Value) ~= "number" or Value ~= Value then
        return 0
    end

    return math.max(0, math.floor(Value :: number))
end

local function Is_Tutorial_Active(): boolean
    if peek(FusionValues.TutorialStepReceived) ~= true then
        return false
    end

    return not TutorialSteps.Is_Complete(TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep)))
end

local function Is_Tutorial_Food_Buy_Step(): boolean
    return Is_Tutorial_Active()
end

local function Is_Tutorial_Food_Buy(FoodName: string): boolean
    return Is_Tutorial_Food_Buy_Step() and FoodName == TutorialSteps.FeedName
end

local function Normalize_Custom_Slot(Value: any): number?
    local Slot = if type(Value) == "number" then Value else tonumber(Value)

    if not Slot or Slot ~= Slot then
        return nil
    end

    Slot = math.floor(Slot)

    return if Slot >= CUSTOM_SLOT_MIN and Slot <= CUSTOM_SLOT_MAX then Slot else nil
end

local function Find_Food_Hotbar_Slot(FoodName: string): string?
    local HotbarSlots = peek(FusionValues.HotbarSlots)

    if type(HotbarSlots) == "table" then
        for Key, Assignment in HotbarSlots do
            if
                type(Assignment) == "table"
                and Assignment.ItemType == "Food"
                and Assignment.ItemId == FoodName
                and type(Assignment.Slot) == "number"
            then
                return tostring(Assignment.Slot)
            end

            if type(Assignment) == "table" and Assignment.ItemType == "Food" and Assignment.ItemId == FoodName then
                return tostring(Key)
            end
        end
    end

    local OwnedFood = peek(FusionValues.OwnedFood)

    if type(OwnedFood) == "table" then
        for _, Entry in OwnedFood do
            if type(Entry) == "table" and Entry.Id == FoodName and type(Entry.HotbarSlot) == "number" then
                return tostring(Entry.HotbarSlot)
            end
        end
    end

    return nil
end

local function Find_First_Open_Hotbar_Slot(): string?
    local HotbarSlots = peek(FusionValues.HotbarSlots)
    local Occupied = {}

    if type(HotbarSlots) == "table" then
        for Key, Assignment in HotbarSlots do
            if type(Assignment) ~= "table" then
                continue
            end

            local Slot = Normalize_Custom_Slot(Assignment.Slot) or Normalize_Custom_Slot(Key)

            if Slot then
                Occupied[Slot] = true
            end
        end
    end

    for Slot = CUSTOM_SLOT_MIN, CUSTOM_SLOT_MAX do
        if not Occupied[Slot] then
            return tostring(Slot)
        end
    end

    return nil
end

local function Try_Equip_Food(FoodName: string): boolean
    if not EquipInventorySlot then
        return false
    end

    local SlotName = Find_Food_Hotbar_Slot(FoodName) or PendingEquipSlotName

    if not SlotName then
        return false
    end

    EquipInventorySlot(SlotName)

    return LocalPlayer:GetAttribute(SERVER_EQUIPPED_SLOT_ATTRIBUTE) == SlotName
end

local function Queue_Equip_Food(FoodName: string)
    PendingEquipFoodName = FoodName
    PendingEquipSlotName = Find_First_Open_Hotbar_Slot()
    PendingEquipFoodExpiresAt = os.clock() + 10
    PendingEquipLastAttemptAt = 0
    Try_Equip_Food(FoodName)
end

local function Step_Pending_Equip_Food()
    if not PendingEquipFoodName then
        return
    end

    local Now = os.clock()

    if Now - PendingEquipLastAttemptAt < 0.12 and Now < PendingEquipFoodExpiresAt then
        return
    end

    PendingEquipLastAttemptAt = Now

    if Try_Equip_Food(PendingEquipFoodName) or Now >= PendingEquipFoodExpiresAt then
        PendingEquipFoodName = nil
        PendingEquipSlotName = nil
        PendingEquipFoodExpiresAt = 0
        PendingEquipLastAttemptAt = 0
    end
end

local function Bind_Motion(Button: Instance?)
    if not Button or not Button:IsA("GuiButton") or Button:GetAttribute(MOTION_BOUND_ATTRIBUTE) then
        return
    end

    Button:SetAttribute(MOTION_BOUND_ATTRIBUTE, true)

    if BindButtonMotion then
        BindButtonMotion(Button)
    end
end

local function Bind_Buy_Button(Button: Instance?, FoodData: Foods.FoodData)
    Bind_Motion(Button)

    if not Button or not Button:IsA("GuiButton") or Button:GetAttribute(BUY_BOUND_ATTRIBUTE) then
        return
    end

    Button:SetAttribute(BUY_BOUND_ATTRIBUTE, true)
    Button.Activated:Connect(function()
        local FoodName = FoodData.Name

        if IsUiBlocked and IsUiBlocked() then
            return
        end

        Network.BuyFood.Fire(FoodName)

        if Is_Tutorial_Food_Buy(FoodName) then
            Queue_Equip_Food(FoodName)
        end

        if Is_Tutorial_Food_Buy(FoodName) and CloseTutorialFrame then
            CloseTutorialFrame()
        end
    end)
end

local function Set_Button_Label(Button: Instance?, Text: string)
    if not Button then
        return
    end

    local Label = if Button:IsA("TextLabel") then Button else Button:FindFirstChildWhichIsA("TextLabel", true)

    if Label and Label:IsA("TextLabel") then
        Label.Text = Text
    end
end

local function Set_Button_Enabled(Button: Instance?, Enabled: boolean)
    if not Button or not Button:IsA("GuiButton") then
        return
    end

    Button.Active = Enabled
    Button.Interactable = Enabled
    Button.AutoButtonColor = Enabled
end

local function Update_Display_Image(Card: Instance, Image: string)
    local Display = Card:FindFirstChild("Display")

    if not Display then
        return
    end

    local ItemDisplay = Display:FindFirstChild("itemdisplay", true)

    if ItemDisplay and (ItemDisplay:IsA("ImageLabel") or ItemDisplay:IsA("ImageButton")) then
        (ItemDisplay :: ImageLabel).Image = Image
    end
end

local function Update_Food_Card(FoodData: Foods.FoodData)
    local Card = Find_Card(FoodData)

    if not Card then
        return
    end

    Update_Display_Image(Card, FoodData.Image)

    local PriceLabel = Find_Text_Label(Card, "Price")
    local StockLabel = Find_Stock_Label(Card)
    local BuyButton = Card:FindFirstChild("Buy Button")
    local RobuxButton = Card:FindFirstChild("Robux Button")
    local GiftButton = Card:FindFirstChild("Gift Button") or Card:FindFirstChild("Gift")
    local OutOfStock = Card:FindFirstChild("OutOfStock")
    local IsTutorialBuyStep = Is_Tutorial_Food_Buy_Step()
    local IsTutorialBuy = Is_Tutorial_Food_Buy(FoodData.Name)
    local IsTutorialBlocked = IsTutorialBuyStep and not IsTutorialBuy
    local Stock = if IsTutorialBuy
        then math.max(1, Get_Food_Stock(FoodData.Name))
        elseif IsTutorialBlocked then 0
        else Get_Food_Stock(FoodData.Name)

    if PriceLabel then
        PriceLabel.Text = if IsTutorialBuy then "FREE" else Format_Cash(FoodData.Price)
    end

    if StockLabel then
        StockLabel.Text = `Stock: {Stock}`
    end

    Bind_Buy_Button(BuyButton, FoodData)
    Set_Button_Label(BuyButton, if IsTutorialBuy then "FREE" else "Buy")
    Bind_Motion(RobuxButton)
    Bind_Motion(GiftButton)
    Set_Button_Enabled(BuyButton, Stock > 0 and not IsTutorialBlocked)
    Set_Button_Enabled(RobuxButton, not IsTutorialBlocked)
    Set_Button_Enabled(GiftButton, not IsTutorialBlocked)

    if OutOfStock and OutOfStock:IsA("GuiObject") then
        OutOfStock.Visible = IsTutorialBlocked or Stock <= 0
    end
end

local function Bind_Restock_Button()
    local Frame = Get_Frame()
    local RestockButton = Frame and Frame:FindFirstChild("Restock")

    Bind_Motion(RestockButton)

    if
        not RestockButton
        or not RestockButton:IsA("GuiButton")
        or RestockButton:GetAttribute(RESTOCK_BOUND_ATTRIBUTE)
    then
        return
    end

    RestockButton:SetAttribute(RESTOCK_BOUND_ATTRIBUTE, true)
    RestockButton.Activated:Connect(function()
        if IsUiBlocked and IsUiBlocked() then
            return
        end

        MarketPlaceService:PromptProductPurchase(LocalPlayer, RobuxProducts.Products.Restock.ProductId)
    end)
end

local function Receive_Restock_End_Time()
    for _, EndTime in Network.FoodRestockEndTimeChanged.Iter() do
        if type(EndTime) == "number" and EndTime == EndTime then
            RestockEndsAt = math.max(0, math.floor(EndTime))
            LastTimerUpdate = 0
        end
    end
end

local function Get_Restock_End_Time(): number
    if RestockEndsAt > 0 then
        return RestockEndsAt
    end

    local LastRestock = peek(FusionValues.LastFoodRestock)

    if type(LastRestock) ~= "number" or LastRestock <= 0 or LastRestock ~= LastRestock then
        return 0
    end

    return math.max(0, math.floor(LastRestock + RESTOCK_TIME))
end

local function Update_Restock_Timer()
    local Now = os.clock()

    if Now - LastTimerUpdate < TIMER_UPDATE_INTERVAL then
        return
    end

    LastTimerUpdate = Now

    local Frame = Get_Frame()
    local TimeLabel = Find_Text_Label(Frame, "Time")

    if not TimeLabel then
        return
    end

    local EndTime = Get_Restock_End_Time()
    local Remaining = if EndTime > 0 then EndTime - Workspace:GetServerTimeNow() else 0

    TimeLabel.Text = Format_Timer(Remaining)
end

local function Bind_All()
    Receive_Restock_End_Time()

    for _, FoodName in Foods.Order do
        local FoodData = Foods.Get(FoodName)

        if FoodData then
            Update_Food_Card(FoodData)
        end
    end

    Bind_Restock_Button()
    Update_Restock_Timer()
end

local function Should_Update_Food_Cards(): boolean
    local FoodStock = peek(FusionValues.FoodStock)
    local OwnedFood = peek(FusionValues.OwnedFood)
    local TutorialStep = peek(FusionValues.TutorialStep)
    local TutorialStepReceived = peek(FusionValues.TutorialStepReceived)

    if
        FoodStock == LastFoodStockRef
        and OwnedFood == LastOwnedFoodRef
        and TutorialStep == LastTutorialStep
        and TutorialStepReceived == LastTutorialStepReceived
    then
        return false
    end

    LastFoodStockRef = FoodStock
    LastOwnedFoodRef = OwnedFood
    LastTutorialStep = TutorialStep
    LastTutorialStepReceived = TutorialStepReceived

    return true
end

local FoodShopUI = {}

function FoodShopUI.Initialize(
    Gui: ScreenGui,
    ButtonMotion: (GuiButton) -> (),
    UiBlocked: () -> boolean,
    TutorialClose: (() -> ())?,
    EquipSlot: ((string) -> ())?
)
    MainGui = Gui
    BindButtonMotion = ButtonMotion
    IsUiBlocked = UiBlocked
    CloseTutorialFrame = TutorialClose
    EquipInventorySlot = EquipSlot
    LastTimerUpdate = 0
    LastFoodStockRef = nil
    LastOwnedFoodRef = nil
    LastTutorialStep = nil
    LastTutorialStepReceived = nil

    Bind_All()
end

function FoodShopUI.Step()
    Step_Pending_Equip_Food()
    Receive_Restock_End_Time()
    Bind_Restock_Button()

    if Should_Update_Food_Cards() then
        for _, FoodName in Foods.Order do
            local FoodData = Foods.Get(FoodName)

            if FoodData then
                Update_Food_Card(FoodData)
            end
        end
    end

    Update_Restock_Timer()
end

return table.freeze(FoodShopUI)
