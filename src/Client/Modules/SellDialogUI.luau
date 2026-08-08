local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local FusionValues = require(script.Parent.FusionValues)
local LocalNotifications = require(script.Parent.LocalNotifications)
local Network = require(ReplicatedFirst.Network)
local PlaySellEffect = require(script.Parent.SellEffect)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local peek = Fusion.peek

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local SellDialogUI = {}

local SCREEN_GUI_NAME = "dialog"
local RESPONSES_FRAME_NAME = "dialogResponses"
local NPC_GUI_NAME = "gui"
local BUTTON_HEIGHT = 76
local BUTTON_PADDING = 12
local BUTTON_TEXT_MIN_SIZE = 28
local BUTTON_TEXT_MAX_SIZE = 42
local BUTTON_BACKGROUND_TRANSPARENCY = 0.5
local BUTTON_BORDER_STROKE_NAME = "ButtonStroke"
local BUTTON_BORDER_STROKE_THICKNESS = 3
local BUTTON_BORDER_STROKE_TRANSPARENCY_OFFSET = 0.25
local TEXT_STROKE_THICKNESS = 0.08
local RESPONSES_FRAME_WIDTH_SCALE = 0.48
local RESPONSES_FRAME_TOUCH_WIDTH_SCALE = 0.66
local RESPONSES_FRAME_BOTTOM_Y_SCALE = 0.82
local OPTION_COUNT = 9
local MAX_DISTANCE = 15
local TYPEWRITER_DELAY = 0.03
local RESULT_CLOSE_DELAY = 0.85
local BUTTON_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local UI_SLIDE_TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FOV_IN_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FOV_OUT_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FONT = Enum.Font.FredokaOne

local function Get_Dialog_Scale(): number
    local CurrentCamera = workspace.CurrentCamera or Camera
    local ViewportSize = if CurrentCamera then CurrentCamera.ViewportSize else Vector2.new(1280, 720)
    local ShortSide = math.min(ViewportSize.X, ViewportSize.Y)
    local Scale = math.clamp(ShortSide / 720, 0.68, 1)

    if UserInputService.TouchEnabled then
        return math.min(Scale, 0.86)
    end

    return Scale
end

local function Get_Response_Metrics()
    local Scale = Get_Dialog_Scale()
    local CurrentCamera = workspace.CurrentCamera or Camera
    local ViewportSize = if CurrentCamera then CurrentCamera.ViewportSize else Vector2.new(1280, 720)
    local IsNarrow = math.min(ViewportSize.X, ViewportSize.Y) <= 520

    return {
        ButtonHeight = math.floor(BUTTON_HEIGHT * Scale + 0.5),
        ButtonPadding = math.floor(BUTTON_PADDING * Scale + 0.5),
        WidthScale = if UserInputService.TouchEnabled or IsNarrow
            then RESPONSES_FRAME_TOUCH_WIDTH_SCALE
            else RESPONSES_FRAME_WIDTH_SCALE,
        TextMinSize = math.max(14, math.floor(BUTTON_TEXT_MIN_SIZE * Scale + 0.5)),
        TextMaxSize = math.max(18, math.floor(BUTTON_TEXT_MAX_SIZE * Scale + 0.5)),
    }
end

local CONFIRM_SELL_ALL_OPTIONS = {
    {
        Text = "Yes, sell my inventory",
        Mode = "All",
    },
    {
        Text = "Nevermind",
        LocalMessage = "Ok, see you another time!",
    },
}

local MAIN_OPTIONS = {
    {
        Text = "I want to sell my inventory",
        NextOptions = CONFIRM_SELL_ALL_OPTIONS,
    },
    {
        Text = "I want to sell this",
        Mode = "Equipped",
    },
    {
        Text = "Nevermind",
        LocalMessage = "Ok, see you another time!",
    },
}

local ActiveShop: Model? = nil
local ActivePrompt: ProximityPrompt? = nil
local ActiveNpcGui: BillboardGui? = nil
local ActiveToken = 0
local BoundPrompts: { [ProximityPrompt]: boolean } = {}
local DialogScreenGui: ScreenGui? = nil
local ResponsesFrame: Frame? = nil
local WaitingForResult = false
local ResponsesVisible = false
local BlockInventoryInputForCurrentEvent = false
local OtherUiSlid = false
local OtherUiSlideStates: { [GuiObject]: { Position: UDim2, Visible: boolean } } = {}
local OtherUiSlideTweens: { [GuiObject]: Tween } = {}
local ActiveOptions = MAIN_OPTIONS
local Show_Responses: (number) -> ()

local function Is_Tutorial_Sell_Blocked(): boolean
    if peek(FusionValues.TutorialStepReceived) ~= true then
        return false
    end

    local Step = TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep))

    return not TutorialSteps.Is_Complete(Step) and Step ~= TutorialSteps.SellOld
end

local function Is_Tutorial_Sell_Step(): boolean
    if peek(FusionValues.TutorialStepReceived) ~= true then
        return false
    end

    return TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep)) == TutorialSteps.SellOld
end

local function Get_Main_Options(): { any }
    if Is_Tutorial_Sell_Step() then
        return { MAIN_OPTIONS[2], MAIN_OPTIONS[3] }
    end

    return MAIN_OPTIONS
end

local function Play_Ui_Sound(SoundName: string)
    local UiSounds = SoundService:FindFirstChild("UI")
    local Sound = UiSounds and UiSounds:FindFirstChild(SoundName)

    if not Sound or not Sound:IsA("Sound") then
        return
    end

    Sound:Stop()
    Sound.TimePosition = 0
    Sound:Play()
end

local function Play_Typewriter_Sound(Character: string?)
    if not Character or string.match(Character, "%s") then
        return
    end

    Play_Ui_Sound("TypeWriter")
end

local function Tween(InstanceToTween: Instance, Info: TweenInfo, Properties)
    local CreatedTween = TweenService:Create(InstanceToTween, Info, Properties)
    CreatedTween:Play()

    return CreatedTween
end

local function Offset_Position(
    Position: UDim2,
    ScaleX: number,
    ScaleY: number,
    OffsetX: number?,
    OffsetY: number?
): UDim2
    return UDim2.new(
        Position.X.Scale + ScaleX,
        Position.X.Offset + (OffsetX or 0),
        Position.Y.Scale + ScaleY,
        Position.Y.Offset + (OffsetY or 0)
    )
end

local function Cancel_Other_Ui_Tween(Object: GuiObject)
    local ExistingTween = OtherUiSlideTweens[Object]

    if ExistingTween then
        ExistingTween:Cancel()
        OtherUiSlideTweens[Object] = nil
    end
end

local function Tween_Other_Ui(Object: GuiObject, Position: UDim2, HideAfterTween: boolean?)
    Cancel_Other_Ui_Tween(Object)
    Object.Visible = true

    local CreatedTween = Tween(Object, UI_SLIDE_TWEEN_INFO, { Position = Position })
    OtherUiSlideTweens[Object] = CreatedTween

    CreatedTween.Completed:Connect(function()
        if OtherUiSlideTweens[Object] ~= CreatedTween then
            return
        end

        OtherUiSlideTweens[Object] = nil

        if HideAfterTween and Object.Parent then
            Object.Visible = false
        end
    end)
end

local function Get_Main_Gui(): ScreenGui?
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Main = PlayerGui and PlayerGui:FindFirstChild("Main")

    if Main and Main:IsA("ScreenGui") then
        return Main
    end

    return nil
end

local function Add_Other_Ui_Slide_Target(
    Root: Instance,
    Path: { string },
    ScaleX: number,
    ScaleY: number,
    OffsetX: number?,
    OffsetY: number?
)
    local Current: Instance? = Root

    for _, Name in Path do
        Current = Current and Current:FindFirstChild(Name)
    end

    if not Current or not Current:IsA("GuiObject") or not Current.Visible then
        return
    end

    local Object = Current :: GuiObject

    if not OtherUiSlideStates[Object] then
        OtherUiSlideStates[Object] = {
            Position = Object.Position,
            Visible = Object.Visible,
        }
    end

    Tween_Other_Ui(Object, Offset_Position(Object.Position, ScaleX, ScaleY, OffsetX, OffsetY))
end

local function Set_Other_Ui_Slid(ShouldSlide: boolean)
    if ShouldSlide == OtherUiSlid then
        return
    end

    OtherUiSlid = ShouldSlide

    if ShouldSlide then
        local Main = Get_Main_Gui()

        if not Main then
            return
        end

        Add_Other_Ui_Slide_Target(Main, { "Hud Frame", "Buttons" }, -0.24, 0, -96, 0)
        Add_Other_Ui_Slide_Target(Main, { "Hud Frame", "2x Money" }, 0.24, 0, 96, 0)
        Add_Other_Ui_Slide_Target(Main, { "Hud Frame", "Right_Corner" }, 0.24, 0, 96, 0)
        Add_Other_Ui_Slide_Target(Main, { "Hud Frame", "Place" }, 0.18, 0.16, 96, 64)
        Add_Other_Ui_Slide_Target(Main, { "Hud Frame", "LassoStrength" }, 0, 0.16, 0, 64)
        Add_Other_Ui_Slide_Target(Main, { "Hud Frame", "ClickToPickup" }, 0, 0.16, 0, 64)
        Add_Other_Ui_Slide_Target(Main, { "Hud Frame", "MaxSquishies" }, 0, 0.16, 0, 64)
        Add_Other_Ui_Slide_Target(Main, { "Hud Frame", "SelectFeedAmount" }, 0, 0.16, 0, 64)
        Add_Other_Ui_Slide_Target(Main, { "Hud Frame", "FeedAmountButtons" }, 0, 0.16, 0, 64)
        Add_Other_Ui_Slide_Target(Main, { "Hud Frame", "EventInfo" }, 0, -0.32, 0, -96)
        Add_Other_Ui_Slide_Target(Main, { "EdgeLayer", "Plot" }, 0, -0.32, 0, -96)
        Add_Other_Ui_Slide_Target(Main, { "EdgeLayer", "Disclaimer" }, 0, 0.16, 0, 64)
        return
    end

    for Object, State in OtherUiSlideStates do
        if not Object.Parent then
            OtherUiSlideStates[Object] = nil
            continue
        end

        Tween_Other_Ui(Object, State.Position, not State.Visible)
        OtherUiSlideStates[Object] = nil
    end
end

local function Add_Text_Stroke(Parent: Instance, Thickness: number): UIStroke
    local Stroke = Instance.new("UIStroke")
    Stroke.Name = "UIStroke"
    Stroke.Thickness = Thickness
    Stroke.Color = Color3.fromRGB(0, 0, 0)
    Stroke.LineJoinMode = Enum.LineJoinMode.Round
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    Stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
    Stroke.Parent = Parent

    return Stroke
end

local function Apply_Text_Stroke_Style(Stroke: UIStroke)
    Stroke.Thickness = TEXT_STROKE_THICKNESS
    Stroke.Color = Color3.fromRGB(0, 0, 0)
    Stroke.LineJoinMode = Enum.LineJoinMode.Round
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    Stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
end

local function Get_Or_Create_Button_Border_Stroke(Button: TextButton): UIStroke
    local Existing = Button:FindFirstChild(BUTTON_BORDER_STROKE_NAME)

    if Existing and Existing:IsA("UIStroke") then
        Existing.Thickness = BUTTON_BORDER_STROKE_THICKNESS
        return Existing
    end

    local Stroke = Instance.new("UIStroke")
    Stroke.Name = BUTTON_BORDER_STROKE_NAME
    Stroke.Thickness = BUTTON_BORDER_STROKE_THICKNESS
    Stroke.Color = Color3.fromRGB(0, 0, 0)
    Stroke.LineJoinMode = Enum.LineJoinMode.Miter
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Transparency = 1
    Stroke.Parent = Button

    return Stroke
end

local function Get_Button_Stroke_Transparency(
    Stroke: UIStroke,
    TextTransparency: number,
    BackgroundTransparency: number
): number
    if Stroke.Name ~= BUTTON_BORDER_STROKE_NAME then
        return TextTransparency
    end

    return math.max(
        TextTransparency,
        math.clamp(BackgroundTransparency - BUTTON_BORDER_STROKE_TRANSPARENCY_OFFSET, 0, 1)
    )
end

local function Get_Or_Create_Screen_Gui(): (ScreenGui, Frame)
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local ScreenGui = DialogScreenGui or PlayerGui:FindFirstChild(SCREEN_GUI_NAME)

    if not ScreenGui or not ScreenGui:IsA("ScreenGui") then
        ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = SCREEN_GUI_NAME
        ScreenGui.ResetOnSpawn = true
        ScreenGui.IgnoreGuiInset = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.Parent = PlayerGui
    end

    DialogScreenGui = ScreenGui

    local Frame = ResponsesFrame or ScreenGui:FindFirstChild(RESPONSES_FRAME_NAME)

    if not Frame or not Frame:IsA("Frame") then
        Frame = Instance.new("Frame")
        Frame.Name = RESPONSES_FRAME_NAME
        Frame.Parent = ScreenGui
    end

    local Metrics = Get_Response_Metrics()

    Frame.AnchorPoint = Vector2.new(0.5, 1)
    Frame.BackgroundTransparency = 1
    Frame.BorderSizePixel = 0
    Frame.Position = UDim2.fromScale(0.5, RESPONSES_FRAME_BOTTOM_Y_SCALE)
    Frame.Size = UDim2.new(
        Metrics.WidthScale,
        0,
        0,
        (#ActiveOptions * Metrics.ButtonHeight) + ((#ActiveOptions - 1) * Metrics.ButtonPadding)
    )

    local Layout = Frame:FindFirstChildOfClass("UIListLayout")

    if not Layout then
        Layout = Instance.new("UIListLayout")
        Layout.Parent = Frame
    end

    Layout.FillDirection = Enum.FillDirection.Vertical
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    Layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, Metrics.ButtonPadding)

    ResponsesFrame = Frame

    return ScreenGui, Frame
end

local function Get_Or_Create_Button_Scale(Button: GuiObject): UIScale
    local Scale = Button:FindFirstChild("ButtonMotionScale")

    if Scale and Scale:IsA("UIScale") then
        return Scale
    end

    Scale = Instance.new("UIScale")
    Scale.Name = "ButtonMotionScale"
    Scale.Scale = 1
    Scale.Parent = Button

    return Scale
end

local function Get_Or_Create_Button_Padding(Button: TextButton): UIPadding
    local Padding = Button:FindFirstChildOfClass("UIPadding")

    if Padding then
        return Padding
    end

    Padding = Instance.new("UIPadding")
    Padding.Parent = Button

    return Padding
end

local function Get_Or_Create_Text_Size_Constraint(TextObject: TextLabel | TextButton): UITextSizeConstraint
    local Constraint = TextObject:FindFirstChildOfClass("UITextSizeConstraint")

    if Constraint then
        return Constraint
    end

    Constraint = Instance.new("UITextSizeConstraint")
    Constraint.Parent = TextObject

    return Constraint
end

local function Apply_Response_Button_Style(Button: TextButton, Index: number)
    local Metrics = Get_Response_Metrics()

    Button.LayoutOrder = Index
    Button.Active = true
    Button.AutomaticSize = Enum.AutomaticSize.None
    Button.AutoButtonColor = false
    Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Button.BorderSizePixel = 0
    Button.Font = FONT
    Button.RichText = true
    Button.Size = UDim2.new(1, 0, 0, Metrics.ButtonHeight)
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextScaled = true
    Button.TextSize = Metrics.TextMaxSize
    Button.TextTruncate = Enum.TextTruncate.None
    Button.TextXAlignment = Enum.TextXAlignment.Left
    Button.TextYAlignment = Enum.TextYAlignment.Center
    Button.TextWrapped = true

    local Padding = Get_Or_Create_Button_Padding(Button)
    local HorizontalPadding = math.max(6, math.floor(10 * Get_Dialog_Scale() + 0.5))

    Padding.PaddingLeft = UDim.new(0, HorizontalPadding)
    Padding.PaddingRight = UDim.new(0, HorizontalPadding)

    local Constraint = Get_Or_Create_Text_Size_Constraint(Button)
    Constraint.MinTextSize = Metrics.TextMinSize
    Constraint.MaxTextSize = Metrics.TextMaxSize

    Get_Or_Create_Button_Border_Stroke(Button)

    for _, Child in Button:GetChildren() do
        if Child:IsA("UIStroke") and Child.Name ~= BUTTON_BORDER_STROKE_NAME then
            Apply_Text_Stroke_Style(Child)
        end
    end
end

local function Set_Button_Transparency(Button: TextButton, TextTransparency: number, BackgroundTransparency: number)
    Button.TextTransparency = TextTransparency
    Button.BackgroundTransparency = BackgroundTransparency

    for _, Child in Button:GetChildren() do
        if Child:IsA("UIStroke") then
            Child.Transparency = Get_Button_Stroke_Transparency(Child, TextTransparency, BackgroundTransparency)
        end
    end
end

local function Tween_Button_Transparency(Button: TextButton, TextTransparency: number, BackgroundTransparency: number)
    Tween(Button, BUTTON_TWEEN_INFO, {
        BackgroundTransparency = BackgroundTransparency,
        TextTransparency = TextTransparency,
    })

    for _, Child in Button:GetChildren() do
        if Child:IsA("UIStroke") then
            Tween(Child, BUTTON_TWEEN_INFO, {
                Transparency = Get_Button_Stroke_Transparency(Child, TextTransparency, BackgroundTransparency),
            })
        end
    end
end

local function Bind_Response_Button(Button: TextButton)
    if Button:GetAttribute("SellDialogMotionBound") then
        return
    end

    Button:SetAttribute("SellDialogMotionBound", true)

    local Scale = Get_Or_Create_Button_Scale(Button)
    local Hovering = false

    Button.MouseEnter:Connect(function()
        Hovering = true
        Play_Ui_Sound("Hover")
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = 1.08 })
    end)

    Button.MouseLeave:Connect(function()
        Hovering = false
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = 1 })
    end)

    Button.MouseButton1Down:Connect(function()
        Play_Ui_Sound("Click")
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = 0.92 })
    end)

    Button.MouseButton1Up:Connect(function()
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = if Hovering then 1.08 else 1 })
    end)
end

local function Get_Response_Button(Frame: Frame, Index: number): TextButton
    local Existing = Frame:FindFirstChild(tostring(Index))

    if Existing and Existing:IsA("TextButton") then
        Apply_Response_Button_Style(Existing, Index)
        Bind_Response_Button(Existing)

        return Existing
    end

    local Button = Instance.new("TextButton")
    Button.Name = tostring(Index)
    Button.BackgroundTransparency = 1
    Button.TextTransparency = 1
    Button.Visible = false
    Button.Parent = Frame
    Apply_Response_Button_Style(Button, Index)

    Add_Text_Stroke(Button, TEXT_STROKE_THICKNESS)
    Set_Button_Transparency(Button, 1, 1)
    Bind_Response_Button(Button)

    return Button
end

local function Hide_Responses()
    local _, Frame = Get_Or_Create_Screen_Gui()
    ResponsesVisible = false

    for _, Child in Frame:GetChildren() do
        if Child:IsA("GuiButton") then
            Child.Visible = false
        end
    end
end

local function Get_Shop_Rig(ShopModel: Model): Model?
    local Rig = ShopModel:FindFirstChild("Rig")

    if Rig and Rig:IsA("Model") then
        return Rig
    end

    return nil
end

local function Get_Shop_Head(ShopModel: Model): BasePart?
    local Rig = Get_Shop_Rig(ShopModel)
    local Head = Rig and Rig:FindFirstChild("Head")

    if Head and Head:IsA("BasePart") then
        return Head
    end

    return nil
end

local function Create_Npc_Text(Name: string, Text: string, Position: UDim2, Size: UDim2): TextLabel
    local Label = Instance.new("TextLabel")
    Label.Name = Name
    Label.AnchorPoint = Vector2.new(0.5, 0.5)
    Label.BackgroundTransparency = 1
    Label.Font = FONT
    Label.Position = Position
    Label.RichText = true
    Label.Size = Size
    Label.Text = Text
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextScaled = true
    Label.TextStrokeTransparency = 1
    Label.TextWrapped = true
    Label.Visible = false

    Add_Text_Stroke(Label, TEXT_STROKE_THICKNESS)

    return Label
end

local function Get_Or_Create_Npc_Gui(ShopModel: Model): BillboardGui?
    local Head = Get_Shop_Head(ShopModel)

    if not Head then
        return nil
    end

    local Gui = Head:FindFirstChild(NPC_GUI_NAME)

    if not Gui or not Gui:IsA("BillboardGui") then
        Gui = Instance.new("BillboardGui")
        Gui.Name = NPC_GUI_NAME
        Gui:SetAttribute("SellDialogRuntime", true)
        Gui.Parent = Head
    end

    Gui.Active = true
    Gui.AlwaysOnTop = true
    Gui.Brightness = 1
    Gui.LightInfluence = 0
    Gui.MaxDistance = 50
    local DialogScale = Get_Dialog_Scale()

    Gui.Size = UDim2.new(10 * DialogScale, 0, 0.8 * DialogScale, 0)
    Gui.StudsOffset = Vector3.new(0, 2.25, 0)
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local Dialog = Gui:FindFirstChild("dialog")

    if not Dialog or not Dialog:IsA("TextLabel") then
        Dialog = Create_Npc_Text("dialog", "", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(2.5, 1))
        Dialog.TextSize = 100
        Dialog.Parent = Gui
    else
        local Stroke = Dialog:FindFirstChildOfClass("UIStroke") or Add_Text_Stroke(Dialog, TEXT_STROKE_THICKNESS)
        Apply_Text_Stroke_Style(Stroke)
    end

    for _, IdleLabelName in { "arrow", "name" } do
        local IdleLabel = Gui:FindFirstChild(IdleLabelName)

        if IdleLabel then
            IdleLabel:Destroy()
        end
    end

    return Gui
end

local function Hide_Idle_Overhead(NpcGui: BillboardGui?)
    if not NpcGui then
        return
    end

    local Name = NpcGui:FindFirstChild("name")
    local Arrow = NpcGui:FindFirstChild("arrow")

    for _, Label in { Name, Arrow } do
        if Label and Label:IsA("TextLabel") then
            Label.Visible = false
            Label.TextTransparency = 1

            local Stroke = Label:FindFirstChildOfClass("UIStroke")
            if Stroke then
                Stroke.Transparency = 1
            end
        end
    end
end

local function Tween_Fov(Value: number, TweenInfoOverride: TweenInfo?)
    if not Camera then
        return
    end

    Tween(Camera, TweenInfoOverride or FOV_IN_TWEEN_INFO, { FieldOfView = Value })
end

local function Typewrite(Label: TextLabel, Text: string, Token: number)
    Label.Visible = true
    Label.Text = ""
    Label.TextTransparency = 0
    Label.RichText = true

    local Stroke = Label:FindFirstChildOfClass("UIStroke")
    if Stroke then
        Stroke.Transparency = 0
    end

    if string.find(Text, "<", 1, true) then
        Label.Text = Text
        Play_Typewriter_Sound("x")
        return
    end

    for Index = 1, #Text do
        if ActiveToken ~= Token then
            return
        end

        Label.Text = string.sub(Text, 1, Index)
        Play_Typewriter_Sound(string.sub(Text, Index, Index))
        task.wait(TYPEWRITER_DELAY)
    end

    Label.Text = Text
end

local function Close_Dialog(Message: string?, DelaySeconds: number?)
    ActiveToken += 1
    local Token = ActiveToken
    local NpcGui = ActiveNpcGui
    local Prompt = ActivePrompt

    Hide_Responses()
    Set_Other_Ui_Slid(false)

    task.spawn(function()
        if Message and NpcGui then
            local Dialog = NpcGui:FindFirstChild("dialog")

            if Dialog and Dialog:IsA("TextLabel") then
                Typewrite(Dialog, Message, Token)
            end
        end

        local CloseDelay = if DelaySeconds ~= nil then DelaySeconds else RESULT_CLOSE_DELAY

        if CloseDelay > 0 then
            task.wait(CloseDelay)
        end

        if ActiveToken ~= Token then
            return
        end

        if NpcGui then
            local Dialog = NpcGui:FindFirstChild("dialog")

            if Dialog and Dialog:IsA("TextLabel") then
                Dialog.Visible = false
                Dialog.Text = ""
            end

            Hide_Idle_Overhead(NpcGui)
        end

        if Prompt and Prompt.Parent then
            Prompt.Enabled = true
        end

        Tween_Fov(70, FOV_OUT_TWEEN_INFO)

        ActiveShop = nil
        ActivePrompt = nil
        ActiveNpcGui = nil
        WaitingForResult = false
    end)
end

local function Select_Response(Option)
    if not ActiveShop or WaitingForResult then
        return
    end

    BlockInventoryInputForCurrentEvent = true
    task.defer(function()
        BlockInventoryInputForCurrentEvent = false
    end)

    Hide_Responses()

    if Option.NextOptions then
        WaitingForResult = true
        ActiveOptions = Option.NextOptions
        Show_Responses(ActiveToken)
        WaitingForResult = false
        return
    end

    Set_Other_Ui_Slid(false)
    WaitingForResult = true

    if Option.LocalMessage then
        Close_Dialog(Option.LocalMessage)
        return
    end

    if Option.Mode then
        Network.SellSquishies.Fire(Option.Mode)
    end
end

function Show_Responses(Token: number)
    local _, Frame = Get_Or_Create_Screen_Gui()
    ResponsesVisible = true
    Set_Other_Ui_Slid(true)

    for Index, Option in ActiveOptions do
        if ActiveToken ~= Token then
            ResponsesVisible = false
            Set_Other_Ui_Slid(false)
            return
        end

        local Button = Get_Response_Button(Frame, Index)
        Button.Text = `<font color='rgb(255,220,127)'>{Index}.)</font> [''{Option.Text}'']`
        Get_Or_Create_Button_Scale(Button).Scale = 0.98
        Set_Button_Transparency(Button, 1, 1)
        Button.Visible = true
        Tween(Get_Or_Create_Button_Scale(Button), BUTTON_TWEEN_INFO, { Scale = 1 })
        Tween_Button_Transparency(Button, 0, BUTTON_BACKGROUND_TRANSPARENCY)

        if not Button:GetAttribute("SellDialogResponseBound") then
            Button:SetAttribute("SellDialogResponseBound", true)
            Button.Activated:Connect(function()
                local ResponseIndex = tonumber(Button.Name)
                local ResponseOption = ResponseIndex and ActiveOptions[ResponseIndex]

                if ActiveShop and Button.Visible and ResponseOption then
                    Select_Response(ResponseOption)
                end
            end)
        end

        task.wait(0.05)
    end

    for Index = #ActiveOptions + 1, OPTION_COUNT do
        local Button = Get_Response_Button(Frame, Index)
        Button.Visible = false
    end
end

local function Monitor_Distance(ShopModel: Model, Token: number)
    local Rig = Get_Shop_Rig(ShopModel)
    local Root = Rig and Rig.PrimaryPart

    if not Root then
        local HumanoidRootPart = Rig and Rig:FindFirstChild("HumanoidRootPart")

        if HumanoidRootPart and HumanoidRootPart:IsA("BasePart") then
            Root = HumanoidRootPart
        end
    end

    while ActiveToken == Token and ActiveShop == ShopModel do
        local Character = LocalPlayer.Character
        local CharacterRoot = Character and Character:FindFirstChild("HumanoidRootPart")

        if Root and CharacterRoot and CharacterRoot:IsA("BasePart") then
            local Distance = (CharacterRoot.Position - Root.Position).Magnitude

            if Distance > MAX_DISTANCE then
                Close_Dialog(nil, 0)
                break
            end
        end

        task.wait()
    end
end

function SellDialogUI.Open(ShopModel: Model, Prompt: ProximityPrompt?)
    if Is_Tutorial_Sell_Blocked() then
        LocalNotifications.Push(TutorialSteps.BlockedMessage, "Error", 3)
        return
    end

    local NpcGui = Get_Or_Create_Npc_Gui(ShopModel)

    if not NpcGui then
        return
    end

    if ActivePrompt and ActivePrompt.Parent then
        ActivePrompt.Enabled = true
    end

    ActiveToken += 1
    local Token = ActiveToken

    ActiveShop = ShopModel
    ActivePrompt = Prompt
    ActiveNpcGui = NpcGui
    WaitingForResult = false
    ActiveOptions = Get_Main_Options()

    if Prompt then
        Prompt.Enabled = false
    end

    Hide_Responses()
    Hide_Idle_Overhead(NpcGui)

    local Dialog = NpcGui:FindFirstChild("dialog")

    if not Dialog or not Dialog:IsA("TextLabel") then
        return
    end

    Set_Other_Ui_Slid(true)
    Tween_Fov(65)

    task.spawn(function()
        Typewrite(Dialog, `Hello, {LocalPlayer.Name} what do you want?`, Token)

        if ActiveToken ~= Token then
            return
        end

        ActiveOptions = Get_Main_Options()
        Show_Responses(Token)
    end)

    task.spawn(Monitor_Distance, ShopModel, Token)
end

function SellDialogUI.Bind(ShopModel: Model, Prompt: ProximityPrompt)
    if BoundPrompts[Prompt] then
        return
    end

    BoundPrompts[Prompt] = true

    local NpcGui = Get_Or_Create_Npc_Gui(ShopModel)
    Hide_Idle_Overhead(NpcGui)

    Prompt.PromptShown:Connect(function()
        Hide_Idle_Overhead(NpcGui)
    end)

    Prompt.PromptHidden:Connect(function()
        Hide_Idle_Overhead(NpcGui)
    end)

    Prompt.Triggered:Connect(function(TargetPlayer: Player?)
        if TargetPlayer and TargetPlayer ~= LocalPlayer then
            return
        end

        SellDialogUI.Open(ShopModel, Prompt)
    end)
end

local function Bind_Keyboard_Responses()
    UserInputService.InputBegan:Connect(function(Input, GameProcessed)
        if GameProcessed or not ActiveShop then
            return
        end

        local KeyCodes = {
            Enum.KeyCode.One,
            Enum.KeyCode.Two,
            Enum.KeyCode.Three,
            Enum.KeyCode.Four,
            Enum.KeyCode.Five,
            Enum.KeyCode.Six,
            Enum.KeyCode.Seven,
            Enum.KeyCode.Eight,
            Enum.KeyCode.Nine,
        }

        local Index = table.find(KeyCodes, Input.KeyCode)
        local Option = Index and ActiveOptions[Index]

        if Option then
            Select_Response(Option)
        end
    end)
end

local function Handle_Server_Messages()
    for _, Message in Network.SellDialogMessage.Iter() do
        if ActiveShop then
            Close_Dialog(Message)
        end
    end
end

local function Handle_Sell_Effects()
    for _ in Network.SellEffect.Iter() do
        PlaySellEffect(LocalPlayer.Character)
    end
end

Bind_Keyboard_Responses()

function SellDialogUI.Step()
    Handle_Sell_Effects()
    Handle_Server_Messages()
end

function SellDialogUI.IsOpen(): boolean
    return ActiveShop ~= nil
end

function SellDialogUI.Close()
    if not ActiveShop then
        return
    end

    Close_Dialog(nil, 0)
end

function SellDialogUI.ShouldBlockInventoryInput(): boolean
    return ResponsesVisible or BlockInventoryInputForCurrentEvent
end

return SellDialogUI
