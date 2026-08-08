local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedFirst.Network)

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)

local peek = Fusion.peek
local LocalPlayer = Players.LocalPlayer

local BUTTON_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_SCALE = 1.08
local PRESS_SCALE = 0.92
local ICON_HOVER_SCALE = 1.06
local EXCLAMATION_BOUNCE_SCALE = 1.18
local CATCH_MINIGAME_ACTIVE_ATTRIBUTE = "CatchMinigameActive"
local GENERATED_CARD_ATTRIBUTE = "IndexGeneratedCard"
local TEMPLATE_ATTRIBUTE = "IndexTemplate"
local TEMPLATE_FOLDER_NAME = "RuntimeTemplates"

local Initialized = false
local Content: ScrollingFrame? = nil
local IndexExclamation: GuiObject? = nil
local Templates: { [string]: ImageLabel } = {}
local RenderedCards: { GuiObject } = {}
local LastIndexRef = nil
local LastClaimedRef = nil
local LastHasClaimableIndexReward: boolean? = nil
local ExclamationBounceActive = false

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

local function Is_Catch_Minigame_Active(): boolean
    return LocalPlayer:GetAttribute(CATCH_MINIGAME_ACTIVE_ATTRIBUTE) == true
        or LocalPlayer:GetAttribute("LassoMinigame") == true
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

local function Tween(InstanceToTween: Instance, Info: TweenInfo, Properties)
    local CreatedTween = TweenService:Create(InstanceToTween, Info, Properties)
    CreatedTween:Play()

    return CreatedTween
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
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = HOVER_SCALE })
    end)

    Button.MouseLeave:Connect(function()
        Hovering = false
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = 1 })
    end)

    Button.MouseButton1Down:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        Play_Ui_Sound("Click")
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = PRESS_SCALE })
    end)

    Button.MouseButton1Up:Connect(function()
        if Is_Catch_Minigame_Active() then
            return
        end

        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = if Hovering then HOVER_SCALE else 1 })
    end)
end

local function Bind_Icon_Hover(Icon: GuiObject, Is_Enabled: () -> boolean)
    if Icon:GetAttribute("IndexIconHoverBound") then
        return
    end

    Icon:SetAttribute("IndexIconHoverBound", true)
    Icon.Active = true

    local Scale = Get_Or_Create_Scale(Icon, "IndexIconHoverScale")

    Icon.MouseEnter:Connect(function()
        if Is_Catch_Minigame_Active() or not Is_Enabled() then
            return
        end

        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = ICON_HOVER_SCALE })
    end)

    Icon.MouseLeave:Connect(function()
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = 1 })
    end)
end

local function To_Set(List: any): { [string]: boolean }
    local Set = {}

    if type(List) ~= "table" then
        return Set
    end

    for _, Key in List do
        if type(Key) == "string" then
            Set[Key] = true
        end
    end

    return Set
end

local function Set_Text(Root: Instance, ChildName: string, Text: string, Visible: boolean?)
    local Label = Root:FindFirstChild(ChildName)

    if not Label or not Label:IsA("TextLabel") then
        return
    end

    Label.Text = Text

    if Visible ~= nil then
        Label.Visible = Visible
    end
end

local function Clear_Rendered_Cards()
    for _, Card in RenderedCards do
        if Card and Card.Parent then
            Card:Destroy()
        end
    end

    table.clear(RenderedCards)

    if not Content then
        return
    end

    for _, Child in Content:GetChildren() do
        if Child:IsA("GuiObject") and Child:GetAttribute(GENERATED_CARD_ATTRIBUTE) == true then
            Child:Destroy()
        end
    end
end

local function Get_Template(Rarity: string): ImageLabel?
    return Templates[Rarity] or Templates.Common
end

local function Create_Card(Entry, LayoutOrder: number, Discovered: boolean, Claimed: boolean): GuiObject?
    local Template = Get_Template(Entry.Rarity)

    if not Template or not Content then
        return nil
    end

    local Card = Template:Clone()
    Card.Name = `Index_{Entry.Kind}_{Entry.Name}`
    Card:SetAttribute(GENERATED_CARD_ATTRIBUTE, true)
    Card:SetAttribute(TEMPLATE_ATTRIBUTE, nil)
    Card.LayoutOrder = LayoutOrder
    Card.Visible = true

    local Claimable = Discovered and not Claimed
    local Icon = Card:FindFirstChild("Icon")

    if Icon and Icon:IsA("ImageLabel") then
        Icon.Image = Entry.Image
        Icon.ImageColor3 = if Discovered then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
        Icon.ImageTransparency = 0
        Bind_Icon_Hover(Icon, function()
            return not Claimable
        end)
    end

    Set_Text(Card, "Title", if Discovered then Entry.Name else "", Discovered)
    Set_Text(Card, "Rarity", Entry.Rarity, not Claimable)

    local ClaimButton = Card:FindFirstChild("Claim")

    if ClaimButton and ClaimButton:IsA("GuiButton") then
        ClaimButton.Visible = Claimable
        Bind_Button_Motion(ClaimButton)

        ClaimButton.Activated:Connect(function()
            if not Claimable or Is_Catch_Minigame_Active() then
                return
            end

            Network.ClaimIndexReward.Fire(Entry.Key)
        end)
    end

    Card.Parent = Content
    table.insert(RenderedCards, Card)

    return Card
end

local function Has_Claimable_Index_Reward(): boolean
    local DiscoveredSet = To_Set(peek(FusionValues.Index))
    local ClaimedSet = To_Set(peek(FusionValues.ClaimedIndexRewards))

    for Key in DiscoveredSet do
        if not ClaimedSet[Key] then
            return true
        end
    end

    return false
end

local function Bounce_Exclamation()
    if not IndexExclamation or ExclamationBounceActive then
        return
    end

    ExclamationBounceActive = true

    local Scale = Get_Or_Create_Scale(IndexExclamation, "ExclamationBounceScale")

    Tween(Scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = EXCLAMATION_BOUNCE_SCALE,
    })

    task.delay(0.16, function()
        if IndexExclamation and IndexExclamation.Parent then
            Tween(Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Scale = 1,
            })
        end

        task.delay(0.18, function()
            ExclamationBounceActive = false
        end)
    end)
end

local function Update_Index_Exclamation()
    if not IndexExclamation then
        return
    end

    local ShouldShow = Has_Claimable_Index_Reward()
    local HadClaimable = LastHasClaimableIndexReward == true

    IndexExclamation.Visible = ShouldShow
    LastHasClaimableIndexReward = ShouldShow

    if not ShouldShow then
        return
    end

    if not HadClaimable then
        Bounce_Exclamation()
    end
end

local function Render_Index()
    if not Content then
        return
    end

    Clear_Rendered_Cards()

    local DiscoveredSet = To_Set(peek(FusionValues.Index))
    local ClaimedSet = To_Set(peek(FusionValues.ClaimedIndexRewards))
    local Entries = Squishies.GetIndexEntries()

    for LayoutOrder, Entry in Entries do
        Create_Card(Entry, LayoutOrder, DiscoveredSet[Entry.Key] == true, ClaimedSet[Entry.Key] == true)
    end

    Update_Index_Exclamation()
end

local function Cache_Templates()
    if not Content then
        return
    end

    table.clear(Templates)

    local TemplateFolder = Content:FindFirstChild(TEMPLATE_FOLDER_NAME)

    if not TemplateFolder then
        TemplateFolder = Instance.new("Folder")
        TemplateFolder.Name = TEMPLATE_FOLDER_NAME
        TemplateFolder.Parent = Content
    end

    for _, Child in Content:GetChildren() do
        if not Child:IsA("ImageLabel") then
            continue
        end

        if Child:GetAttribute(GENERATED_CARD_ATTRIBUTE) == true then
            continue
        end

        Templates[Child.Name] = Child
        Child:SetAttribute(TEMPLATE_ATTRIBUTE, true)
        Child.Visible = false
        Child.Parent = TemplateFolder
    end
end

local function Initialize(): boolean
    if Initialized then
        return true
    end

    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local CandidateMainGui = PlayerGui and PlayerGui:FindFirstChild("Main")

    if not CandidateMainGui or not CandidateMainGui:IsA("ScreenGui") then
        return false
    end

    local Frames = CandidateMainGui:FindFirstChild("Frames")
    local Hud = CandidateMainGui:FindFirstChild("Hud Frame")
    local Buttons = Hud and Hud:FindFirstChild("Buttons")
    local IndexButton = Buttons and Buttons:FindFirstChild("Index")
    local IndexFrame = Frames and Frames:FindFirstChild("Index")

    if not IndexFrame then
        return false
    end

    local CandidateContent = IndexFrame:FindFirstChild("Content") or IndexFrame:FindFirstChild("Contents")

    if not CandidateContent or not CandidateContent:IsA("ScrollingFrame") then
        return false
    end

    Content = CandidateContent
    IndexExclamation = if IndexButton then IndexButton:FindFirstChild("Exclamation") :: GuiObject? else nil

    if IndexExclamation and IndexExclamation:IsA("GuiObject") then
        IndexExclamation.Visible = false
    else
        IndexExclamation = nil
    end

    Cache_Templates()
    Render_Index()

    LastIndexRef = peek(FusionValues.Index)
    LastClaimedRef = peek(FusionValues.ClaimedIndexRewards)
    Initialized = true

    return true
end

local function Update()
    if not Initialize() then
        return
    end

    local CurrentIndexRef = peek(FusionValues.Index)
    local CurrentClaimedRef = peek(FusionValues.ClaimedIndexRewards)

    if CurrentIndexRef == LastIndexRef and CurrentClaimedRef == LastClaimedRef then
        Update_Index_Exclamation()
        return
    end

    LastIndexRef = CurrentIndexRef
    LastClaimedRef = CurrentClaimedRef
    Render_Index()
    Update_Index_Exclamation()
end

return {
    name = script.Name,
    phase = Phases.Runservice.Last,
    system = Update,
    runConditions = {},
}
