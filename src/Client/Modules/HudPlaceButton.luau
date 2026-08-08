local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local FusionValues = require(script.Parent.FusionValues)
local Network = require(ReplicatedFirst.Network)
local PlotAreaMath = require(ReplicatedStorage.Shared.Modules.PlotAreaMath)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)

local peek = Fusion.peek
local LocalPlayer = Players.LocalPlayer

local HudPlaceButton = {}

local ButtonTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ShowTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HideTweenInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HoverScale = 1.08
local PressScale = 0.92
local HiddenScale = 0.96
local NotificationYScale = 0.65
local CatchMinigameActiveAttribute = "CatchMinigameActive"
local PlaceRequestSuppressSeconds = 0.1
local LocalPlotCacheSeconds = 1
local FeedAmountEnabledImage = "rbxassetid://108188333176085"
local FeedAmountDisabledImage = "rbxassetid://72472520617691"
local PlaceButton: GuiButton? = nil
local MaxSquishiesDisplay: GuiObject? = nil
local CASH_GREEN_RICH_TEXT_COLOR = "rgb(0,206,7)"
local FeedAmountButtons: GuiObject? = nil
local SelectFeedAmount: GuiObject? = nil
local PlaceButtonState = {
    TargetVisible = false,
    Token = nil :: any,
    Tween = nil :: Tween?,
}
local MaxSquishiesDisplayState = {
    TargetVisible = false,
    Token = nil :: any,
    Tween = nil :: Tween?,
}
local FeedAmountButtonsState = {
    TargetVisible = false,
    Token = nil :: any,
    Tween = nil :: Tween?,
}
local SelectFeedAmountState = {
    TargetVisible = false,
    Token = nil :: any,
    Tween = nil :: Tween?,
}
local SelectedFeedAmount = 1
local PendingPlaceItemId: string? = nil
local PendingPlaceExpiresAt = 0
local CachedLocalPlot: Instance? = nil
local LastLocalPlotLookupAt = 0
local Hide_Place_Displays_Smoothly: (() -> ())? = nil

local function Normalize_Name(Name: string): string
    return string.lower(string.gsub(Name, "%W", ""))
end

local function Is_Catch_Minigame_Active(): boolean
    if LocalPlayer:GetAttribute(CatchMinigameActiveAttribute) == true then
        return true
    end

    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local MinigameGui = PlayerGui and PlayerGui:FindFirstChild("Minigame")

    return MinigameGui ~= nil and MinigameGui:IsA("ScreenGui") and MinigameGui.Enabled
end

local function Is_Tutorial_Active(): boolean
    if peek(FusionValues.TutorialStepReceived) ~= true then
        return false
    end

    return not TutorialSteps.Is_Complete(peek(FusionValues.TutorialStep))
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
    if Button:GetAttribute("HudPlaceButtonMotionBound") then
        return
    end

    Button:SetAttribute("HudPlaceButtonMotionBound", true)
    Button.Active = true

    local Scale = Get_Or_Create_Scale(Button, "ButtonMotionScale")
    local Hovering = false

    Button.MouseEnter:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        Hovering = true
        Play_Ui_Sound("Hover")
        Tween(Scale, ButtonTweenInfo, { Scale = HoverScale })
    end)

    Button.MouseLeave:Connect(function()
        Hovering = false
        Tween(Scale, ButtonTweenInfo, { Scale = 1 })
    end)

    Button.MouseButton1Down:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        Play_Ui_Sound("Click")
        Tween(Scale, ButtonTweenInfo, { Scale = PressScale })
    end)

    Button.MouseButton1Up:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        Tween(Scale, ButtonTweenInfo, { Scale = if Hovering then HoverScale else 1 })
    end)
end

local function Get_Slot_Number_From_Name(SlotName: any): number?
    if type(SlotName) ~= "string" then
        return nil
    end

    if SlotName == "Lasso" then
        return 1
    elseif SlotName == "Hammer" then
        return 2
    end

    return tonumber(SlotName) or tonumber(string.match(SlotName, "^Item%s+(%d+)$"))
end

local function Get_Hotbar_Assignment_For_Slot(Slot: number): any?
    local HotbarSlots = peek(FusionValues.HotbarSlots)

    if type(HotbarSlots) ~= "table" then
        return nil
    end

    for Key, Assignment in HotbarSlots do
        if type(Assignment) ~= "table" then
            continue
        end

        local AssignmentSlot = Assignment.Slot

        if type(AssignmentSlot) ~= "number" then
            AssignmentSlot = if type(Key) == "number" then Key else tonumber(Key)
        end

        if AssignmentSlot == Slot then
            return Assignment
        end
    end

    return nil
end

local function Owns_Squishy(ItemId: any): boolean
    if type(ItemId) ~= "string" or ItemId == "" then
        return false
    end

    local OwnedSquishies = peek(FusionValues.OwnedSquishies)

    if type(OwnedSquishies) ~= "table" then
        return false
    end

    for _, Item in OwnedSquishies do
        if type(Item) == "table" and Item.Id == ItemId and Item.Type == "Squishy" then
            return true
        end
    end

    return false
end

local function Owns_Food(ItemId: any): boolean
    if type(ItemId) ~= "string" or ItemId == "" then
        return false
    end

    local OwnedFood = peek(FusionValues.OwnedFood)

    if type(OwnedFood) ~= "table" then
        return false
    end

    for _, Item in OwnedFood do
        if type(Item) == "table" and Item.Id == ItemId and Item.Type == "Food" then
            local Amount = if type(Item.Amount) == "number" then Item.Amount else 0

            return Amount > 0
        end
    end

    return false
end

local function Get_Equipped_Squishy_Item_Id(CurrentEquippedSlot: any): string?
    local EquippedInventoryItemId = peek(FusionValues.EquippedInventoryItemId)

    if Owns_Squishy(EquippedInventoryItemId) then
        return EquippedInventoryItemId
    end

    local Slot = Get_Slot_Number_From_Name(CurrentEquippedSlot)

    if not Slot or Slot < 3 then
        return nil
    end

    local Assignment = Get_Hotbar_Assignment_For_Slot(Slot)

    if type(Assignment) == "table" and Assignment.ItemType == "Squishy" and Owns_Squishy(Assignment.ItemId) then
        return Assignment.ItemId
    end

    return nil
end

local function Get_Equipped_Food_Item_Id(CurrentEquippedSlot: any): string?
    local Slot = Get_Slot_Number_From_Name(CurrentEquippedSlot)

    if not Slot or Slot < 3 then
        return nil
    end

    local Assignment = Get_Hotbar_Assignment_For_Slot(Slot)

    if type(Assignment) == "table" and Assignment.ItemType == "Food" and Owns_Food(Assignment.ItemId) then
        return Assignment.ItemId
    end

    return nil
end

local function Get_Local_Player_Plot(): Instance?
    if CachedLocalPlot and CachedLocalPlot.Parent then
        if CachedLocalPlot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return CachedLocalPlot
        end

        CachedLocalPlot = nil
    end

    local Now = os.clock()

    if Now - LastLocalPlotLookupAt < LocalPlotCacheSeconds then
        return CachedLocalPlot
    end

    LastLocalPlotLookupAt = Now
    local Plots = workspace:FindFirstChild("Plots")

    if not Plots then
        CachedLocalPlot = nil
        return nil
    end

    for _, Plot in Plots:GetChildren() do
        if Plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            CachedLocalPlot = Plot
            return Plot
        end
    end

    local ExpectedTitle = `{LocalPlayer.Name}'s Plot`

    for _, Plot in Plots:GetChildren() do
        local OwnerSign = Plot:FindFirstChild("OwnerSign")
        local Title = OwnerSign and OwnerSign:FindFirstChild("Title", true)

        if Title and Title:IsA("TextLabel") and Title.Text == ExpectedTitle then
            CachedLocalPlot = Plot
            return Plot
        end
    end

    CachedLocalPlot = nil
    return nil
end

local function Is_Local_Player_In_Unlocked_Plot_Area(): boolean
    local Plot = Get_Local_Player_Plot()
    local Character = LocalPlayer.Character
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if not Plot or not Root or not Root:IsA("BasePart") then
        return false
    end

    return PlotAreaMath.IsPositionInUnlockedArea(Plot, Root.Position)
end

local function Get_Local_Plot_Squishy_Count(): number
    local PlotSquishies = peek(FusionValues.PlotSquishies)

    if type(PlotSquishies) ~= "table" then
        return 0
    end

    local Count = 0

    for _, Item in PlotSquishies do
        if type(Item) == "table" then
            Count += 1
        end
    end

    return Count
end

local function Get_Text_Label(Root: Instance?): TextLabel?
    if not Root then
        return nil
    end

    if Root:IsA("TextLabel") then
        return Root
    end

    return Root:FindFirstChildWhichIsA("TextLabel", true)
end

local function Update_Max_Squishies_Text()
    local Label = Get_Text_Label(MaxSquishiesDisplay)

    if not Label then
        return
    end

    local Plot = Get_Local_Player_Plot()
    local CurrentCount = Get_Local_Plot_Squishy_Count()
    local MaxCount = PlotAreaMath.GetMaxSquishies(Plot)
    local Text = `Max Squishies: <font color="{CASH_GREEN_RICH_TEXT_COLOR}">{CurrentCount}/{MaxCount}</font>`

    Label.RichText = true

    if Label.Text ~= Text then
        Label.Text = Text
    end
end

local function Request_Place_Equipped_Squishy()
    if Is_Catch_Minigame_Active() then
        return
    end

    if PendingPlaceItemId and os.clock() < PendingPlaceExpiresAt then
        return
    end

    local ItemId = Get_Equipped_Squishy_Item_Id(peek(FusionValues.EquippedInventorySlot))

    if not ItemId then
        return
    end

    PendingPlaceItemId = ItemId
    PendingPlaceExpiresAt = os.clock() + PlaceRequestSuppressSeconds

    if Hide_Place_Displays_Smoothly then
        Hide_Place_Displays_Smoothly()
    end

    Network.PlacePlotSquishy.Fire({
        ItemId = ItemId,
    })
end

local function Find_Place_Button(Root: Instance?): GuiButton?
    if not Root then
        return nil
    end

    for _, Name in { "Place", "PlaceButton", "Place Button", "PlaceSquishy", "Place Squishy" } do
        local Candidate = Root:FindFirstChild(Name, true)

        if Candidate and Candidate:IsA("GuiButton") then
            return Candidate
        end
    end

    for _, Descendant in Root:GetDescendants() do
        if not Descendant:IsA("GuiButton") then
            continue
        end

        local NormalizedName = Normalize_Name(Descendant.Name)

        if NormalizedName == "place" or NormalizedName == "placebutton" or NormalizedName == "placesquishy" then
            return Descendant
        end
    end

    return nil
end

local function Find_Max_Squishies_Display(Root: Instance?): GuiObject?
    if not Root then
        return nil
    end

    for _, Name in
        {
            "MaxSquishies",
            "Max Squishies",
            "MaxSquishys",
            "Max Squishys",
            "MaxSquishy",
            "Max Squishy",
            "SquishyMax",
            "Squishy Max",
            "SquishyLimit",
            "Squishy Limit",
        }
    do
        local Candidate = Root:FindFirstChild(Name, true)

        if Candidate and Candidate:IsA("GuiObject") then
            return Candidate
        end
    end

    for _, Descendant in Root:GetDescendants() do
        if not Descendant:IsA("GuiObject") then
            continue
        end

        local NormalizedName = Normalize_Name(Descendant.Name)

        if
            NormalizedName == "maxsquishies"
            or NormalizedName == "maxsquishys"
            or NormalizedName == "maxsquishy"
            or NormalizedName == "squishymax"
            or NormalizedName == "squishylimit"
        then
            return Descendant
        end
    end

    return nil
end

local function Find_Gui_Object(Root: Instance?, Names: { string }): GuiObject?
    if not Root then
        return nil
    end

    for _, Name in Names do
        local Candidate = Root:FindFirstChild(Name, true)

        if Candidate and Candidate:IsA("GuiObject") then
            return Candidate
        end
    end

    local NormalizedTargets = {}

    for _, Name in Names do
        NormalizedTargets[Normalize_Name(Name)] = true
    end

    for _, Descendant in Root:GetDescendants() do
        if Descendant:IsA("GuiObject") and NormalizedTargets[Normalize_Name(Descendant.Name)] then
            return Descendant
        end
    end

    return nil
end

local function Get_Feed_Button_Amount(Button: Instance): number?
    local Amount = tonumber(string.match(Button.Name, "^x(%d+)$"))

    if not Amount or Amount <= 0 then
        return nil
    end

    return math.floor(Amount)
end

local function Update_Feed_Amount_Button_Images()
    if not FeedAmountButtons then
        return
    end

    for _, Descendant in FeedAmountButtons:GetDescendants() do
        if not Descendant:IsA("ImageButton") then
            continue
        end

        local Amount = Get_Feed_Button_Amount(Descendant)

        if Amount then
            Descendant.Image = if Amount == SelectedFeedAmount then FeedAmountEnabledImage else FeedAmountDisabledImage
        end
    end
end

local function Bind_Feed_Amount_Button(Button: ImageButton)
    if Button:GetAttribute("FeedAmountButtonBound") then
        return
    end

    local Amount = Get_Feed_Button_Amount(Button)

    if not Amount then
        return
    end

    Button:SetAttribute("FeedAmountButtonBound", true)
    Bind_Button_Motion(Button)
    Button.Activated:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        SelectedFeedAmount = Amount
        Update_Feed_Amount_Button_Images()
    end)
end

local function Bind_Feed_Amount_Buttons()
    if not FeedAmountButtons then
        return
    end

    for _, Descendant in FeedAmountButtons:GetDescendants() do
        if Descendant:IsA("ImageButton") then
            Bind_Feed_Amount_Button(Descendant)
        end
    end

    Update_Feed_Amount_Button_Images()
end

local function Set_Scale_Visible(
    GuiObjectToShow: GuiObject?,
    State: any,
    ScaleName: string,
    ShouldShow: boolean,
    Smooth: boolean?
)
    if not GuiObjectToShow or not GuiObjectToShow.Parent then
        return
    end

    local Scale = Get_Or_Create_Scale(GuiObjectToShow, ScaleName)

    if State.TargetVisible == ShouldShow then
        if ShouldShow and not GuiObjectToShow.Visible then
            GuiObjectToShow.Visible = true
            Scale.Scale = HiddenScale
        end

        if ShouldShow and Smooth and math.abs(Scale.Scale - 1) > 0.001 then
            if State.Tween then
                State.Tween:Cancel()
            end

            State.Tween = Tween(Scale, ShowTweenInfo, { Scale = 1 })
        elseif not ShouldShow and not Smooth and GuiObjectToShow.Visible then
            if State.Tween then
                State.Tween:Cancel()
                State.Tween = nil
            end

            GuiObjectToShow.Visible = false
            Scale.Scale = HiddenScale
        end

        return
    end

    State.TargetVisible = ShouldShow

    local Token = {}
    State.Token = Token

    if State.Tween then
        State.Tween:Cancel()
        State.Tween = nil
    end

    if not Smooth then
        GuiObjectToShow.Visible = ShouldShow
        Scale.Scale = if ShouldShow then 1 else HiddenScale
        return
    end

    if ShouldShow then
        local WasVisible = GuiObjectToShow.Visible
        GuiObjectToShow.Visible = true

        if not WasVisible then
            Scale.Scale = HiddenScale
        end

        State.Tween = Tween(Scale, ShowTweenInfo, { Scale = 1 })
        return
    end

    local HideTween = Tween(Scale, HideTweenInfo, { Scale = HiddenScale })
    State.Tween = HideTween

    HideTween.Completed:Connect(function()
        if State.Token ~= Token then
            return
        end

        State.Tween = nil

        if GuiObjectToShow and GuiObjectToShow.Parent then
            GuiObjectToShow.Visible = false
        end
    end)
end

Hide_Place_Displays_Smoothly = function()
    Set_Scale_Visible(PlaceButton, PlaceButtonState, "PlaceButtonVisibleScale", false, true)
    Set_Scale_Visible(MaxSquishiesDisplay, MaxSquishiesDisplayState, "MaxSquishiesVisibleScale", false, true)
end

function HudPlaceButton.Initialize(MainGui: ScreenGui?, Hud: Instance?, EdgeLayer: Instance?)
    if not PlaceButton or not PlaceButton.Parent then
        PlaceButton = Find_Place_Button(Hud) or Find_Place_Button(EdgeLayer) or Find_Place_Button(MainGui)

        if PlaceButton then
            Bind_Button_Motion(PlaceButton)

            if not PlaceButton:GetAttribute("HudPlaceButtonActivatedBound") then
                PlaceButton:SetAttribute("HudPlaceButtonActivatedBound", true)
                PlaceButton.Activated:Connect(Request_Place_Equipped_Squishy)
            end

            PlaceButton.Visible = false
            Get_Or_Create_Scale(PlaceButton, "PlaceButtonVisibleScale").Scale = HiddenScale
        end
    end

    if not MaxSquishiesDisplay or not MaxSquishiesDisplay.Parent then
        MaxSquishiesDisplay = Find_Max_Squishies_Display(PlaceButton)
            or Find_Max_Squishies_Display(Hud)
            or Find_Max_Squishies_Display(EdgeLayer)
            or Find_Max_Squishies_Display(MainGui)

        if MaxSquishiesDisplay then
            MaxSquishiesDisplay.Visible = false
            Get_Or_Create_Scale(MaxSquishiesDisplay, "MaxSquishiesVisibleScale").Scale = HiddenScale
            Update_Max_Squishies_Text()
        end
    end

    if not FeedAmountButtons or not FeedAmountButtons.Parent then
        FeedAmountButtons = Find_Gui_Object(Hud, { "FeedAmountButtons", "Feed Amount Buttons" })
            or Find_Gui_Object(EdgeLayer, { "FeedAmountButtons", "Feed Amount Buttons" })
            or Find_Gui_Object(MainGui, { "FeedAmountButtons", "Feed Amount Buttons" })

        if FeedAmountButtons then
            FeedAmountButtons.Visible = false
            Get_Or_Create_Scale(FeedAmountButtons, "FeedAmountButtonsVisibleScale").Scale = HiddenScale
            Bind_Feed_Amount_Buttons()
        end
    end

    if not SelectFeedAmount or not SelectFeedAmount.Parent then
        SelectFeedAmount = Find_Gui_Object(Hud, { "SelectFeedAmount", "Select Feed Amount" })
            or Find_Gui_Object(EdgeLayer, { "SelectFeedAmount", "Select Feed Amount" })
            or Find_Gui_Object(MainGui, { "SelectFeedAmount", "Select Feed Amount" })

        if SelectFeedAmount then
            SelectFeedAmount.Visible = false
            Get_Or_Create_Scale(SelectFeedAmount, "SelectFeedAmountVisibleScale").Scale = HiddenScale
        end
    end
end

function HudPlaceButton.Step(HideForUi: boolean, CurrentEquippedSlot: any)
    if not PlaceButton or not PlaceButton.Parent or not FeedAmountButtons or not FeedAmountButtons.Parent then
        local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local MainGui = PlayerGui and PlayerGui:FindFirstChild("Main")

        if MainGui and MainGui:IsA("ScreenGui") then
            HudPlaceButton.Initialize(MainGui, MainGui:FindFirstChild("Hud Frame"), MainGui:FindFirstChild("EdgeLayer"))
        end

        if not PlaceButton or not PlaceButton.Parent then
            return
        end
    end

    if PendingPlaceItemId and os.clock() >= PendingPlaceExpiresAt then
        PendingPlaceItemId = nil
    end

    local EquippedSquishyId = Get_Equipped_Squishy_Item_Id(CurrentEquippedSlot)
    local EquippedFoodId = Get_Equipped_Food_Item_Id(CurrentEquippedSlot)
    local IsPendingPlacedSquishy = PendingPlaceItemId ~= nil
        and PendingPlaceItemId == EquippedSquishyId
        and os.clock() < PendingPlaceExpiresAt
    local HideInstantly = HideForUi or CurrentEquippedSlot == "Lasso" or CurrentEquippedSlot == "Hammer"
    local ShouldShow = not HideForUi
        and CurrentEquippedSlot ~= "Lasso"
        and CurrentEquippedSlot ~= "Hammer"
        and EquippedSquishyId ~= nil
        and not IsPendingPlacedSquishy
        and Is_Local_Player_In_Unlocked_Plot_Area()
    local Smooth = ShouldShow or not HideInstantly
    local ShouldShowFeedAmount = not Is_Tutorial_Active() and not HideForUi and EquippedFoodId ~= nil
    local FeedSmooth = ShouldShowFeedAmount or not HideInstantly

    Update_Max_Squishies_Text()
    Bind_Feed_Amount_Buttons()
    Set_Scale_Visible(PlaceButton, PlaceButtonState, "PlaceButtonVisibleScale", ShouldShow, Smooth)
    Set_Scale_Visible(MaxSquishiesDisplay, MaxSquishiesDisplayState, "MaxSquishiesVisibleScale", ShouldShow, Smooth)
    Set_Scale_Visible(
        FeedAmountButtons,
        FeedAmountButtonsState,
        "FeedAmountButtonsVisibleScale",
        ShouldShowFeedAmount,
        FeedSmooth
    )
    Set_Scale_Visible(
        SelectFeedAmount,
        SelectFeedAmountState,
        "SelectFeedAmountVisibleScale",
        ShouldShowFeedAmount,
        FeedSmooth
    )
end

function HudPlaceButton.IsVisible(): boolean
    return (PlaceButton ~= nil and PlaceButton.Visible) or (FeedAmountButtons ~= nil and FeedAmountButtons.Visible)
end

function HudPlaceButton.GetNotificationYScale(): number
    return NotificationYScale
end

function HudPlaceButton.GetSelectedFeedAmount(): number
    return SelectedFeedAmount
end

return table.freeze(HudPlaceButton)
