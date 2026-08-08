local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Modules.Events)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local Phases = require(ReplicatedStorage.Shared.Phases)
local peek = Fusion.peek

local LocalPlayer = Players.LocalPlayer
local GENERATED_CARD_ATTRIBUTE = "GeneratedEventCard"
local ICON_HOVER_BOUND_ATTRIBUTE = "EventIconHoverBound"
local UPDATE_INTERVAL = 0.1
local ICON_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ICON_HOVER_SCALE = 1.08

local LastUpdateAt = 0

local function Format_Time(Seconds: number): string
    local TotalSeconds = math.max(0, math.ceil(Seconds))
    local Minutes = math.floor(TotalSeconds / 60)
    local RemainingSeconds = TotalSeconds % 60

    return string.format("%02d:%02d", Minutes, RemainingSeconds)
end

local function Get_Player_Gui(): PlayerGui?
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function Get_Main_Gui(): Instance?
    local PlayerGui = Get_Player_Gui()

    return PlayerGui and PlayerGui:FindFirstChild("Main")
end

local function Get_Hud_Frame(): Instance?
    local Main = Get_Main_Gui()

    return Main and Main:FindFirstChild("Hud Frame")
end

local function Get_Event_Info_Label(): TextLabel?
    local HudFrame = Get_Hud_Frame()
    local EventInfo = HudFrame and HudFrame:FindFirstChild("EventInfo")

    return if EventInfo and EventInfo:IsA("TextLabel") then EventInfo else nil
end

local function Get_Right_Corner(): Instance?
    local HudFrame = Get_Hud_Frame()

    return HudFrame and HudFrame:FindFirstChild("Right_Corner")
end

local function Get_Template(RightCorner: Instance): GuiObject?
    local Template = RightCorner:FindFirstChild("Event_Template")

    return if Template and Template:IsA("GuiObject") then Template else nil
end

local function Tween_Scale(ScaleObject: UIScale, Scale: number)
    TweenService:Create(ScaleObject, ICON_TWEEN_INFO, {
        Scale = Scale,
    }):Play()
end

local function Get_Or_Create_Scale(Object: GuiObject, Name: string): UIScale
    local Existing = Object:FindFirstChild(Name)

    if Existing and Existing:IsA("UIScale") then
        return Existing
    end

    local Scale = Instance.new("UIScale")

    Scale.Name = Name
    Scale.Scale = 1
    Scale.Parent = Object

    return Scale
end

local function Bind_Event_Icon_Hover(Icon: GuiObject?)
    if not Icon or Icon:GetAttribute(ICON_HOVER_BOUND_ATTRIBUTE) == true then
        return
    end

    Icon:SetAttribute(ICON_HOVER_BOUND_ATTRIBUTE, true)
    Icon.Active = true

    local Scale = Get_Or_Create_Scale(Icon, "HoverScale")

    Icon.MouseEnter:Connect(function()
        Tween_Scale(Scale, ICON_HOVER_SCALE)
    end)

    Icon.MouseLeave:Connect(function()
        Tween_Scale(Scale, 1)
    end)
end

local function Get_Active_Events(Now: number): { any }
    local EventState = peek(FusionValues.EventState)
    local ActiveEvents = if type(EventState) == "table" then EventState.ActiveEvents else nil
    local Result = {}

    if type(ActiveEvents) ~= "table" then
        return Result
    end

    for _, ActiveEvent in ActiveEvents do
        if type(ActiveEvent) ~= "table" then
            continue
        end

        local EventName = Events.Normalize(ActiveEvent.Name)

        if not EventName then
            continue
        end

        if type(ActiveEvent.EndsAt) ~= "number" or ActiveEvent.EndsAt <= Now then
            continue
        end

        table.insert(Result, {
            Name = EventName,
            StartedAt = if type(ActiveEvent.StartedAt) == "number" then ActiveEvent.StartedAt else 0,
            EndsAt = if type(ActiveEvent.EndsAt) == "number" then ActiveEvent.EndsAt else 0,
            Source = if type(ActiveEvent.Source) == "string" then ActiveEvent.Source else "",
        })
    end

    table.sort(Result, function(Left, Right)
        if Left.EndsAt ~= Right.EndsAt then
            return Left.EndsAt < Right.EndsAt
        end

        return Left.Name < Right.Name
    end)

    return Result
end

local function Get_Next_Event_At(Now: number): number
    local EventState = peek(FusionValues.EventState)

    if type(EventState) == "table" and type(EventState.NextEventAt) == "number" and EventState.NextEventAt > Now then
        return EventState.NextEventAt
    end

    return Events.GetNextEventAt(Now)
end

local function Find_Image_Label(Root: Instance): ImageLabel?
    local Image = Root:FindFirstChild("Image", true)

    return if Image and Image:IsA("ImageLabel") then Image else nil
end

local function Find_Time_Label(Root: Instance): TextLabel?
    local TimeLabel = Root:FindFirstChild("Time_Remaining", true)

    return if TimeLabel and TimeLabel:IsA("TextLabel") then TimeLabel else nil
end

local function Get_Card(RightCorner: Instance, Template: GuiObject, EventName: string): GuiObject
    local CardName = `Event_{EventName}`
    local Existing = RightCorner:FindFirstChild(CardName)

    if Existing and Existing:IsA("GuiObject") then
        return Existing
    end

    local Card = Template:Clone()
    Card.Name = CardName
    Card:SetAttribute(GENERATED_CARD_ATTRIBUTE, true)
    Card.Visible = true
    Card.Parent = RightCorner

    return Card
end

local function Update_Event_Info(ActiveEvents: { any }, Now: number)
    local EventInfo = Get_Event_Info_Label()

    if not EventInfo then
        return
    end

    EventInfo.Visible = true

    if #ActiveEvents <= 0 then
        EventInfo.Text = `Next Event In {Format_Time(Get_Next_Event_At(Now) - Now)}`
        return
    end

    local EndingSoonest = ActiveEvents[1]
    local DisplayName = Events.GetDisplayName(EndingSoonest.Name)
    local RemainingText = Format_Time(EndingSoonest.EndsAt - Now)

    if #ActiveEvents == 1 then
        EventInfo.Text = `{DisplayName} Event Ends In {RemainingText}`
    else
        EventInfo.Text = `{#ActiveEvents} Events Active - {DisplayName} Ends In {RemainingText}`
    end
end

local function Update_Right_Corner(ActiveEvents: { any }, Now: number)
    local RightCorner = Get_Right_Corner()

    if not RightCorner then
        return
    end

    local Template = Get_Template(RightCorner)

    if not Template then
        return
    end

    Template.Visible = false

    local Seen = {}

    for _, ActiveEvent in ActiveEvents do
        local EventName = ActiveEvent.Name
        local Card = Get_Card(RightCorner, Template, EventName)
        local ImageLabel = Find_Image_Label(Card)
        local TimeLabel = Find_Time_Label(Card)

        Seen[Card.Name] = true
        Card.Visible = true

        if ImageLabel then
            ImageLabel.Image = Events.GetImage(EventName)
            Bind_Event_Icon_Hover(ImageLabel)
        end

        if TimeLabel then
            TimeLabel.Text = Format_Time(ActiveEvent.EndsAt - Now)
        end
    end

    for _, Child in RightCorner:GetChildren() do
        if Child:GetAttribute(GENERATED_CARD_ATTRIBUTE) == true and not Seen[Child.Name] then
            Child:Destroy()
        end
    end
end

local function Update()
    local NowClock = os.clock()

    if NowClock - LastUpdateAt < UPDATE_INTERVAL then
        return
    end

    LastUpdateAt = NowClock

    local Now = workspace:GetServerTimeNow()
    local ActiveEvents = Get_Active_Events(Now)

    Update_Event_Info(ActiveEvents, Now)
    Update_Right_Corner(ActiveEvents, Now)
end

return {
    name = script.Name,
    phase = Phases.Runservice.Last,
    system = Update,
    runConditions = {},
}
