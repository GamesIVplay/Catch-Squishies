local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local EzVisualz = require(ReplicatedStorage.Packages.EzVisualz)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Network = require(ReplicatedFirst.Network)
local TopbarPlus = require(ReplicatedStorage.Packages.TopbarPlus)
local peek = Fusion.peek

local DailyRewardsUI = require(script.Parent.Parent.Modules.DailyRewardsUI)
local FoodShopUI = require(script.Parent.Parent.Modules.FoodShopUI)
local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local GiftingUI = require(script.Parent.Parent.Modules.GiftingUI)
local HudPlaceButton = require(script.Parent.Parent.Modules.HudPlaceButton)
local InventoryUI = require(script.Parent.Parent.Modules.InventoryUI)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local LocalNotifications = require(script.Parent.Parent.Modules.LocalNotifications)
local OfflineRewardsUI = require(script.Parent.Parent.Modules.OfflineRewardsUI)
local Phases = require(ReplicatedStorage.Shared.Phases)
local PlaytimeRewardsUI = require(script.Parent.Parent.Modules.PlaytimeRewardsUI)
local RobuxShopUI = require(script.Parent.Parent.Modules.RobuxShopUI)
local SellDialogUI = require(script.Parent.Parent.Modules.SellDialogUI)
local ShopExclamationUI = require(script.Parent.Parent.Modules.ShopExclamationUI)
local TutorialAutoEquip = require(script.Parent.Parent.Modules.TutorialAutoEquip)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local UiImageEffects = require(script.Parent.Parent.Modules.UiImageEffects)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local LocalPlayer = Players.LocalPlayer
local CUSTOM_SLOT_MIN = 3
local CUSTOM_SLOT_MAX = 7

local function Create_Inventory_Slot_Configs()
    return {
        {
            ButtonName = "Lasso",
            DisplayNumber = 1,
            KeyCodes = { Enum.KeyCode.One, Enum.KeyCode.KeypadOne },
        },
        {
            ButtonName = "Hammer",
            DisplayNumber = 2,
            KeyCodes = { Enum.KeyCode.Two, Enum.KeyCode.KeypadTwo },
        },
        {
            ButtonName = "3",
            DisplayNumber = 3,
            KeyCodes = { Enum.KeyCode.Three, Enum.KeyCode.KeypadThree },
        },
        {
            ButtonName = "4",
            DisplayNumber = 4,
            KeyCodes = { Enum.KeyCode.Four, Enum.KeyCode.KeypadFour },
        },
        {
            ButtonName = "5",
            DisplayNumber = 5,
            KeyCodes = { Enum.KeyCode.Five, Enum.KeyCode.KeypadFive },
        },
        {
            ButtonName = "6",
            DisplayNumber = 6,
            KeyCodes = { Enum.KeyCode.Six, Enum.KeyCode.KeypadSix },
        },
        {
            ButtonName = "7",
            DisplayNumber = 7,
            KeyCodes = { Enum.KeyCode.Seven, Enum.KeyCode.KeypadSeven },
        },
    }
end

local Constants = {
    ButtonTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    FrameTweenInfo = TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    FrameCloseTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
    HudTweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    InventoryShowTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    InventoryHideTweenInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
    RainbowEffectSpeed = 0.3,
    HoverScale = 1.08,
    PressScale = 0.92,
    PlotButtonUpOffset = -0.28,
    InventoryElementHiddenYOffset = 1,
    InventoryFrameHiddenPadding = 0.08,
    InventoryPopupHiddenScale = 0.86,
    DoubleMoneyHiddenRightPadding = 0.05,
    DailyRewardsTopbarImage = "rbxassetid://101611660760021",
    MusicTopbarMutedImage = "rbxassetid://134056990643242",
    MusicTopbarUnmutedImage = "rbxassetid://99028625406197",
    MusicSoundGroupName = "Music",
    CatchMinigameActiveAttribute = "CatchMinigameActive",
    CatchLassoBusyAttribute = "CatchLassoBusy",
    UiBlocksLassoThrowAttribute = "UiBlocksLassoThrow",
    InventorySuppressSlotActivatedAttribute = "InventorySuppressNextActivated",
    RobuxShopPromptDisabledAttribute = "RobuxShopPromptDisabled",
    LassoShopRobuxEquipBoundAttribute = "LassoShopRobuxEquipBound",
    LassoShopRobuxStateLabelName = "LassoShopRobuxStateLabel",
    InventoryEquippedImage = "rbxassetid://93835669739593",
    InventoryUnequippedImage = "rbxassetid://129986152318539",
    NotificationsRaisedYScale = 0.75,
    NotificationsDefaultYScale = 0.85,
    FrameNames = {
        FoodShop = true,
        Gifting = true,
        Shop = true,
        Index = true,
        LassoShop = true,
        DailyRewards = true,
        OfflineReward = true,
        PlaytimeRewards = true,
    },
    InventoryPopupElementNames = {
        "Tabs",
        "Search Bar",
        "Favorite",
        "Equip Best Pet",
        "Sort Tabs",
        "Items",
    },
    InventoryCompactElementNames = {
        "Backpack Button",
        "Item Buttons",
    },
    InventorySlotConfigs = Create_Inventory_Slot_Configs(),
    PlotShopPromptConfigs = {
        FoodShop = {
            FrameName = "FoodShop",
            ActionText = "Open Food",
        },
        LassoShop = {
            FrameName = "LassoShop",
            ActionText = "Open Lassos",
        },
        SellShop = {
            ActionText = "Sell Squishies",
            UseSellDialog = true,
        },
    },
    PlotSignModelNames = {
        LuckyBlockSign = true,
        SkipTimeSign = true,
    },
    PlotInteractionBindRetryInterval = 0.5,
    ShopPromptName = "OpenShopPrompt",
    ShopPromptBoundAttribute = "ShopPromptBound",
    ShopPromptTriggeredBoundAttribute = "ShopPromptTriggeredBound",
}

local Initialized = false
local Initializing = false
local MainGui: ScreenGui? = nil
local ActiveFrame: GuiObject? = nil
local FrameTokens: { [GuiObject]: any } = {}
local HudOriginalPositions: { [GuiObject]: UDim2 } = {}
local HudHiddenPositions: { [GuiObject]: UDim2 } = {}
local BoundPlot: Instance? = nil
local LastPlotInteractionBindAttempt = 0
local CashLabel: TextLabel? = nil
local FriendBoostLabel: TextLabel? = nil
local LassoStrengthLabel: TextLabel? = nil
local ClickToPickupLabel: TextLabel? = nil
local DoubleMoneyButton: GuiObject? = nil
local DoubleMoneyOriginalPosition: UDim2? = nil
local LastCashText: string? = nil
local LastFriendBoostText: string? = nil
local HudHintStates: { [TextLabel]: any } = {}
local RainbowEffects: { [GuiObject]: any } = {}
local DailyRewardsTopbarIcon: any = nil
local DailyRewardsOpenedOnJoin = false
local MusicTopbarIcon: any = nil
local MusicUnmutedVolume: number? = nil
local LastAffordableLassoName: string? = nil
local InventoryExpanded = false
local InventoryHiddenForFrame = false
local InventoryOriginalPosition: UDim2? = nil
local InventoryFrameToken: any = nil
local InventoryElementOriginalPositions: { [GuiObject]: UDim2 } = {}
local InventoryElementTokens: { [GuiObject]: any } = {}
local InventorySlotButtons: { [string]: ImageButton } = {}
local EquippedInventorySlot: string? = nil
local LastReplicatedEquippedInventorySlot: string? = nil
local InventoryInputBound = false
local MoneyMultiplierUi = {
    LastStateKey = "",
    PriceCache = {},
    PriceWaiters = {},
}
local Close_Active_Frame: () -> () = function() end
local Close_Active_Frame_Immediately: () -> () = function() end

local function Is_Tutorial_Active(): (boolean, number)
    if peek(FusionValues.TutorialStepReceived) ~= true then
        return false, TutorialSteps.StartStep
    end

    local Step = TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep))

    return not TutorialSteps.Is_Complete(Step), Step
end

local function Can_Open_Tutorial_Shop(ShopModelName: string): boolean
    local Active, Step = Is_Tutorial_Active()

    if not Active then
        return true
    end

    if ShopModelName == "LassoShop" then
        return Step == TutorialSteps.BuyNextLasso
    end

    if ShopModelName == "FoodShop" then
        return Step == TutorialSteps.FeedStrong
    end

    if ShopModelName == "SellShop" then
        return Step == TutorialSteps.SellOld
    end

    return false
end

local function Show_Tutorial_Block()
    LocalNotifications.Push(TutorialSteps.BlockedMessage, "Error", 3)
end

local function Normalize_Name(Name: string): string
    local Result = string.gsub(Name, "%W", "")

    return string.lower(Result)
end

local function Is_Catch_Minigame_Active(): boolean
    if LocalPlayer:GetAttribute(Constants.CatchMinigameActiveAttribute) == true then
        return true
    end

    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local MinigameGui = PlayerGui and PlayerGui:FindFirstChild("Minigame")

    return MinigameGui ~= nil and MinigameGui:IsA("ScreenGui") and MinigameGui.Enabled
end

local function Is_Lasso_Busy(): boolean
    return LocalPlayer:GetAttribute(Constants.CatchLassoBusyAttribute) == true
end

local function Is_Ui_Activation_Blocked(): boolean
    return Is_Catch_Minigame_Active() or Is_Lasso_Busy()
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

local function Get_Music_Sound_Group(): SoundGroup?
    local MusicGroup = SoundService:FindFirstChild(Constants.MusicSoundGroupName)

    if MusicGroup and MusicGroup:IsA("SoundGroup") then
        return MusicGroup
    end

    return nil
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

local function Bind_Button_Motion(Button: GuiButton)
    if Button:GetAttribute("UiMotionBound") then
        return
    end

    Button:SetAttribute("UiMotionBound", true)
    Button.Active = true

    local Scale = Get_Or_Create_Scale(Button, "ButtonMotionScale")
    local Hovering = false

    Button.MouseEnter:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        Hovering = true
        Play_Ui_Sound("Hover")
        Tween(Scale, Constants.ButtonTweenInfo, { Scale = Constants.HoverScale })
    end)

    Button.MouseLeave:Connect(function()
        Hovering = false
        Tween(Scale, Constants.ButtonTweenInfo, { Scale = 1 })
    end)

    Button.MouseButton1Down:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        Play_Ui_Sound("Click")
        Tween(Scale, Constants.ButtonTweenInfo, { Scale = Constants.PressScale })
    end)

    Button.MouseButton1Up:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        Tween(Scale, Constants.ButtonTweenInfo, { Scale = if Hovering then Constants.HoverScale else 1 })
    end)
end

local function Offset_Position(Position: UDim2, XScale: number, YScale: number): UDim2
    return UDim2.new(Position.X.Scale + XScale, Position.X.Offset, Position.Y.Scale + YScale, Position.Y.Offset)
end

local function Get_Inventory_Frame(): GuiObject?
    if not MainGui then
        return nil
    end

    local Frames = MainGui:FindFirstChild("Frames")
    local Inventory = Frames and Frames:FindFirstChild("Inventory")

    if Inventory and Inventory:IsA("GuiObject") then
        return Inventory
    end

    return nil
end

local function Get_Inventory_Element(Inventory: GuiObject, ElementName: string): GuiObject?
    local Element = Inventory:FindFirstChild(ElementName)

    if Element and Element:IsA("GuiObject") then
        return Element
    end

    return nil
end

local function Is_Search_Bar_Button(Inventory: GuiObject, Button: GuiButton): boolean
    local SearchBar = Get_Inventory_Element(Inventory, "Search Bar")

    return SearchBar == Button
end

local function Get_Inventory_Slot_Name_For_Key(KeyCode: Enum.KeyCode): string?
    for _, Config in Constants.InventorySlotConfigs do
        for _, SlotKeyCode in Config.KeyCodes do
            if KeyCode == SlotKeyCode then
                return Config.ButtonName
            end
        end
    end

    return nil
end

local function Is_Inventory_Slot_Name_Known(ButtonName: string): boolean
    for _, Config in Constants.InventorySlotConfigs do
        if Config.ButtonName == ButtonName then
            return true
        end
    end

    return false
end

local function Is_Slot_Display_Label(TextObject: TextLabel | TextButton): boolean
    local Name = string.lower(TextObject.Name)

    return string.find(Name, "key", 1, true) ~= nil
        or string.find(Name, "number", 1, true) ~= nil
        or string.find(Name, "slot", 1, true) ~= nil
        or string.match(TextObject.Text, "^%s*%d+%s*$") ~= nil
end

local function Set_Inventory_Slot_Display_Number(Button: GuiObject, DisplayNumber: number?)
    if not DisplayNumber then
        return
    end

    local DisplayText = tostring(DisplayNumber)

    for _, Descendant in Button:GetDescendants() do
        if (Descendant:IsA("TextLabel") or Descendant:IsA("TextButton")) and Is_Slot_Display_Label(Descendant) then
            Descendant.Text = DisplayText
        end
    end
end

local function Set_Inventory_Slot_Button_Enabled(Button: GuiObject, IsEnabled: boolean)
    Button.Visible = IsEnabled
    Button.Active = IsEnabled
    Button.Selectable = IsEnabled
end

local function Is_Custom_Inventory_Slot(ButtonName: string): boolean
    local Slot = tonumber(ButtonName)

    return type(Slot) == "number" and Slot >= CUSTOM_SLOT_MIN and Slot <= CUSTOM_SLOT_MAX and math.floor(Slot) == Slot
end

local function Toggle_Custom_Inventory_Slot(ButtonName: string)
    InventoryUI.ToggleHotbarSlotName(ButtonName)
end

local function Get_Selected_Lasso_Data()
    local LassoName = peek(FusionValues.Lasso)

    if type(LassoName) ~= "string" then
        LassoName = Lassos.Default
    end

    return Lassos.Get(LassoName) or Lassos.Get(Lassos.Default)
end

local function Format_Cash_Amount(Cash: number): string
    return Util.Format_Number_With_Commas(math.max(0, math.floor(Cash)))
end

local function Is_Any_Frame_Visible(): boolean
    if ActiveFrame and ActiveFrame.Visible then
        return true
    end

    if not MainGui then
        return false
    end

    local Frames = MainGui:FindFirstChild("Frames")

    if not Frames then
        return false
    end

    for _, Child in Frames:GetChildren() do
        if Child:IsA("GuiObject") and Constants.FrameNames[Child.Name] and Child.Visible then
            return true
        end
    end

    return false
end

local function Is_Inventory_Popup_Visible(): boolean
    if InventoryExpanded then
        return true
    end

    local Inventory = Get_Inventory_Frame()

    if not Inventory then
        return false
    end

    for _, ElementName in Constants.InventoryPopupElementNames do
        local Element = Get_Inventory_Element(Inventory, ElementName)

        if Element and Element.Visible then
            return true
        end
    end

    return false
end

local function Update_Lasso_Throw_Ui_Block()
    LocalPlayer:SetAttribute(
        Constants.UiBlocksLassoThrowAttribute,
        Is_Any_Frame_Visible() or Is_Inventory_Popup_Visible()
    )
end

local function Should_Hide_Held_Item_Text(): boolean
    return Is_Catch_Minigame_Active() or Is_Any_Frame_Visible() or Is_Inventory_Popup_Visible()
end

local function Get_Notifications_Frame(): GuiObject?
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local NotificationsGui = PlayerGui and PlayerGui:FindFirstChild("Notifications")
    local NotificationsFrame = NotificationsGui and NotificationsGui:FindFirstChild("Notifications")

    if NotificationsFrame and NotificationsFrame:IsA("GuiObject") then
        return NotificationsFrame
    end

    return nil
end

local function Set_Notifications_Y(YScale: number)
    local NotificationsFrame = Get_Notifications_Frame()

    if not NotificationsFrame then
        return
    end

    local Position = NotificationsFrame.Position

    if math.abs(Position.Y.Scale - YScale) < 0.001 then
        return
    end

    NotificationsFrame.Position = UDim2.new(Position.X.Scale, Position.X.Offset, YScale, Position.Y.Offset)
end

local function Update_Notifications_Position_For_Held_Item_Text()
    if Is_Catch_Minigame_Active() then
        Set_Notifications_Y(Constants.NotificationsRaisedYScale)
        return
    end

    if HudPlaceButton.IsVisible() then
        Set_Notifications_Y(HudPlaceButton.GetNotificationYScale())
        return
    end

    local ShouldRaise = (LassoStrengthLabel ~= nil and LassoStrengthLabel.Visible)
        or (ClickToPickupLabel ~= nil and ClickToPickupLabel.Visible)

    Set_Notifications_Y(
        if ShouldRaise then Constants.NotificationsRaisedYScale else Constants.NotificationsDefaultYScale
    )
end

local function Update_Disclaimer_Visibility()
    if not MainGui then
        return
    end

    local EdgeLayer = MainGui:FindFirstChild("EdgeLayer")
    local Disclaimer = EdgeLayer and EdgeLayer:FindFirstChild("Disclaimer")

    if Disclaimer and Disclaimer:IsA("GuiObject") then
        Disclaimer.Visible = Is_Catch_Minigame_Active()
    end
end

local function Get_Hud_Hint_State(Label: TextLabel)
    local State = HudHintStates[Label]

    if State then
        return State
    end

    State = {
        TargetVisible = Label.Visible,
        Token = nil,
    }

    HudHintStates[Label] = State

    return State
end

local function Set_Hud_Hint_Visible(Label: TextLabel?, ShouldShow: boolean, Smooth: boolean?)
    if not Label or not Label.Parent then
        return
    end

    local State = Get_Hud_Hint_State(Label)
    local Scale = Get_Or_Create_Scale(Label, "HudHintScale")

    if State.TargetVisible == ShouldShow then
        if ShouldShow and not Label.Visible then
            Label.Visible = true
        elseif not ShouldShow and not Smooth and Label.Visible then
            Label.Visible = false
            Scale.Scale = 0.96
        end

        return
    end

    State.TargetVisible = ShouldShow

    local Token = {}
    State.Token = Token

    if not Smooth then
        Label.Visible = ShouldShow
        Scale.Scale = if ShouldShow then 1 else 0.96
        return
    end

    if ShouldShow then
        Label.Visible = true
        Scale.Scale = 0.96

        Tween(Scale, Constants.InventoryShowTweenInfo, { Scale = 1 })

        return
    end

    local HideTween = Tween(Scale, Constants.InventoryHideTweenInfo, { Scale = 0.96 })

    HideTween.Completed:Connect(function()
        if State.Token ~= Token then
            return
        end

        Label.Visible = false
    end)
end

local function Update_Lasso_Slot_Visuals()
    local Button = InventorySlotButtons.Lasso
    local LassoData = Get_Selected_Lasso_Data()

    if not Button or not Button.Parent or not LassoData then
        return
    end

    local Icon = Button:FindFirstChild("lassoicon", true)

    if Icon and (Icon:IsA("ImageLabel") or Icon:IsA("ImageButton")) then
        Icon.Image = LassoData.Image
    end
end

local function Update_Inventory_Slot_Images()
    local CurrentEquippedSlot = peek(FusionValues.EquippedInventorySlot)

    EquippedInventorySlot = if type(CurrentEquippedSlot) == "string" then CurrentEquippedSlot else nil

    if EquippedInventorySlot and not Is_Inventory_Slot_Name_Known(EquippedInventorySlot) then
        EquippedInventorySlot = nil
        FusionValues.EquippedInventorySlot:set(nil)
    end

    for _, Config in Constants.InventorySlotConfigs do
        local Button = InventorySlotButtons[Config.ButtonName]

        if Button and Button.Parent then
            Button.Image = if EquippedInventorySlot == Config.ButtonName
                then Constants.InventoryEquippedImage
                else Constants.InventoryUnequippedImage
        end
    end

    Update_Lasso_Slot_Visuals()
end

local function Replicate_Equipped_Inventory_Slot()
    local CurrentEquippedSlot = peek(FusionValues.EquippedInventorySlot)
    local SlotName = if type(CurrentEquippedSlot) == "string" then CurrentEquippedSlot else ""

    if SlotName == LastReplicatedEquippedInventorySlot then
        return
    end

    LastReplicatedEquippedInventorySlot = SlotName
    Network.EquippedInventorySlotChanged.Fire(SlotName)
end

local function Toggle_Inventory_Slot(ButtonName: string)
    if Is_Ui_Activation_Blocked() then
        return
    end

    if not Is_Inventory_Slot_Name_Known(ButtonName) then
        return
    end

    if Is_Custom_Inventory_Slot(ButtonName) then
        Toggle_Custom_Inventory_Slot(ButtonName)
        return
    end

    if not InventorySlotButtons[ButtonName] then
        return
    end

    InventoryUI.ClearInventorySelection()
    EquippedInventorySlot = if EquippedInventorySlot == ButtonName then nil else ButtonName
    FusionValues.EquippedInventorySlot:set(EquippedInventorySlot)
    Update_Inventory_Slot_Images()
end

local function Equip_Inventory_Slot(ButtonName: string)
    if not Is_Inventory_Slot_Name_Known(ButtonName) then
        return
    end

    if not InventorySlotButtons[ButtonName] then
        return
    end

    InventoryUI.ClearInventorySelection()

    EquippedInventorySlot = ButtonName
    FusionValues.EquippedInventorySlot:set(ButtonName)
    Update_Inventory_Slot_Images()
end

local function Bind_Inventory_Slot_Button(Button: ImageButton, ButtonName: string)
    InventorySlotButtons[ButtonName] = Button

    Set_Inventory_Slot_Button_Enabled(Button, true)

    if Button:GetAttribute("InventorySlotBound") then
        return
    end

    Button:SetAttribute("InventorySlotBound", true)

    if Is_Custom_Inventory_Slot(ButtonName) then
        return
    end

    Button.Activated:Connect(function()
        if Button:GetAttribute(Constants.InventorySuppressSlotActivatedAttribute) == true then
            Button:SetAttribute(Constants.InventorySuppressSlotActivatedAttribute, nil)
            return
        end

        if InventoryUI.ShouldSuppressSlotActivated() then
            return
        end

        Toggle_Inventory_Slot(ButtonName)
    end)
end

local function Bind_Inventory_Slots(Inventory: GuiObject)
    local ItemButtons = Get_Inventory_Element(Inventory, "Item Buttons")

    if not ItemButtons then
        return
    end

    for _, Config in Constants.InventorySlotConfigs do
        local Button = ItemButtons:FindFirstChild(Config.ButtonName)

        if Button and Button:IsA("ImageButton") then
            Set_Inventory_Slot_Display_Number(Button, Config.DisplayNumber)
            Bind_Inventory_Slot_Button(Button, Config.ButtonName)
        end
    end

    Update_Inventory_Slot_Images()
end

local function Cache_Inventory_Frame_Position(Inventory: GuiObject): UDim2
    if InventoryOriginalPosition then
        return InventoryOriginalPosition
    end

    InventoryOriginalPosition = Inventory.Position

    return Inventory.Position
end

local function Get_Inventory_Frame_Hidden_Position(Inventory: GuiObject): UDim2
    local OriginalPosition = Cache_Inventory_Frame_Position(Inventory)

    return Offset_Position(OriginalPosition, 0, Inventory.Size.Y.Scale + Constants.InventoryFrameHiddenPadding)
end

local function Set_Inventory_Frame_Visible(ShouldShow: boolean, Smooth: boolean?)
    local Inventory = Get_Inventory_Frame()

    if not Inventory then
        return
    end

    local OriginalPosition = Cache_Inventory_Frame_Position(Inventory)
    local HiddenPosition = Get_Inventory_Frame_Hidden_Position(Inventory)
    local Token = {}

    InventoryFrameToken = Token

    if ShouldShow then
        Inventory.Visible = true

        if Smooth then
            Tween(Inventory, Constants.HudTweenInfo, { Position = OriginalPosition })
        else
            Inventory.Position = OriginalPosition
        end

        return
    end

    if not Smooth then
        Inventory.Position = HiddenPosition
        Inventory.Visible = false
        return
    end

    local HideTween = Tween(Inventory, Constants.HudTweenInfo, { Position = HiddenPosition })

    HideTween.Completed:Connect(function()
        if InventoryFrameToken ~= Token then
            return
        end

        Inventory.Visible = false
    end)
end

local function Cache_Inventory_Element_Position(Element: GuiObject): UDim2
    local OriginalPosition = InventoryElementOriginalPositions[Element]

    if OriginalPosition then
        return OriginalPosition
    end

    InventoryElementOriginalPositions[Element] = Element.Position

    return Element.Position
end

local function Set_Inventory_Element_Visible(Element: GuiObject, ShouldShow: boolean, Smooth: boolean?, Mode: string?)
    local OriginalPosition = Cache_Inventory_Element_Position(Element)
    local HiddenPosition = Offset_Position(OriginalPosition, 0, Constants.InventoryElementHiddenYOffset)
    local ShouldPop = Mode == "Pop"
    local Scale = if ShouldPop then Get_Or_Create_Scale(Element, "ButtonMotionScale") else nil
    local Token = {}

    InventoryElementTokens[Element] = Token

    if ShouldShow then
        Element.Visible = true
        Element.Position = OriginalPosition

        if Smooth then
            if Scale then
                Scale.Scale = Constants.InventoryPopupHiddenScale
                Tween(Scale, Constants.InventoryShowTweenInfo, { Scale = 1 })
            else
                Element.Position = HiddenPosition
                Tween(Element, Constants.InventoryShowTweenInfo, { Position = OriginalPosition })
            end
        else
            if Scale then
                Scale.Scale = 1
            end
        end

        return
    end

    if not Element.Visible then
        if Scale then
            Scale.Scale = Constants.InventoryPopupHiddenScale
            Element.Position = OriginalPosition
        else
            Element.Position = HiddenPosition
        end
        return
    end

    if not Smooth then
        Element.Visible = false

        if Scale then
            Scale.Scale = Constants.InventoryPopupHiddenScale
            Element.Position = OriginalPosition
        else
            Element.Position = HiddenPosition
        end

        return
    end

    local HideTween

    if Scale then
        HideTween = Tween(Scale, Constants.InventoryHideTweenInfo, { Scale = Constants.InventoryPopupHiddenScale })
    else
        HideTween = Tween(Element, Constants.InventoryHideTweenInfo, { Position = HiddenPosition })
    end

    HideTween.Completed:Connect(function()
        if InventoryElementTokens[Element] ~= Token then
            return
        end

        Element.Visible = false

        if Scale then
            Element.Position = OriginalPosition
        end
    end)
end

local function Set_Inventory_Elements_Visible(
    ElementNames: { string },
    ShouldShow: boolean,
    Smooth: boolean?,
    Mode: string?
)
    local Inventory = Get_Inventory_Frame()

    if not Inventory then
        return
    end

    for _, ElementName in ElementNames do
        local Element = Get_Inventory_Element(Inventory, ElementName)

        if Element then
            Set_Inventory_Element_Visible(Element, ShouldShow, Smooth, Mode)
        end
    end
end

local function Cache_Double_Money_Position(): UDim2?
    if not DoubleMoneyButton or not DoubleMoneyButton.Parent then
        return nil
    end

    if DoubleMoneyOriginalPosition then
        return DoubleMoneyOriginalPosition
    end

    DoubleMoneyOriginalPosition = DoubleMoneyButton.Position

    return DoubleMoneyButton.Position
end

local function Get_Double_Money_Hidden_Position(): UDim2?
    if not DoubleMoneyButton then
        return nil
    end

    local OriginalPosition = Cache_Double_Money_Position()

    if not OriginalPosition then
        return nil
    end

    local HiddenXScale = 1
        + (DoubleMoneyButton.Size.X.Scale * DoubleMoneyButton.AnchorPoint.X)
        + Constants.DoubleMoneyHiddenRightPadding

    return UDim2.new(HiddenXScale, OriginalPosition.X.Offset, OriginalPosition.Y.Scale, OriginalPosition.Y.Offset)
end

local function Set_Double_Money_Button_Visible(ShouldShow: boolean, Smooth: boolean?)
    if not DoubleMoneyButton or not DoubleMoneyButton.Parent then
        return
    end

    local TutorialActive = Is_Tutorial_Active()

    if TutorialActive then
        DoubleMoneyButton.Visible = false
        return
    end

    local OriginalPosition = Cache_Double_Money_Position()
    local HiddenPosition = Get_Double_Money_Hidden_Position()

    if not OriginalPosition or not HiddenPosition then
        return
    end

    DoubleMoneyButton.Visible = true

    if Smooth then
        Tween(DoubleMoneyButton, Constants.HudTweenInfo, {
            Position = if ShouldShow then OriginalPosition else HiddenPosition,
        })
    else
        DoubleMoneyButton.Position = if ShouldShow then OriginalPosition else HiddenPosition
    end
end

local function Set_Inventory_Expanded(ShouldExpand: boolean, Smooth: boolean?)
    if InventoryHiddenForFrame then
        ShouldExpand = false
    end

    local WasExpanded = InventoryExpanded
    InventoryExpanded = ShouldExpand

    if ShouldExpand and not WasExpanded then
        InventoryUI.ClearTabSelection()
    end

    Set_Double_Money_Button_Visible(not ShouldExpand, Smooth)
    Set_Inventory_Elements_Visible(Constants.InventoryPopupElementNames, ShouldExpand, Smooth, "Pop")
    Update_Lasso_Throw_Ui_Block()
end

local function Set_Inventory_Compact_Visible(ShouldShow: boolean, Smooth: boolean?)
    Set_Inventory_Elements_Visible(Constants.InventoryCompactElementNames, ShouldShow, Smooth, "Slide")
end

local function Set_Inventory_Hidden_For_Frame(ShouldHide: boolean, Smooth: boolean?)
    InventoryHiddenForFrame = ShouldHide

    if ShouldHide then
        Set_Inventory_Expanded(false, false)
        Set_Inventory_Compact_Visible(true, false)
        Set_Inventory_Frame_Visible(false, Smooth)
        return
    end

    Set_Inventory_Compact_Visible(true, false)
    Set_Inventory_Frame_Visible(true, Smooth)
end

local function Toggle_Inventory_Expanded()
    if Is_Ui_Activation_Blocked() then
        return
    end

    if OfflineRewardsUI.Is_Blocking_Other_Frames() then
        return
    end

    SellDialogUI.Close()

    if ActiveFrame then
        Close_Active_Frame()
        Set_Inventory_Expanded(true, true)
        return
    end

    if InventoryHiddenForFrame then
        return
    end

    Set_Inventory_Expanded(not InventoryExpanded, true)
end

local function Bind_Inventory_Input()
    if InventoryInputBound then
        return
    end

    InventoryInputBound = true

    UserInputService.InputBegan:Connect(function(Input: InputObject, GameProcessedEvent: boolean)
        if GameProcessedEvent or UserInputService:GetFocusedTextBox() then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        if Input.KeyCode == Enum.KeyCode.Backquote then
            Toggle_Inventory_Expanded()
            return
        end

        if SellDialogUI.ShouldBlockInventoryInput() then
            return
        end

        local ButtonName = Get_Inventory_Slot_Name_For_Key(Input.KeyCode)

        if ButtonName then
            Toggle_Inventory_Slot(ButtonName)
        end
    end)
end

local function Bind_Inventory()
    local Inventory = Get_Inventory_Frame()

    if not Inventory then
        return
    end

    for _, Descendant in Inventory:GetDescendants() do
        if Descendant:IsA("GuiButton") and not Is_Search_Bar_Button(Inventory, Descendant) then
            Bind_Button_Motion(Descendant)
        end
    end

    local BackpackButton = Get_Inventory_Element(Inventory, "Backpack Button")

    if
        BackpackButton
        and BackpackButton:IsA("GuiButton")
        and not BackpackButton:GetAttribute("InventoryBackpackBound")
    then
        BackpackButton:SetAttribute("InventoryBackpackBound", true)
        BackpackButton.Activated:Connect(Toggle_Inventory_Expanded)
    end

    Bind_Inventory_Slots(Inventory)
    Bind_Inventory_Input()
    InventoryUI.Initialize(Inventory)

    for _, ElementName in Constants.InventoryPopupElementNames do
        local Element = Get_Inventory_Element(Inventory, ElementName)

        if Element then
            Cache_Inventory_Element_Position(Element)
            Set_Inventory_Element_Visible(Element, false, false, "Pop")
        end
    end

    for _, ElementName in Constants.InventoryCompactElementNames do
        local Element = Get_Inventory_Element(Inventory, ElementName)

        if Element then
            Cache_Inventory_Element_Position(Element)
        end
    end

    Set_Inventory_Expanded(false, false)
    Set_Inventory_Compact_Visible(not InventoryHiddenForFrame and not ActiveFrame, false)
    Set_Inventory_Frame_Visible(not InventoryHiddenForFrame and not ActiveFrame, false)
end

local function Cache_Hud_Tween_Target(GuiObject: GuiObject?, HiddenPosition: UDim2?)
    if not GuiObject or not HiddenPosition or HudOriginalPositions[GuiObject] then
        return
    end

    HudOriginalPositions[GuiObject] = GuiObject.Position
    HudHiddenPositions[GuiObject] = HiddenPosition
end

local function Cache_Hud_Tween_Targets()
    if not MainGui then
        return
    end

    local EdgeLayer = MainGui:FindFirstChild("EdgeLayer")
    local Hud = MainGui:FindFirstChild("Hud Frame")
    local Plot = EdgeLayer and EdgeLayer:FindFirstChild("Plot")
    local EventInfo = Hud and Hud:FindFirstChild("EventInfo")
    local PlotHiddenPosition = if Plot and Plot:IsA("GuiObject")
        then Offset_Position(Plot.Position, 0, Constants.PlotButtonUpOffset)
        else nil

    Cache_Hud_Tween_Target(if Plot and Plot:IsA("GuiObject") then Plot else nil, PlotHiddenPosition)

    if EventInfo and EventInfo:IsA("GuiObject") then
        Cache_Hud_Tween_Target(EventInfo, Offset_Position(EventInfo.Position, 0, Constants.PlotButtonUpOffset))
    end
end

local function Tween_Hud_Targets(IsFrameOpen: boolean)
    for GuiObject, OriginalPosition in HudOriginalPositions do
        if not GuiObject.Parent then
            continue
        end

        Tween(GuiObject, Constants.HudTweenInfo, {
            Position = if IsFrameOpen then HudHiddenPositions[GuiObject] else OriginalPosition,
        })
    end
end

local function Get_Frame_Scale(Frame: GuiObject): UIScale
    return Get_Or_Create_Scale(Frame, "FrameOpenScale")
end

local function Reset_Scrolling_Frames(Frame: GuiObject)
    for _, Descendant in Frame:GetDescendants() do
        if Descendant:IsA("ScrollingFrame") then
            Descendant.CanvasPosition = Vector2.new(0, 0)
        end
    end
end

local function Close_Frame(Frame: GuiObject)
    if not Frame.Visible then
        return
    end

    local Token = {}
    FrameTokens[Frame] = Token

    local Scale = Get_Frame_Scale(Frame)
    local CloseTween = Tween(Scale, Constants.FrameCloseTweenInfo, { Scale = 0.78 })

    CloseTween.Completed:Connect(function()
        if FrameTokens[Frame] ~= Token or ActiveFrame == Frame then
            return
        end

        Frame.Visible = false
    end)
end

local function Hide_Frame_Immediately(Frame: GuiObject)
    FrameTokens[Frame] = {}
    Frame.Visible = false

    local Scale = Frame:FindFirstChild("FrameOpenScale")

    if Scale and Scale:IsA("UIScale") then
        Scale.Scale = 0.78
    end
end

Close_Active_Frame = function()
    if not ActiveFrame then
        return
    end

    local FrameToClose = ActiveFrame
    ActiveFrame = nil

    Close_Frame(FrameToClose)
    Tween_Hud_Targets(false)
    Set_Inventory_Hidden_For_Frame(false, true)
    Update_Lasso_Throw_Ui_Block()
end

Close_Active_Frame_Immediately = function()
    if not ActiveFrame then
        return
    end

    local FrameToClose = ActiveFrame
    ActiveFrame = nil

    Hide_Frame_Immediately(FrameToClose)
    Tween_Hud_Targets(false)
    Set_Inventory_Hidden_For_Frame(false, false)
    Update_Lasso_Throw_Ui_Block()
end

local function Close_Other_Frames(ExceptFrame: GuiObject?)
    if not MainGui then
        return
    end

    local Frames = MainGui:FindFirstChild("Frames")

    if not Frames then
        return
    end

    for _, Child in Frames:GetChildren() do
        if Child:IsA("GuiObject") and Child ~= ExceptFrame and Constants.FrameNames[Child.Name] then
            Hide_Frame_Immediately(Child)
        end
    end
end

local function Get_Frame(FrameName: string): GuiObject?
    if not MainGui then
        return nil
    end

    local Frames = MainGui:FindFirstChild("Frames")
    local Frame = Frames and Frames:FindFirstChild(FrameName)

    if not Frame or not Frame:IsA("GuiObject") then
        return nil
    end

    return Frame
end

local function Open_Frame(FrameName: string, ForceOpen: boolean?)
    if Is_Ui_Activation_Blocked() then
        return
    end

    if FrameName ~= "OfflineReward" and OfflineRewardsUI.Is_Blocking_Other_Frames() then
        return
    end

    local Frame = Get_Frame(FrameName)

    if not Frame then
        return
    end

    if FrameName == "Shop" then
        ShopExclamationUI.MarkShopOpened()
    end

    if ActiveFrame == Frame and Frame.Visible then
        if ForceOpen then
            Reset_Scrolling_Frames(Frame)
            return
        end

        Close_Active_Frame()
        return
    end

    ActiveFrame = Frame
    Close_Other_Frames(Frame)
    Reset_Scrolling_Frames(Frame)
    Tween_Hud_Targets(true)
    Set_Inventory_Hidden_For_Frame(true, true)

    local Token = {}
    FrameTokens[Frame] = Token
    Frame.Visible = true

    local Scale = Get_Frame_Scale(Frame)
    Scale.Scale = 0.78

    Play_Ui_Sound(if FrameName == "Shop" then "ShopOpen" else "FrameOpen")
    Tween(Scale, Constants.FrameTweenInfo, { Scale = 1 })
    Update_Lasso_Throw_Ui_Block()
end

local function Open_Daily_Rewards_On_Join()
    if DailyRewardsOpenedOnJoin then
        return
    end

    if not peek(FusionValues.ProfileDataReceived) then
        return
    end

    if
        not peek(FusionValues.TutorialStepReceived) or not TutorialSteps.Is_Complete(peek(FusionValues.TutorialStep))
    then
        return
    end

    if not OfflineRewardsUI.Is_Ready_For_Daily_Rewards() then
        return
    end

    if not DailyRewardsUI.Has_Ready_Reward() then
        return
    end

    DailyRewardsOpenedOnJoin = true

    task.defer(function()
        Open_Frame("DailyRewards", true)
    end)
end

local function Open_Daily_Rewards_After_Offline()
    if DailyRewardsOpenedOnJoin then
        return
    end

    if not DailyRewardsUI.Has_Ready_Reward() then
        return
    end

    DailyRewardsOpenedOnJoin = true
    Open_Frame("DailyRewards", true)
end

local function Bind_Frame_Button(Button: Instance?, FrameName: string)
    if not Button or not Button:IsA("GuiButton") then
        return
    end

    Bind_Button_Motion(Button)

    if Button:GetAttribute("UiFrameOpenBound") then
        return
    end

    Button:SetAttribute("UiFrameOpenBound", true)

    Button.Activated:Connect(function()
        Open_Frame(FrameName)
    end)
end

local function Bind_Motion_Only_Button(Button: Instance?)
    if Button and Button:IsA("GuiButton") then
        Bind_Button_Motion(Button)
    end
end

local function Bind_Daily_Rewards_Topbar()
    if DailyRewardsTopbarIcon then
        return
    end

    DailyRewardsTopbarIcon = TopbarPlus.new()
        :setImage(Constants.DailyRewardsTopbarImage)
        :setImageScale(0.8)
        :align("Right")
        :setCaption("Daily Rewards")
        :setOrder(1)
        :oneClick(true)

    DailyRewardsTopbarIcon.viewingStarted:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        Play_Ui_Sound("Hover")
    end)

    DailyRewardsTopbarIcon.selected:Connect(function()
        if Is_Ui_Activation_Blocked() then
            return
        end

        Play_Ui_Sound("Click")
        Open_Frame("DailyRewards")
    end)
end

local function Bind_Music_Topbar()
    if MusicTopbarIcon then
        return
    end

    local MusicGroup = Get_Music_Sound_Group()
    MusicUnmutedVolume = if MusicGroup and MusicGroup.Volume > 0 then MusicGroup.Volume else 1

    MusicTopbarIcon = TopbarPlus.new()
        :setImage(Constants.MusicTopbarMutedImage, "Selected")
        :setImage(Constants.MusicTopbarUnmutedImage, "Deselected")
        :setImageScale(0.8)
        :align("Right")
        :setCaption("Toggle Music")
        :setOrder(2)
        :autoDeselect(false)

    MusicTopbarIcon.viewingStarted:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        Play_Ui_Sound("Hover")
    end)

    MusicTopbarIcon.toggled:Connect(function(IsMuted: boolean)
        if Is_Ui_Activation_Blocked() then
            return
        end

        Play_Ui_Sound("Click")

        local CurrentMusicGroup = Get_Music_Sound_Group()

        if not CurrentMusicGroup then
            return
        end

        if IsMuted then
            if CurrentMusicGroup.Volume > 0 then
                MusicUnmutedVolume = CurrentMusicGroup.Volume
            end

            CurrentMusicGroup.Volume = 0
        else
            CurrentMusicGroup.Volume = MusicUnmutedVolume or 1
        end
    end)
end

local function Bind_Rainbow_Effect(GuiObjectToBind: GuiObject?)
    if not GuiObjectToBind or GuiObjectToBind:GetAttribute("EzRainbowBound") then
        return
    end

    GuiObjectToBind:SetAttribute("EzRainbowBound", true)

    local Success, Effect = pcall(function()
        return EzVisualz.new(GuiObjectToBind, "Rainbow", Constants.RainbowEffectSpeed)
    end)

    if Success and Effect then
        RainbowEffects[GuiObjectToBind] = Effect
        return
    end

    GuiObjectToBind:SetAttribute("EzRainbowBound", nil)
    warn(`Failed to bind rainbow effect to {GuiObjectToBind:GetFullName()}: {tostring(Effect)}`)
end

local function Get_Local_Player_Plot(): Instance?
    local Plots = workspace:FindFirstChild("Plots")

    if not Plots then
        return nil
    end

    for _, Plot in Plots:GetChildren() do
        if Plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return Plot
        end
    end

    local ExpectedTitle = `{LocalPlayer.Name}'s Plot`

    for _, Plot in Plots:GetChildren() do
        local OwnerSign = Plot:FindFirstChild("OwnerSign")
        local Title = OwnerSign and OwnerSign:FindFirstChild("Title", true)

        if not Title or not Title:IsA("TextLabel") or Title.Text ~= ExpectedTitle then
            continue
        end

        return Plot
    end

    return nil
end

local function Get_Plot_Part(Plot: Instance, PartName: string): BasePart?
    local Part = Plot:FindFirstChild(PartName)

    if not Part then
        Part = Plot:FindFirstChild(PartName, true)
    end

    if Part and Part:IsA("BasePart") then
        return Part
    end

    return nil
end

local function Get_Local_Player_Plot_Spawn(): BasePart?
    local Plot = Get_Local_Player_Plot()

    if not Plot then
        return nil
    end

    return Get_Plot_Part(Plot, "Spawn")
end

local function Teleport_To_Plot()
    if Is_Ui_Activation_Blocked() then
        return
    end

    local Character = LocalPlayer.Character
    local Spawn = Get_Local_Player_Plot_Spawn()

    if not Character or not Spawn then
        return
    end

    Character:PivotTo(Spawn.CFrame + Vector3.yAxis * 3)
end

local function Bind_Plot_Button(Button: Instance?)
    if not Button or not Button:IsA("GuiButton") then
        return
    end

    Bind_Button_Motion(Button)

    if Button:GetAttribute("PlotTeleportBound") then
        return
    end

    Button:SetAttribute("PlotTeleportBound", true)
    Button.Activated:Connect(Teleport_To_Plot)
end

local function Find_Shop_Prompt_Attachment(ShopModel: Instance): Attachment?
    local Store = ShopModel:FindFirstChild("Store")

    if Store then
        local StorePart = Store:FindFirstChild("Part")
        local StorePartAttachment = StorePart and StorePart:FindFirstChildWhichIsA("Attachment", true)

        if StorePartAttachment then
            return StorePartAttachment
        end

        local StoreAttachment = Store:FindFirstChildWhichIsA("Attachment", true)

        if StoreAttachment then
            return StoreAttachment
        end
    end

    local DirectAttachment = ShopModel:FindFirstChild("Attachment")

    if DirectAttachment and DirectAttachment:IsA("Attachment") then
        return DirectAttachment
    end

    return nil
end

local function Remove_Misplaced_Shop_Prompts(ShopModel: Instance, Attachment: Attachment)
    for _, Descendant in ShopModel:GetDescendants() do
        if
            Descendant.Name == Constants.ShopPromptName
            and Descendant:IsA("ProximityPrompt")
            and Descendant.Parent ~= Attachment
        then
            Descendant:Destroy()
        end
    end
end

local function Bind_Shop_Prompt(ShopModel: Instance, FrameName: string?, ActionText: string, UseSellDialog: boolean?)
    local Attachment = Find_Shop_Prompt_Attachment(ShopModel)

    if not Attachment or Attachment:GetAttribute(Constants.ShopPromptBoundAttribute) then
        return
    end

    Attachment:SetAttribute(Constants.ShopPromptBoundAttribute, true)
    Remove_Misplaced_Shop_Prompts(ShopModel, Attachment)

    local Prompt = Attachment:FindFirstChild(Constants.ShopPromptName)

    if not Prompt or not Prompt:IsA("ProximityPrompt") then
        Prompt = Instance.new("ProximityPrompt")
        Prompt.Name = Constants.ShopPromptName
        Prompt.Parent = Attachment
    end

    Prompt.ActionText = ActionText
    Prompt.ObjectText = ""
    Prompt.HoldDuration = 0.25
    Prompt.MaxActivationDistance = 10
    Prompt.RequiresLineOfSight = false
    Prompt.Enabled = true

    if UseSellDialog and ShopModel:IsA("Model") then
        SellDialogUI.Bind(ShopModel, Prompt)
        return
    end

    if not FrameName then
        return
    end

    if Prompt:GetAttribute(Constants.ShopPromptTriggeredBoundAttribute) then
        return
    end

    Prompt:SetAttribute(Constants.ShopPromptTriggeredBoundAttribute, true)
    Prompt.Triggered:Connect(function(TargetPlayer: Player?)
        if TargetPlayer and TargetPlayer ~= LocalPlayer then
            return
        end

        if not Can_Open_Tutorial_Shop(ShopModel.Name) then
            Show_Tutorial_Block()
            return
        end

        Open_Frame(FrameName, true)
    end)
end

local function Bind_Plot_Sign_Button_Motion(Plot: Instance)
    for _, Descendant in Plot:GetDescendants() do
        if not Descendant:IsA("GuiButton") then
            continue
        end

        local Ancestor = Descendant.Parent
        local ShouldBind = false

        while Ancestor and Ancestor ~= Plot do
            if Constants.PlotSignModelNames[Ancestor.Name] then
                ShouldBind = true
                break
            end

            Ancestor = Ancestor.Parent
        end

        if ShouldBind then
            Bind_Button_Motion(Descendant)
        end
    end
end

local function Bind_Plot_Shop_Prompts(Plot: Instance)
    for ShopModelName, Config in Constants.PlotShopPromptConfigs do
        local ShopModel = Plot:FindFirstChild(ShopModelName)

        if ShopModel then
            Bind_Shop_Prompt(ShopModel, Config.FrameName, Config.ActionText, Config.UseSellDialog)
        end
    end
end

local function Bind_Local_Plot_Interactions()
    if BoundPlot and BoundPlot.Parent then
        return
    end

    local Now = os.clock()

    if Now - LastPlotInteractionBindAttempt < Constants.PlotInteractionBindRetryInterval then
        return
    end

    LastPlotInteractionBindAttempt = Now

    local Plot = Get_Local_Player_Plot()

    if not Plot then
        return
    end

    BoundPlot = Plot

    Bind_Plot_Shop_Prompts(Plot)
    Bind_Plot_Sign_Button_Motion(Plot)
end

local function Bind_Frame_Close_Button(Frame: GuiObject)
    for _, Descendant in Frame:GetDescendants() do
        if
            not Descendant:IsA("GuiButton")
            or (Descendant.Name ~= "Close" and Descendant.Name ~= "Close Button" and Descendant.Name ~= "CloseButton")
        then
            continue
        end

        Bind_Button_Motion(Descendant)

        if Descendant:GetAttribute("UiFrameCloseBound") then
            continue
        end

        Descendant:SetAttribute("UiFrameCloseBound", true)

        Descendant.Activated:Connect(function()
            if ActiveFrame == Frame then
                Close_Active_Frame()
            else
                Close_Frame(Frame)
            end
        end)
    end
end

local function Bind_Frame_Close_Buttons()
    if not MainGui then
        return
    end

    local Frames = MainGui:FindFirstChild("Frames")

    if not Frames then
        return
    end

    for FrameName in Constants.FrameNames do
        local Frame = Frames:FindFirstChild(FrameName)

        if Frame and Frame:IsA("GuiObject") then
            Bind_Frame_Close_Button(Frame)
        end
    end
end

local function Find_First_Text_Label(Container: Instance?): TextLabel?
    if not Container then
        return nil
    end

    if Container:IsA("TextLabel") then
        return Container
    end

    return Container:FindFirstChildWhichIsA("TextLabel", true)
end

function MoneyMultiplierUi.Is_Price_Object(Object: Instance, Root: Instance): boolean
    local Current: Instance? = Object

    while Current and Current ~= Root do
        local Name = Normalize_Name(Current.Name)

        if Name == "price" or Name == "robuxprice" or string.find(Name, "price", 1, true) then
            return true
        end

        Current = Current.Parent
    end

    return false
end

function MoneyMultiplierUi.Get_Exact_Price_Label(Button: GuiObject): TextLabel?
    local PriceFrame = Button:FindFirstChild("price")
    local PriceLabel = PriceFrame and PriceFrame:FindFirstChild("Price")

    return if PriceLabel and PriceLabel:IsA("TextLabel") then PriceLabel else nil
end

function MoneyMultiplierUi.Find_Button_Title_Label(Button: GuiObject): TextLabel?
    for _, Name in { "Txt", "Title", "Text" } do
        local Label = Button:FindFirstChild(Name, true)

        if Label and Label:IsA("TextLabel") and not MoneyMultiplierUi.Is_Price_Object(Label, Button) then
            return Label
        end
    end

    for _, Descendant in Button:GetDescendants() do
        if Descendant:IsA("TextLabel") and not MoneyMultiplierUi.Is_Price_Object(Descendant, Button) then
            return Descendant
        end
    end

    return nil
end

function MoneyMultiplierUi.Set_Price_Visible(Button: GuiObject, IsVisible: boolean)
    local PriceLabel = MoneyMultiplierUi.Get_Exact_Price_Label(Button)

    if PriceLabel then
        PriceLabel.Visible = IsVisible
    end

    for _, Descendant in Button:GetDescendants() do
        if Descendant:IsA("GuiObject") and MoneyMultiplierUi.Is_Price_Object(Descendant, Button) then
            Descendant.Visible = IsVisible
        end
    end
end

function MoneyMultiplierUi.Set_Price_Text(Button: GuiObject, PriceText: string?)
    if type(PriceText) ~= "string" or PriceText == "" then
        return
    end

    local function Set_Label(Label: TextLabel)
        Label.Text = PriceText
    end

    local ExactPriceLabel = MoneyMultiplierUi.Get_Exact_Price_Label(Button)

    if ExactPriceLabel then
        Set_Label(ExactPriceLabel)
        return
    end

    for _, Descendant in Button:GetDescendants() do
        if Descendant:IsA("TextLabel") and MoneyMultiplierUi.Is_Price_Object(Descendant, Button) then
            Set_Label(Descendant)
        end
    end
end

function MoneyMultiplierUi.Resolve_Price(ProductId: number): string?
    if MoneyMultiplierUi.PriceCache[ProductId] ~= nil then
        return MoneyMultiplierUi.PriceCache[ProductId]
    end

    if MoneyMultiplierUi.PriceWaiters[ProductId] then
        return nil
    end

    MoneyMultiplierUi.PriceWaiters[ProductId] = true

    task.spawn(function()
        local ProductInfo = Util.Get_Product_Info(ProductId)
        local PriceText = nil

        if type(ProductInfo) == "table" and type(ProductInfo.PriceInRobux) == "number" then
            PriceText = tostring(ProductInfo.PriceInRobux)
        end

        MoneyMultiplierUi.PriceCache[ProductId] = PriceText
        MoneyMultiplierUi.PriceWaiters[ProductId] = nil
    end)

    return nil
end

function MoneyMultiplierUi.Update_Price_Text(Button: GuiObject, ProductId: number, FallbackPrice: number?)
    local PriceText = MoneyMultiplierUi.Resolve_Price(ProductId)

    if PriceText then
        MoneyMultiplierUi.Set_Price_Text(Button, PriceText)
        return
    end

    if type(FallbackPrice) == "number" then
        MoneyMultiplierUi.Set_Price_Text(Button, tostring(FallbackPrice))
    end

    task.spawn(function()
        while Button.Parent and MoneyMultiplierUi.PriceWaiters[ProductId] do
            task.wait(0.1)
        end

        if not Button.Parent then
            return
        end

        local CachedPriceText = MoneyMultiplierUi.PriceCache[ProductId]

        if type(CachedPriceText) == "string" and CachedPriceText ~= "" then
            MoneyMultiplierUi.Set_Price_Text(Button, CachedPriceText)
        end
    end)
end

function MoneyMultiplierUi.Bind_Button(Button: Instance?)
    if not Button or not Button:IsA("GuiButton") then
        return
    end

    if Button:GetAttribute("MoneyMultiplierPromptBound") then
        return
    end

    Button:SetAttribute("MoneyMultiplierPromptBound", true)
    Button.Activated:Connect(function()
        if Is_Ui_Activation_Blocked() then
            return
        end

        local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
        local NextMultiplier = RobuxProducts.GetNextMoneyMultiplier(peek(FusionValues.MoneyMultiplier))
        local Product = NextMultiplier and RobuxProducts.GetMoneyMultiplierProduct(NextMultiplier)

        if not Product or not Product.ProductId then
            return
        end

        game:GetService("MarketplaceService"):PromptProductPurchase(LocalPlayer, Product.ProductId)
    end)
end

function MoneyMultiplierUi.Update_Button()
    if not DoubleMoneyButton or not DoubleMoneyButton.Parent then
        return
    end

    local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
    local NextMultiplier = RobuxProducts.GetNextMoneyMultiplier(peek(FusionValues.MoneyMultiplier))
    local Product = NextMultiplier and RobuxProducts.GetMoneyMultiplierProduct(NextMultiplier)
    local ProductId = Product and Product.ProductId
    local StateKey = `{NextMultiplier or 0}:{ProductId or 0}`

    if StateKey == MoneyMultiplierUi.LastStateKey then
        return
    end

    MoneyMultiplierUi.LastStateKey = StateKey

    local TitleLabel = MoneyMultiplierUi.Find_Button_Title_Label(DoubleMoneyButton)

    if Product and ProductId and NextMultiplier then
        if TitleLabel then
            TitleLabel.Text = `{NextMultiplier}x MONEY`
        end

        DoubleMoneyButton:SetAttribute("DeveloperProduct", ProductId)
        DoubleMoneyButton:SetAttribute("ProductPrice", ProductId)
        DoubleMoneyButton.Active = true
        MoneyMultiplierUi.Set_Price_Visible(DoubleMoneyButton, true)
        MoneyMultiplierUi.Update_Price_Text(DoubleMoneyButton, ProductId, Product.PriceRobux)
    else
        if TitleLabel then
            TitleLabel.Text = "MAX"
        end

        DoubleMoneyButton:SetAttribute("DeveloperProduct", nil)
        DoubleMoneyButton:SetAttribute("ProductPrice", nil)
        DoubleMoneyButton.Active = false
        MoneyMultiplierUi.Set_Price_Visible(DoubleMoneyButton, false)
    end
end

local function Get_Lasso_Shop_Content(): Instance?
    local LassoShop = Get_Frame("LassoShop")

    if not LassoShop then
        return nil
    end

    return LassoShop:FindFirstChild("Content")
end

local function Format_Lasso_Price(Price: number): string
    if Price <= 0 then
        return "FREE"
    end

    return "$" .. Format_Cash_Amount(Price)
end

local function Format_Display_Number(Value: number): string
    return Util.Abbreviate_Number(math.max(0, math.floor(Value + 0.5)), 1)
end

local function Is_Robux_Only_Lasso(LassoName: string): boolean
    return LassoName == "Void"
end

local function Has_Lasso_Robux_Purchase(LassoData: Lassos.LassoData): boolean
    return Is_Robux_Only_Lasso(LassoData.Name) or type(LassoData.RobuxProductId) == "number"
end

local function Is_Tutorial_Lasso_Shop_Step(): boolean
    if peek(FusionValues.TutorialStepReceived) ~= true then
        return false
    end

    return not TutorialSteps.Is_Complete(TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep)))
end

local function Is_Tutorial_Lasso_Allowed(LassoName: string): boolean
    return LassoName == TutorialSteps.NextLasso
end

local function Is_Tutorial_Lasso_Blocked(LassoName: string): boolean
    return Is_Tutorial_Lasso_Shop_Step() and not Is_Tutorial_Lasso_Allowed(LassoName)
end

local function Set_Gui_Button_Enabled(Button: Instance?, Enabled: boolean)
    if not Button or not Button:IsA("GuiButton") then
        return
    end

    Button.Active = Enabled
    Button.Interactable = Enabled
    Button.AutoButtonColor = Enabled
end

local function Set_Lasso_Tutorial_Hide(Card: Instance, Visible: boolean)
    for _, Name in { "Hide", "OutOfStock", "Locked" } do
        local Object = Card:FindFirstChild(Name)

        if Object and Object:IsA("GuiObject") then
            Object.Visible = Visible
        end
    end
end

local function Get_Direct_Text_Label(Parent: Instance, ChildName: string): TextLabel?
    local Child = Parent:FindFirstChild(ChildName)

    if Child and Child:IsA("TextLabel") then
        return Child
    end

    return nil
end

local function Set_Button_Label(Button: Instance?, Text: string)
    local Label = Find_First_Text_Label(Button)

    if Label then
        Label.Text = Text
    end
end

local function Get_Any_Lasso_Buy_Button_Template(Content: Instance): ImageButton?
    for _, Card in Content:GetChildren() do
        local Button = Card:FindFirstChild("Buy Button")

        if Button and Button:IsA("ImageButton") then
            return Button
        end
    end

    return nil
end

local function Get_Lasso_Buy_Label_Template(Content: Instance): TextLabel?
    local Button = Get_Any_Lasso_Buy_Button_Template(Content)

    if not Button then
        return nil
    end

    local Label = Button:FindFirstChildWhichIsA("TextLabel")

    if Label and Label:IsA("TextLabel") then
        return Label
    end

    return nil
end

local function Get_Robux_State_Label(RobuxButton: GuiObject, Content: Instance): TextLabel?
    local ExistingLabel = RobuxButton:FindFirstChild(Constants.LassoShopRobuxStateLabelName)

    if ExistingLabel and ExistingLabel:IsA("TextLabel") then
        return ExistingLabel
    end

    local Template = Get_Lasso_Buy_Label_Template(Content)

    if not Template then
        return nil
    end

    local Label = Template:Clone()
    Label.Name = Constants.LassoShopRobuxStateLabelName
    Label.Visible = false
    Label.Parent = RobuxButton

    return Label
end

local function Set_Robux_Price_Content_Visible(RobuxButton: GuiObject, Visible: boolean)
    for _, Child in RobuxButton:GetChildren() do
        if Child.Name == Constants.LassoShopRobuxStateLabelName then
            continue
        end

        local Name = Normalize_Name(Child.Name)

        if
            Child:IsA("GuiObject")
            and (
                Name == "price"
                or Name == "robuxprice"
                or string.find(Name, "price", 1, true)
                or Child:IsA("TextLabel")
                or Child:IsA("ImageLabel")
            )
        then
            Child.Visible = Visible
        end
    end
end

local function Get_Lasso_Card_Buy_Button(Card: Instance, Content: Instance): ImageButton?
    if Is_Robux_Only_Lasso(Card.Name) then
        return nil
    end

    local BuyButton = Card:FindFirstChild("Buy Button")

    if BuyButton and BuyButton:IsA("ImageButton") then
        return BuyButton
    end

    local Template = Get_Any_Lasso_Buy_Button_Template(Content)

    if not Template then
        return nil
    end

    BuyButton = Template:Clone()
    BuyButton.Name = "Buy Button"
    BuyButton:SetAttribute("UiMotionBound", nil)
    BuyButton:SetAttribute("LassoShopBuyBound", nil)
    BuyButton.Parent = Card

    return BuyButton
end

local function Is_Lasso_Owned(LassoName: string): boolean
    return Lassos.Is_Owned(peek(FusionValues.OwnedLassos), LassoName)
end

local function Is_Image_Display(Object: Instance?): boolean
    return Object ~= nil and (Object:IsA("ImageLabel") or Object:IsA("ImageButton"))
end

local function Set_Lasso_Display_Image(Card: Instance, Image: string)
    local Display = Card:FindFirstChild("Display")

    if not Display then
        return
    end

    for _, Descendant in Display:GetDescendants() do
        if Descendant.Name == "Image" and Is_Image_Display(Descendant) then
            (Descendant :: ImageLabel).Image = Image
        end
    end
end

local function Update_Lasso_Card(Card: GuiObject, Content: Instance)
    local LassoData = Lassos.Get(Card.Name)

    if not LassoData then
        return
    end

    Set_Lasso_Display_Image(Card, LassoData.Image)

    local NameLabel = Get_Direct_Text_Label(Card, "Lasso Name")
    local PriceLabel = Get_Direct_Text_Label(Card, "$10M")
    local StrengthLabel = Get_Direct_Text_Label(Card, "Strength: 67") or Get_Direct_Text_Label(Card, "Strength : 67")

    if NameLabel then
        NameLabel.Text = LassoData.DisplayName
    end

    local IsRobuxOnly = Is_Robux_Only_Lasso(LassoData.Name)

    if PriceLabel then
        if IsRobuxOnly then
            PriceLabel.Text = "Limited"
            Bind_Rainbow_Effect(PriceLabel)
        elseif Is_Tutorial_Lasso_Shop_Step() and Is_Tutorial_Lasso_Allowed(LassoData.Name) then
            PriceLabel.Text = "FREE"
        else
            PriceLabel.Text = Format_Lasso_Price(LassoData.Price)
        end
    end

    if StrengthLabel then
        StrengthLabel.Text = `Strength: {Format_Display_Number(LassoData.Strength)}`
    end

    local Owned = Is_Lasso_Owned(LassoData.Name)
    local Equipped = peek(FusionValues.Lasso) == LassoData.Name
    local BuyButton = Get_Lasso_Card_Buy_Button(Card, Content)
    local RobuxButton = Card:FindFirstChild("Robux Button")
    local GiftButton = Card:FindFirstChild("Gift")
    local ExistingBuyButton = Card:FindFirstChild("Buy Button")
    local HasRobuxPurchase = Has_Lasso_Robux_Purchase(LassoData)
    local TutorialBlocked = Is_Tutorial_Lasso_Blocked(LassoData.Name)

    Set_Lasso_Tutorial_Hide(Card, TutorialBlocked)

    if IsRobuxOnly and ExistingBuyButton and ExistingBuyButton:IsA("GuiObject") then
        ExistingBuyButton.Visible = false
    end

    if BuyButton then
        local TutorialFreeBuy = Is_Tutorial_Lasso_Shop_Step()
            and Is_Tutorial_Lasso_Allowed(LassoData.Name)
            and not Owned

        BuyButton.Visible = true
        Set_Gui_Button_Enabled(BuyButton, not TutorialBlocked)
        Set_Button_Label(
            BuyButton,
            if TutorialFreeBuy then "FREE" elseif Owned then if Equipped then "Equipped" else "Equip" else "BUY"
        )
    end

    if RobuxButton and RobuxButton:IsA("GuiObject") then
        local ShouldUseRobuxButtonAsEquip = IsRobuxOnly and Owned

        RobuxButton.Visible = HasRobuxPurchase
        RobuxButton:SetAttribute(
            Constants.RobuxShopPromptDisabledAttribute,
            if ShouldUseRobuxButtonAsEquip then true else nil
        )
        Set_Robux_Price_Content_Visible(RobuxButton, not ShouldUseRobuxButtonAsEquip)

        if ShouldUseRobuxButtonAsEquip then
            local StateLabel = Get_Robux_State_Label(RobuxButton, Content)

            if StateLabel then
                StateLabel.Text = if Equipped then "Equipped" else "Equip"
                StateLabel.Visible = true
            end
        else
            local StateLabel = RobuxButton:FindFirstChild(Constants.LassoShopRobuxStateLabelName)

            if StateLabel and StateLabel:IsA("TextLabel") then
                StateLabel.Visible = false
            end
        end

        Set_Gui_Button_Enabled(RobuxButton, not TutorialBlocked)
    end

    if GiftButton and GiftButton:IsA("GuiButton") then
        Set_Gui_Button_Enabled(GiftButton, not TutorialBlocked)
    end
end

local function Get_Next_Affordable_Lasso(): Lassos.LassoData?
    local Active = Is_Tutorial_Active()

    if Active then
        return nil
    end

    local OwnedLassos = Lassos.Normalize_Owned(peek(FusionValues.OwnedLassos))
    local Cash = tonumber(peek(FusionValues.Cash)) or 0

    for _, LassoName in Lassos.Order do
        local LassoData = Lassos.Get(LassoName)

        if not LassoData or LassoData.RobuxOnly or LassoData.Price <= 0 or Lassos.Is_Owned(OwnedLassos, LassoName) then
            continue
        end

        if Cash >= LassoData.Price then
            return LassoData
        end

        return nil
    end

    return nil
end

local function Update_Lasso_Availability_Notification()
    local LassoData = Get_Next_Affordable_Lasso()

    if not LassoData then
        LastAffordableLassoName = nil
        return
    end

    if LastAffordableLassoName == LassoData.Name then
        return
    end

    LastAffordableLassoName = LassoData.Name
    LocalNotifications.Push(`New lasso available: {LassoData.DisplayName}!`, "Info", 4)
end

local function Bind_Lasso_Card(Card: GuiObject, Content: Instance)
    local LassoData = Lassos.Get(Card.Name)

    if not LassoData then
        return
    end

    local IsRobuxOnly = Is_Robux_Only_Lasso(LassoData.Name)
    local BuyButton = Get_Lasso_Card_Buy_Button(Card, Content)
    local RobuxButton = Card:FindFirstChild("Robux Button")
    local GiftButton = Card:FindFirstChild("Gift")
    local ExistingBuyButton = Card:FindFirstChild("Buy Button")

    if IsRobuxOnly and ExistingBuyButton and ExistingBuyButton:IsA("GuiObject") then
        ExistingBuyButton.Visible = false
    end

    if BuyButton then
        Bind_Button_Motion(BuyButton)

        if not BuyButton:GetAttribute("LassoShopBuyBound") then
            BuyButton:SetAttribute("LassoShopBuyBound", true)
            BuyButton.Activated:Connect(function()
                if Is_Ui_Activation_Blocked() then
                    return
                end

                if Is_Tutorial_Lasso_Blocked(LassoData.Name) then
                    return
                end

                if Is_Lasso_Owned(LassoData.Name) then
                    if peek(FusionValues.Lasso) ~= LassoData.Name then
                        Network.EquipLasso.Fire(LassoData.Name)
                    end

                    if Is_Tutorial_Lasso_Shop_Step() and Is_Tutorial_Lasso_Allowed(LassoData.Name) then
                        Equip_Inventory_Slot("Lasso")
                        Close_Active_Frame_Immediately()
                    end

                    return
                end

                Network.BuyLasso.Fire(LassoData.Name)

                if Is_Tutorial_Lasso_Shop_Step() and Is_Tutorial_Lasso_Allowed(LassoData.Name) then
                    Equip_Inventory_Slot("Lasso")
                    Close_Active_Frame_Immediately()
                end
            end)
        end
    end

    if RobuxButton and RobuxButton:IsA("GuiButton") then
        Bind_Button_Motion(RobuxButton)

        if not RobuxButton:GetAttribute(Constants.LassoShopRobuxEquipBoundAttribute) then
            RobuxButton:SetAttribute(Constants.LassoShopRobuxEquipBoundAttribute, true)
            RobuxButton.Activated:Connect(function()
                if Is_Ui_Activation_Blocked() then
                    return
                end

                if Is_Tutorial_Lasso_Blocked(LassoData.Name) then
                    return
                end

                if not IsRobuxOnly then
                    RobuxButton:SetAttribute(Constants.RobuxShopPromptDisabledAttribute, nil)
                    return
                end

                if not Is_Lasso_Owned(LassoData.Name) then
                    return
                end

                RobuxButton:SetAttribute(Constants.RobuxShopPromptDisabledAttribute, true)

                if peek(FusionValues.Lasso) ~= LassoData.Name then
                    Network.EquipLasso.Fire(LassoData.Name)
                end
            end)
        end
    end

    if GiftButton and GiftButton:IsA("GuiButton") then
        Bind_Button_Motion(GiftButton)
    end
end

local function Bind_Lasso_Shop()
    local Content = Get_Lasso_Shop_Content()

    if not Content then
        return
    end

    for _, Card in Content:GetChildren() do
        if Card:IsA("GuiObject") then
            Bind_Lasso_Card(Card, Content)
        end
    end
end

local function Update_Lasso_Shop()
    local Content = Get_Lasso_Shop_Content()

    if not Content then
        return
    end

    for _, Card in Content:GetChildren() do
        if Card:IsA("GuiObject") then
            Update_Lasso_Card(Card, Content)
        end
    end
end

local function Cache_Data_Labels()
    if not MainGui then
        return
    end

    local EdgeLayer = MainGui:FindFirstChild("EdgeLayer")
    local CashBalance = EdgeLayer and EdgeLayer:FindFirstChild("Cash Balance")
    local FriendBoost = EdgeLayer and EdgeLayer:FindFirstChild("Friend Boost")

    CashLabel = Find_First_Text_Label(CashBalance)
    FriendBoostLabel = Find_First_Text_Label(FriendBoost)
end

local function Update_Data_Labels()
    local Cash = peek(FusionValues.Cash)
    local CashText = Format_Cash_Amount(if type(Cash) == "number" then Cash else 0)

    if CashText ~= LastCashText then
        LastCashText = CashText

        if CashLabel and CashLabel.Parent then
            CashLabel.Text = CashText
        end
    end

    local FriendBoost = peek(FusionValues.FriendBoost)
    local FriendBoostValue = if type(FriendBoost) == "number" then FriendBoost else 0
    local FriendBoostText = `Friend Boost +{Format_Display_Number(FriendBoostValue)}%`

    if FriendBoostText ~= LastFriendBoostText then
        LastFriendBoostText = FriendBoostText

        if FriendBoostLabel and FriendBoostLabel.Parent then
            FriendBoostLabel.Text = FriendBoostText
        end
    end
end

local function Cache_Held_Item_Text_Labels(Hud: Instance?)
    if not Hud then
        return
    end

    local CandidateLassoStrength = Hud:FindFirstChild("LassoStrength")
    local CandidateClickToPickup = Hud:FindFirstChild("ClickToPickup")

    if CandidateLassoStrength and CandidateLassoStrength:IsA("TextLabel") then
        LassoStrengthLabel = CandidateLassoStrength
        Get_Hud_Hint_State(CandidateLassoStrength)
    end

    if CandidateClickToPickup and CandidateClickToPickup:IsA("TextLabel") then
        ClickToPickupLabel = CandidateClickToPickup
        Get_Hud_Hint_State(CandidateClickToPickup)
    end
end

local function Update_Held_Item_Text()
    local CurrentEquippedSlot = peek(FusionValues.EquippedInventorySlot)
    local HideText = Should_Hide_Held_Item_Text()
    local LassoData = Get_Selected_Lasso_Data()
    local ShouldShowLasso = CurrentEquippedSlot == "Lasso" and not HideText and LassoData ~= nil
    local ShouldShowClickToPickup = CurrentEquippedSlot == "Hammer" and not HideText
    local SmoothLasso = not HideText and not (not ShouldShowLasso and ShouldShowClickToPickup)
    local SmoothClickToPickup = not HideText and not (not ShouldShowClickToPickup and ShouldShowLasso)

    if LassoStrengthLabel and LassoData then
        LassoStrengthLabel.Text = `Lasso Strength: 💪{Format_Display_Number(LassoData.Strength)}`
    end

    if ClickToPickupLabel and ClickToPickupLabel.Text == "" then
        ClickToPickupLabel.Text = "Click to pickup 👆"
    end

    Set_Hud_Hint_Visible(LassoStrengthLabel, ShouldShowLasso, SmoothLasso)
    Set_Hud_Hint_Visible(ClickToPickupLabel, ShouldShowClickToPickup, SmoothClickToPickup)
    Update_Notifications_Position_For_Held_Item_Text()
end

local function Initialize(): boolean
    if Initialized or Initializing then
        return Initialized
    end

    Initializing = true

    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local CandidateMainGui = PlayerGui and PlayerGui:FindFirstChild("Main")

    if not CandidateMainGui or not CandidateMainGui:IsA("ScreenGui") then
        Initializing = false
        return false
    end

    MainGui = CandidateMainGui

    local Hud = MainGui:FindFirstChild("Hud Frame")
    local EdgeLayer = MainGui:FindFirstChild("EdgeLayer")
    local Buttons = Hud and Hud:FindFirstChild("Buttons")

    Bind_Frame_Button(Buttons and Buttons:FindFirstChild("Shop"), "Shop")
    Bind_Frame_Button(Buttons and Buttons:FindFirstChild("Index"), "Index")
    Bind_Frame_Button(Buttons and Buttons:FindFirstChild("Rewards"), "PlaytimeRewards")

    local CandidateDoubleMoneyButton = Hud and Hud:FindFirstChild("2x Money")

    if CandidateDoubleMoneyButton and CandidateDoubleMoneyButton:IsA("GuiObject") then
        DoubleMoneyButton = CandidateDoubleMoneyButton
        Cache_Double_Money_Position()
    end

    Bind_Motion_Only_Button(CandidateDoubleMoneyButton)
    MoneyMultiplierUi.Bind_Button(CandidateDoubleMoneyButton)

    Bind_Plot_Button(EdgeLayer and EdgeLayer:FindFirstChild("Plot"))
    HudPlaceButton.Initialize(MainGui, Hud, EdgeLayer)

    Bind_Inventory()
    Bind_Lasso_Shop()
    DailyRewardsUI.Initialize(MainGui, Bind_Button_Motion, Is_Ui_Activation_Blocked)
    FoodShopUI.Initialize(
        MainGui,
        Bind_Button_Motion,
        Is_Ui_Activation_Blocked,
        Close_Active_Frame_Immediately,
        Equip_Inventory_Slot
    )
    GiftingUI.Initialize(MainGui, Bind_Button_Motion, Is_Ui_Activation_Blocked, Open_Frame)
    OfflineRewardsUI.Initialize(
        MainGui,
        Bind_Button_Motion,
        Is_Ui_Activation_Blocked,
        Open_Frame,
        Close_Active_Frame,
        Open_Daily_Rewards_After_Offline,
        DailyRewardsUI.Has_Ready_Reward
    )
    PlaytimeRewardsUI.Initialize(MainGui, Bind_Button_Motion, Is_Ui_Activation_Blocked)
    RobuxShopUI.Initialize(MainGui, Bind_Button_Motion, Is_Ui_Activation_Blocked)
    ShopExclamationUI.Initialize(MainGui)
    UiImageEffects.Initialize(MainGui)
    Bind_Frame_Close_Buttons()
    Bind_Daily_Rewards_Topbar()
    Open_Daily_Rewards_On_Join()
    Bind_Music_Topbar()
    Cache_Hud_Tween_Targets()
    Cache_Data_Labels()
    Cache_Held_Item_Text_Labels(Hud)

    Initialized = true
    Initializing = false

    return true
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        if not Initialize() then
            return
        end

        Bind_Local_Plot_Interactions()
        Update_Data_Labels()
        MoneyMultiplierUi.Update_Button()
        Update_Inventory_Slot_Images()
        TutorialAutoEquip.Step(Equip_Inventory_Slot)
        Replicate_Equipped_Inventory_Slot()
        Update_Held_Item_Text()
        Update_Disclaimer_Visibility()
        HudPlaceButton.Step(Should_Hide_Held_Item_Text(), peek(FusionValues.EquippedInventorySlot))
        Update_Notifications_Position_For_Held_Item_Text()
        Update_Lasso_Throw_Ui_Block()
        InventoryUI.Step()
        DailyRewardsUI.Step()
        FoodShopUI.Step()
        GiftingUI.Step()
        OfflineRewardsUI.Step()
        PlaytimeRewardsUI.Step()
        RobuxShopUI.Step()
        SellDialogUI.Step()
        ShopExclamationUI.Step()
        Bind_Lasso_Shop()
        Update_Lasso_Shop()
        Update_Lasso_Availability_Notification()
        Open_Daily_Rewards_On_Join()
    end,
}
