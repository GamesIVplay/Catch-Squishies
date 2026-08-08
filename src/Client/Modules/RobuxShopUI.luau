local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EzVisualz = require(ReplicatedStorage.Packages.EzVisualz)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local LocalPlayer = Players.LocalPlayer
local DEVELOPER_PRODUCT_ATTRIBUTE = "DeveloperProduct"
local PRODUCT_PRICE_ATTRIBUTE = "ProductPrice"
local GAMEPASS_ATTRIBUTE = "Gamepass"
local GAMEPASS_ATTRIBUTE_ALTERNATE = "GamePass"
local BOUND_ATTRIBUTE = "RobuxShopPurchaseBound"
local PRICE_BOUND_ATTRIBUTE = "RobuxShopPriceBound"
local PRICE_WAIT_KEY_ATTRIBUTE = "RobuxShopPriceWaitKey"
local PRODUCT_KEY_ATTRIBUTE = "RobuxShopProductKey"
local PROMPT_DISABLED_ATTRIBUTE = "RobuxShopPromptDisabled"
local ICON_HOVER_BOUND_ATTRIBUTE = "RobuxShopIconHoverBound"
local ICON_FLOAT_BOUND_ATTRIBUTE = "RobuxShopIconFloatBound"
local RAINBOW_BOUND_ATTRIBUTE = "RobuxShopRainbowBound"
local HUD_OFFER_AVAILABLE_ATTRIBUTE = "HudOfferAvailable"
local STARTER_PACK_TIMER_SECONDS = 10 * 60
local LUCKY_BLOCK_TIMER_SECONDS = 24 * 60 * 60
local TIMER_UPDATE_INTERVAL = 0.2
local HUD_OFFER_ROTATION_INTERVAL = 10
local PLOT_SIGN_BIND_INTERVAL = 0.5
local ICON_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ICON_HOVER_SCALE = 1.06
local ICON_FLOAT_DURATION_BASE = 2.8
local ICON_FLOAT_DURATION_STEP = 0.24
local ICON_FLOAT_PHASE_STEP = 0.35
local ICON_FLOAT_OFFSET_Y = -4
local RAINBOW_EFFECT_SPEED = 0.3

type PurchaseInfo = {
    Id: number,
    InfoType: Enum.InfoType,
}

type IconFloatState = {
    BasePosition: UDim2,
    Active: boolean,
    Duration: number,
    Phase: number,
    OffsetY: number,
}

local MainGui: ScreenGui? = nil
local BindButtonMotion: ((GuiButton) -> ())? = nil
local IsUiBlocked: (() -> boolean)? = nil
local ProductPriceCache: { [string]: string? } = {}
local ProductPriceWaiters: { [string]: boolean } = {}
local TimerStartedAt = os.clock()
local LastTimerUpdate = 0
local LastPlotSignBindAt = 0
local CurrentHudOfferIndex = 1
local LastHudOfferRotationAt = os.clock()
local LastTimerTextByLabel: { [TextLabel]: string } = {}
local RainbowEffects: { [GuiObject]: any } = {}
local IconFloatStates: { [GuiObject]: IconFloatState } = {}
local IconFloatRenderConnection: RBXScriptConnection? = nil

local function Get_Frames(): Instance?
    return MainGui and MainGui:FindFirstChild("Frames") or nil
end

local function Get_Hud(): Instance?
    return MainGui and MainGui:FindFirstChild("Hud Frame") or nil
end

local function Normalize_Name(Name: string): string
    return string.lower((Name:gsub("[%s_%-%./]", "")))
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

local function Find_By_Path(Root: Instance?, Path: { string }): Instance?
    local Current = Root

    for _, Name in Path do
        if not Current then
            return nil
        end

        Current = Current:FindFirstChild(Name)
    end

    return Current
end

local function Tween(InstanceToTween: Instance, Info: TweenInfo, Properties)
    local CreatedTween = TweenService:Create(InstanceToTween, Info, Properties)
    CreatedTween:Play()

    return CreatedTween
end

local function Get_Or_Create_Scale(GuiObject: GuiObject, ScaleName: string): UIScale
    local Scale = GuiObject:FindFirstChild(ScaleName)

    if Scale and Scale:IsA("UIScale") then
        return Scale
    end

    Scale = Instance.new("UIScale")
    Scale.Name = ScaleName
    Scale.Scale = 1
    Scale.Parent = GuiObject

    return Scale
end

local function Normalize_Purchase_Id(Value): number?
    local PurchaseId = if type(Value) == "number" then Value else tonumber(Value)

    if not PurchaseId or PurchaseId <= 0 then
        return nil
    end

    return math.floor(PurchaseId)
end

local function Get_Prompt_Purchase_Info(Button: GuiButton): PurchaseInfo?
    local ProductId = Normalize_Purchase_Id(Button:GetAttribute(DEVELOPER_PRODUCT_ATTRIBUTE))

    if ProductId then
        return {
            Id = ProductId,
            InfoType = Enum.InfoType.Product,
        }
    end

    local GamepassId = Normalize_Purchase_Id(Button:GetAttribute(GAMEPASS_ATTRIBUTE))
        or Normalize_Purchase_Id(Button:GetAttribute(GAMEPASS_ATTRIBUTE_ALTERNATE))

    if GamepassId then
        return {
            Id = GamepassId,
            InfoType = Enum.InfoType.GamePass,
        }
    end

    return nil
end

local function Get_Price_Purchase_Info(Button: GuiButton): PurchaseInfo?
    local PromptInfo = Get_Prompt_Purchase_Info(Button)

    if PromptInfo then
        return PromptInfo
    end

    local ProductId = Normalize_Purchase_Id(Button:GetAttribute(PRODUCT_PRICE_ATTRIBUTE))

    if ProductId then
        return {
            Id = ProductId,
            InfoType = Enum.InfoType.Product,
        }
    end

    return nil
end

local function Is_In_Price_Frame(Label: TextLabel, Button: GuiButton): boolean
    local Current = Label.Parent

    while Current and Current ~= Button do
        local Name = Normalize_Name(Current.Name)

        if Name == "price" or Name == "robuxprice" or string.find(Name, "price", 1, true) then
            return true
        end

        Current = Current.Parent
    end

    return false
end

local function Is_Direct_Price_Label(Label: TextLabel, Button: GuiButton): boolean
    local Current = Label.Parent

    while Current and Current ~= Button do
        if Current:IsA("GuiButton") then
            return false
        end

        Current = Current.Parent
    end

    if Current ~= Button then
        return false
    end

    local Name = Normalize_Name(Label.Name)
    local Text = string.gsub(Label.Text, "%s+", "")

    return string.match(Name, "^%d+$") ~= nil
        or Name == "price"
        or Name == "robuxprice"
        or string.find(Name, "price", 1, true) ~= nil
        or string.match(Text, "^%d+$") ~= nil
        or string.match(Text, "^R%$%d+$") ~= nil
end

local function Find_Price_Labels(Button: GuiButton): { TextLabel }
    local Labels = {}

    for _, Descendant in Button:GetDescendants() do
        if Descendant:IsA("TextLabel") and Is_In_Price_Frame(Descendant, Button) then
            table.insert(Labels, Descendant)
        end
    end

    if #Labels > 0 then
        return Labels
    end

    for _, Descendant in Button:GetDescendants() do
        if Descendant:IsA("TextLabel") and Is_Direct_Price_Label(Descendant, Button) then
            table.insert(Labels, Descendant)
        end
    end

    return Labels
end

local function Get_Price_Label_Prefix(Label: TextLabel): string
    local Prefix = Label.Text:match("^(.-)%d")

    if type(Prefix) == "string" then
        return Prefix
    end

    return ""
end

local function Set_Button_Price_Text(Button: GuiButton, PriceText: string)
    for _, Label in Find_Price_Labels(Button) do
        Label.Text = Get_Price_Label_Prefix(Label) .. PriceText
    end
end

local function Get_Price_Cache_Key(PurchaseInfo: PurchaseInfo): string
    return `{PurchaseInfo.InfoType.Name}:{PurchaseInfo.Id}`
end

local function Resolve_Product_Price(PurchaseInfo: PurchaseInfo): string?
    local CacheKey = Get_Price_Cache_Key(PurchaseInfo)

    if ProductPriceCache[CacheKey] ~= nil then
        return ProductPriceCache[CacheKey]
    end

    if ProductPriceWaiters[CacheKey] then
        return nil
    end

    ProductPriceWaiters[CacheKey] = true

    task.spawn(function()
        local ProductInfo = if PurchaseInfo.InfoType == Enum.InfoType.GamePass
            then Util.Get_Gamepass_Info(PurchaseInfo.Id)
            else Util.Get_Product_Info(PurchaseInfo.Id)
        local PriceText = nil

        if type(ProductInfo) == "table" and type(ProductInfo.PriceInRobux) == "number" then
            PriceText = tostring(ProductInfo.PriceInRobux)
        end

        ProductPriceCache[CacheKey] = PriceText
        ProductPriceWaiters[CacheKey] = nil
    end)

    return nil
end

local function Update_Button_Price(Button: GuiButton)
    if Button:GetAttribute(PROMPT_DISABLED_ATTRIBUTE) then
        return
    end

    local PurchaseInfo = Get_Price_Purchase_Info(Button)

    if not PurchaseInfo then
        return
    end

    local PriceText = Resolve_Product_Price(PurchaseInfo)

    if PriceText then
        Set_Button_Price_Text(Button, PriceText)
        return
    end

    local CacheKey = Get_Price_Cache_Key(PurchaseInfo)

    if Button:GetAttribute(PRICE_WAIT_KEY_ATTRIBUTE) == CacheKey then
        return
    end

    Button:SetAttribute(PRICE_WAIT_KEY_ATTRIBUTE, CacheKey)

    task.spawn(function()
        while Button.Parent and ProductPriceWaiters[CacheKey] do
            task.wait(0.1)
        end

        if Button:GetAttribute(PRICE_WAIT_KEY_ATTRIBUTE) == CacheKey then
            Button:SetAttribute(PRICE_WAIT_KEY_ATTRIBUTE, nil)
        end

        if not Button.Parent or Button:GetAttribute(PROMPT_DISABLED_ATTRIBUTE) then
            return
        end

        local CachedPriceText = ProductPriceCache[CacheKey]

        if CachedPriceText then
            Set_Button_Price_Text(Button, CachedPriceText)
        end
    end)
end

local function Bind_Button_Price(Button: GuiButton)
    if Button:GetAttribute(PRICE_BOUND_ATTRIBUTE) then
        Update_Button_Price(Button)
        return
    end

    Button:SetAttribute(PRICE_BOUND_ATTRIBUTE, true)
    Update_Button_Price(Button)

    Button.DescendantAdded:Connect(function(Descendant)
        if Descendant:IsA("TextLabel") then
            Update_Button_Price(Button)
        end
    end)
end

local function Set_Button_Purchase_Attributes(Button: GuiButton, Product: RobuxProducts.PurchaseConfig)
    Button:SetAttribute(PRODUCT_KEY_ATTRIBUTE, Product.Key)

    if Product.Kind == "Product" and Product.ProductId then
        Button:SetAttribute(DEVELOPER_PRODUCT_ATTRIBUTE, Product.ProductId)
        Button:SetAttribute(PRODUCT_PRICE_ATTRIBUTE, Product.ProductId)
        Button:SetAttribute(GAMEPASS_ATTRIBUTE, nil)
        Button:SetAttribute(GAMEPASS_ATTRIBUTE_ALTERNATE, nil)
    elseif Product.Kind == "GamePass" and Product.GamePassId then
        Button:SetAttribute(DEVELOPER_PRODUCT_ATTRIBUTE, nil)
        Button:SetAttribute(PRODUCT_PRICE_ATTRIBUTE, nil)
        Button:SetAttribute(GAMEPASS_ATTRIBUTE, Product.GamePassId)
        Button:SetAttribute(GAMEPASS_ATTRIBUTE_ALTERNATE, Product.GamePassId)
    end
end

local function Prompt_Product(Button: GuiButton)
    if Button:GetAttribute(PROMPT_DISABLED_ATTRIBUTE) then
        return
    end

    if IsUiBlocked and IsUiBlocked() then
        return
    end

    local PurchaseInfo = Get_Prompt_Purchase_Info(Button)

    if not PurchaseInfo then
        return
    end

    if PurchaseInfo.InfoType == Enum.InfoType.GamePass then
        MarketplaceService:PromptGamePassPurchase(LocalPlayer, PurchaseInfo.Id)
    else
        MarketplaceService:PromptProductPurchase(LocalPlayer, PurchaseInfo.Id)
    end
end

local function Bind_Purchase_Button(Button: GuiButton, Product: RobuxProducts.PurchaseConfig)
    Set_Button_Purchase_Attributes(Button, Product)

    if Product.PriceRobux then
        Set_Button_Price_Text(Button, tostring(Product.PriceRobux))
    end

    Bind_Button_Price(Button)

    if BindButtonMotion then
        BindButtonMotion(Button)
    end

    if Button:GetAttribute(BOUND_ATTRIBUTE) then
        return
    end

    Button:SetAttribute(BOUND_ATTRIBUTE, true)
    Button.Activated:Connect(function()
        Prompt_Product(Button)
    end)
end

local function Get_Shop_Content(): Instance?
    local Frames = Get_Frames()
    local Shop = Frames and Frames:FindFirstChild("Shop")

    return Shop and (Shop:FindFirstChild("content") or Shop:FindFirstChild("Content")) or nil
end

local function Bind_Icon_Hover(Icon: GuiObject?)
    if not Icon or Icon:GetAttribute(ICON_HOVER_BOUND_ATTRIBUTE) then
        return
    end

    Icon:SetAttribute(ICON_HOVER_BOUND_ATTRIBUTE, true)
    Icon.Active = true

    local Scale = Get_Or_Create_Scale(Icon, "RobuxShopIconHoverScale")

    Icon.MouseEnter:Connect(function()
        Play_Ui_Sound("Hover")
        Tween(Scale, ICON_TWEEN_INFO, {
            Scale = ICON_HOVER_SCALE,
        })
    end)

    Icon.MouseLeave:Connect(function()
        Tween(Scale, ICON_TWEEN_INFO, {
            Scale = 1,
        })
    end)
end

local function Is_Gui_Visible_In_Hierarchy(Object: GuiObject): boolean
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

    return true
end

local function Get_Icon_Float_Seed(Icon: GuiObject, FloatIndex: number): number
    local Seed = FloatIndex
    local Name = Icon.Name

    for Index = 1, #Name do
        Seed += string.byte(Name, Index) or 0
    end

    return Seed
end

local function Update_Icon_Floats()
    local HasActiveFloat = false
    local Now = os.clock()

    for Icon, State in IconFloatStates do
        if not Icon.Parent then
            IconFloatStates[Icon] = nil
            continue
        end

        if State.Active then
            HasActiveFloat = true
        end

        if State.Active and Is_Gui_Visible_In_Hierarchy(Icon) then
            local Alpha = (math.sin(((Now + State.Phase) / State.Duration) * math.pi * 2) + 1) * 0.5
            local OffsetY = State.OffsetY * Alpha
            local BasePosition = State.BasePosition

            Icon.Position = UDim2.new(
                BasePosition.X.Scale,
                BasePosition.X.Offset,
                BasePosition.Y.Scale,
                BasePosition.Y.Offset + OffsetY
            )
        elseif Icon.Position ~= State.BasePosition then
            Icon.Position = State.BasePosition
        end
    end

    if not HasActiveFloat and IconFloatRenderConnection then
        IconFloatRenderConnection:Disconnect()
        IconFloatRenderConnection = nil
    end
end

local function Ensure_Icon_Float_Render()
    if IconFloatRenderConnection then
        return
    end

    IconFloatRenderConnection = RunService.RenderStepped:Connect(Update_Icon_Floats)
end

local function Bind_Icon_Float(Icon: GuiObject?, FloatIndex: number)
    if not Icon then
        return
    end

    if not IconFloatStates[Icon] then
        local Seed = Get_Icon_Float_Seed(Icon, FloatIndex)

        IconFloatStates[Icon] = {
            BasePosition = Icon.Position,
            Active = false,
            Duration = ICON_FLOAT_DURATION_BASE + (Seed % 6) * ICON_FLOAT_DURATION_STEP,
            Phase = (Seed % 11) * ICON_FLOAT_PHASE_STEP,
            OffsetY = ICON_FLOAT_OFFSET_Y - (Seed % 2),
        }
    end

    if Icon:GetAttribute(ICON_FLOAT_BOUND_ATTRIBUTE) then
        return
    end

    Icon:SetAttribute(ICON_FLOAT_BOUND_ATTRIBUTE, true)

    Icon.Destroying:Connect(function()
        IconFloatStates[Icon] = nil
    end)
end

local function Stop_Icon_Float(Icon: GuiObject, State: IconFloatState)
    State.Active = false

    if Icon.Parent then
        Icon.Position = State.BasePosition
    end
end

local function Start_Icon_Float(Icon: GuiObject, State: IconFloatState)
    if State.Active then
        return
    end

    State.Active = true

    Icon.Position = State.BasePosition
    Ensure_Icon_Float_Render()
end

local function Set_Icon_Float_Active(Icon: GuiObject, ShouldAnimate: boolean)
    local State = IconFloatStates[Icon]

    if not State then
        return
    end

    if ShouldAnimate then
        Start_Icon_Float(Icon, State)
        return
    end

    if State.Active then
        Stop_Icon_Float(Icon, State)
    elseif Icon.Parent and Icon.Position ~= State.BasePosition then
        Icon.Position = State.BasePosition
    end
end

local function Is_Shop_Icon(Object: Instance): boolean
    if not Object:IsA("ImageLabel") and not Object:IsA("ImageButton") then
        return false
    end

    if Object:IsA("GuiButton") then
        return false
    end

    if Object:GetAttribute(PRODUCT_KEY_ATTRIBUTE) then
        return false
    end

    if Object:FindFirstChildWhichIsA("GuiObject") then
        return false
    end

    local Name = Normalize_Name(Object.Name)

    if Name:find("background") or Name:find("button") or Name == "price" then
        return false
    end

    local Current = Object.Parent

    while Current do
        if Current:IsA("GuiButton") or Normalize_Name(Current.Name) == "price" then
            return false
        end

        Current = Current.Parent
    end

    return Name:find("icon") ~= nil
        or Name:find("slime") ~= nil
        or Name:find("dumpling") ~= nil
        or Name:find("lasso") ~= nil
        or Name:find("monke") ~= nil
        or Name:find("fox") ~= nil
        or Name:find("catus") ~= nil
        or Name:find("cactus") ~= nil
        or Name:find("shark") ~= nil
        or Name:find("franken") ~= nil
        or Name:find("white") ~= nil
end

local function Bind_Card_Icon_Hovers(
    Card: Instance?,
    EnableFloat: boolean?,
    ShouldAnimateFloat: boolean?,
    FloatIndex: number?
): number
    local NextFloatIndex = FloatIndex or 0

    if not Card then
        return NextFloatIndex
    end

    for _, Descendant in Card:GetDescendants() do
        if Is_Shop_Icon(Descendant) and Descendant:IsA("GuiObject") then
            Bind_Icon_Hover(Descendant)

            if EnableFloat then
                NextFloatIndex += 1
                Bind_Icon_Float(Descendant, NextFloatIndex)
                Set_Icon_Float_Active(
                    Descendant,
                    ShouldAnimateFloat == true and Is_Gui_Visible_In_Hierarchy(Descendant)
                )
            end
        end
    end

    return NextFloatIndex
end

local function Bind_Rainbow_Effect(GuiObjectToBind: GuiObject?)
    if not GuiObjectToBind or GuiObjectToBind:GetAttribute(RAINBOW_BOUND_ATTRIBUTE) then
        return
    end

    GuiObjectToBind:SetAttribute(RAINBOW_BOUND_ATTRIBUTE, true)

    local Success, Effect = pcall(function()
        return EzVisualz.new(GuiObjectToBind, "Rainbow", RAINBOW_EFFECT_SPEED)
    end)

    if Success and Effect then
        RainbowEffects[GuiObjectToBind] = Effect
        return
    end

    GuiObjectToBind:SetAttribute(RAINBOW_BOUND_ATTRIBUTE, nil)
end

local function Bind_Main_Shop_Icon_Effects()
    local ShopContent = Get_Shop_Content()

    if not ShopContent then
        return
    end

    local VoidLasso = ShopContent:FindFirstChild("Void Lasso")
    local LimitedLabel = VoidLasso and VoidLasso:FindFirstChild("LIMITED")

    if LimitedLabel and LimitedLabel:IsA("TextLabel") then
        Bind_Rainbow_Effect(LimitedLabel)
    end

    local ShopFrame = ShopContent.Parent
    local ShouldAnimateFloat = ShopFrame and ShopFrame:IsA("GuiObject") and Is_Gui_Visible_In_Hierarchy(ShopFrame)
    local FloatIndex = 0

    for _, CardName in { "Golden Lucky Block", "Starter Pack", "Void Lasso", "Lucky Pro Pack", "Cash" } do
        FloatIndex = Bind_Card_Icon_Hovers(ShopContent:FindFirstChild(CardName), true, ShouldAnimateFloat, FloatIndex)
    end
end

local function Find_Hud_Offer(OfferName: string): GuiObject?
    local Hud = Get_Hud()

    if not Hud then
        return nil
    end

    if OfferName == "StarterPack" then
        local RightButtons = Hud:FindFirstChild("RightButtons")
        local StarterPack = RightButtons and RightButtons:FindFirstChild("StarterPack")

        if StarterPack and StarterPack:IsA("GuiObject") then
            return StarterPack
        end
    end

    local Offer = Hud:FindFirstChild(OfferName) or Hud:FindFirstChild(OfferName, true)

    return if Offer and Offer:IsA("GuiObject") then Offer else nil
end

local function Is_Hud_Offer_Available(Offer: GuiObject): boolean
    return Offer:GetAttribute(HUD_OFFER_AVAILABLE_ATTRIBUTE) ~= false
end

local function Bind_Hud_Offer(OfferName: string, ProductKey: string): GuiObject?
    local Offer = Find_Hud_Offer(OfferName)
    local Product = RobuxProducts.Get(ProductKey)

    if not Offer or not Product then
        return Offer
    end

    if Offer:IsA("GuiButton") then
        Bind_Purchase_Button(Offer, Product)
    end

    Bind_Card_Icon_Hovers(Offer, false)
    return Offer
end

local function Get_Hud_Offers(): { GuiObject }
    local Offers = {}

    local StarterPack = Bind_Hud_Offer("StarterPack", "StarterPack")

    if StarterPack then
        StarterPack:SetAttribute(HUD_OFFER_AVAILABLE_ATTRIBUTE, true)
        StarterPack.Visible = true
    end

    for _, Offer in
        {
            Bind_Hud_Offer("ProPack", "ProPack"),
            Bind_Hud_Offer("TimeSkip", "SkipTime5m"),
        }
    do
        if Offer and Is_Hud_Offer_Available(Offer) then
            table.insert(Offers, Offer)
        elseif Offer then
            Offer.Visible = false
        end
    end

    return Offers
end

local function Update_Hud_Offer_Rotation()
    local Offers = Get_Hud_Offers()

    if #Offers == 0 then
        return
    end

    if CurrentHudOfferIndex > #Offers then
        CurrentHudOfferIndex = 1
    end

    if #Offers > 1 and os.clock() - LastHudOfferRotationAt >= HUD_OFFER_ROTATION_INTERVAL then
        CurrentHudOfferIndex = (CurrentHudOfferIndex % #Offers) + 1
        LastHudOfferRotationAt = os.clock()
    end

    for Index, Offer in Offers do
        Offer.Visible = Index == CurrentHudOfferIndex
    end
end

local function Bind_Main_Shop_Buttons()
    local Content = Get_Shop_Content()

    if not Content then
        return
    end

    for _, ButtonConfig in RobuxProducts.ShopButtons do
        local Product = RobuxProducts.Get(ButtonConfig.Key)
        local Card = Product and Find_By_Path(Content, ButtonConfig.Path)
        local Button = Card and Card:FindFirstChild("Buy Button")

        if Product and Button and Button:IsA("GuiButton") then
            Bind_Purchase_Button(Button, Product)
        end
    end
end

local function Bind_Lasso_Shop_Buttons()
    local Frames = Get_Frames()
    local LassoShop = Frames and Frames:FindFirstChild("LassoShop")
    local Content = LassoShop and (LassoShop:FindFirstChild("Content") or LassoShop:FindFirstChild("content"))

    if not Content then
        return
    end

    for _, ButtonConfig in RobuxProducts.LassoShopButtons do
        local Product = RobuxProducts.Get(ButtonConfig.Key)
        local Card = Product and Find_By_Path(Content, ButtonConfig.Path)
        local Button = Card and Card:FindFirstChild("Robux Button")

        if Product and Button and Button:IsA("GuiButton") then
            Bind_Purchase_Button(Button, Product)
        end
    end
end

local function Bind_Food_Shop_Buttons()
    local Frames = Get_Frames()
    local FoodShop = Frames and Frames:FindFirstChild("FoodShop")
    local Content = FoodShop and (FoodShop:FindFirstChild("content") or FoodShop:FindFirstChild("Content"))

    if not Content then
        return
    end

    for _, ButtonConfig in RobuxProducts.FoodShopButtons do
        local Product = RobuxProducts.Get(ButtonConfig.Key)
        local Card = Product and Find_By_Path(Content, ButtonConfig.Path)
        local Button = Card and Card:FindFirstChild("Robux Button")

        if Product and Button and Button:IsA("GuiButton") then
            Bind_Purchase_Button(Button, Product)
        end
    end
end

local function Get_Card_Title(Card: Instance): TextLabel?
    local Title = Card:FindFirstChild("Title", true)

    return if Title and Title:IsA("TextLabel") then Title else nil
end

local function Get_Plot_Sign_Product_Key(Card: Instance): string?
    local Title = Get_Card_Title(Card)
    local Text = if Title then Title.Text else Card.Name

    if string.find(Text, "x1 Lucky Block", 1, true) then
        return "LuckyBlock1"
    end

    if string.find(Text, "x3 Lucky Block", 1, true) then
        return "LuckyBlock3"
    end

    if string.find(Text, "Skip 5m", 1, true) then
        return "SkipTime5m"
    end

    if string.find(Text, "Skip 10m", 1, true) then
        return "SkipTime10m"
    end

    return nil
end

local function Bind_Plot_Sign_Card(Card: Instance)
    local ProductKey = Get_Plot_Sign_Product_Key(Card)
    local Product = ProductKey and RobuxProducts.Get(ProductKey)
    local Button = Card:FindFirstChild("Buy Button")

    if not Product or not Button or not Button:IsA("GuiButton") then
        return
    end

    Bind_Purchase_Button(Button, Product)
    Bind_Card_Icon_Hovers(Card)
end

local function Bind_Plot_Sign(Sign: Instance?)
    local SurfaceGui = Sign and Sign:FindFirstChildWhichIsA("SurfaceGui", true)

    if not SurfaceGui then
        return
    end

    for _, Card in SurfaceGui:GetChildren() do
        if Card:IsA("GuiObject") then
            Bind_Plot_Sign_Card(Card)
        end
    end
end

local function Bind_Plot_Sign_Buttons()
    local Now = os.clock()

    if Now - LastPlotSignBindAt < PLOT_SIGN_BIND_INTERVAL then
        return
    end

    LastPlotSignBindAt = Now

    local Plots = Workspace:FindFirstChild("Plots")

    if not Plots then
        return
    end

    for _, Plot in Plots:GetChildren() do
        Bind_Plot_Sign(Plot:FindFirstChild("LuckyBlockSign"))
        Bind_Plot_Sign(Plot:FindFirstChild("SkipTimeSign"))
    end
end

local function Is_Timer_Text(Text: string): boolean
    return Text:match("^%d+:%d%d$") ~= nil or Text:match("^%d+:%d%d:%d%d$") ~= nil
end

local function Text_Uses_Hours(Text: string): boolean
    return Text:match("^%d+:%d%d:%d%d$") ~= nil
end

local function Format_Timer(Seconds: number, UseHours: boolean): string
    local Remaining = math.max(0, math.floor(Seconds))
    local Hours = math.floor(Remaining / 3600)
    local Minutes = math.floor((Remaining % 3600) / 60)
    local SecondsLeft = Remaining % 60

    if UseHours then
        return string.format("%02d:%02d:%02d", Hours, Minutes, SecondsLeft)
    end

    return string.format("%02d:%02d", Minutes, SecondsLeft)
end

local function Add_Timer_Labels(Card: Instance?, Labels: { TextLabel })
    if not Card then
        return
    end

    for _, Descendant in Card:GetDescendants() do
        if Descendant:IsA("TextLabel") and (Descendant.Name == "Timer" or Is_Timer_Text(Descendant.Text)) then
            table.insert(Labels, Descendant)
        end
    end
end

local function Update_Starter_Pack_Timer(Content: Instance, Remaining: number)
    local Card = Content:FindFirstChild("Starter Pack")
    local HudStarterPack = Find_Hud_Offer("StarterPack")
    local Labels = {}

    Add_Timer_Labels(Card, Labels)
    Add_Timer_Labels(HudStarterPack, Labels)

    for _, Label in Labels do
        local PreviousText = LastTimerTextByLabel[Label] or Label.Text
        local TimerText = Format_Timer(Remaining, Text_Uses_Hours(PreviousText))

        if Label.Text ~= TimerText then
            Label.Text = TimerText
        end

        LastTimerTextByLabel[Label] = TimerText
    end
end

local function Update_Lucky_Block_Timer(Content: Instance, Remaining: number)
    local Card = Content:FindFirstChild("Golden Lucky Block")
    local Labels = {}
    local TimerText = Format_Timer(Remaining, true)

    Add_Timer_Labels(Card, Labels)

    for _, Label in Labels do
        if Label.Text ~= TimerText then
            Label.Text = TimerText
        end

        LastTimerTextByLabel[Label] = TimerText
    end
end

local function Get_Looping_Timer_Remaining(Elapsed: number, Duration: number): number
    Duration = math.max(1, math.floor(Duration))

    local Remainder = Elapsed % Duration

    return if Remainder == 0 then Duration else Duration - Remainder
end

local function Update_Timers()
    local Now = os.clock()

    if Now - LastTimerUpdate < TIMER_UPDATE_INTERVAL then
        return
    end

    LastTimerUpdate = Now

    local Content = Get_Shop_Content()

    if not Content then
        return
    end

    local Elapsed = math.floor(Now - TimerStartedAt)

    Update_Starter_Pack_Timer(Content, Get_Looping_Timer_Remaining(Elapsed, STARTER_PACK_TIMER_SECONDS))
    Update_Lucky_Block_Timer(Content, Get_Looping_Timer_Remaining(Elapsed, LUCKY_BLOCK_TIMER_SECONDS))
end

local function Bind_All()
    Bind_Main_Shop_Buttons()
    Bind_Lasso_Shop_Buttons()
    Bind_Food_Shop_Buttons()
    Bind_Main_Shop_Icon_Effects()
    Bind_Plot_Sign_Buttons()
    Update_Hud_Offer_Rotation()
    Update_Timers()
end

local RobuxShopUI = {}

function RobuxShopUI.Initialize(Gui: ScreenGui, ButtonMotion: (GuiButton) -> (), UiBlocked: () -> boolean)
    MainGui = Gui
    BindButtonMotion = ButtonMotion
    IsUiBlocked = UiBlocked
    TimerStartedAt = os.clock()
    LastTimerUpdate = 0
    CurrentHudOfferIndex = 1
    LastHudOfferRotationAt = os.clock()

    Bind_All()
end

function RobuxShopUI.Step()
    Bind_All()
end

return table.freeze(RobuxShopUI)
