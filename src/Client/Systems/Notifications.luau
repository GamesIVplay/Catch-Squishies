local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local LocalNotifications = require(script.Parent.Parent.Modules.LocalNotifications)
local Network = require(ReplicatedFirst.Network)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local LocalPlayer = Players.LocalPlayer
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Gradients = Assets:FindFirstChild("Gradients")

type NotificationData = {
    Text: string,
    Duration: number?,
    Type: "Success" | "Info" | "Warning" | "Error" | "Reward" | "Announcement",
    Gradient: string?,
}

local DEFAULT_NOTIFICATION_DURATION = 4
local MAX_VISIBLE_NOTIFICATIONS = 5
local NOTIFICATION_POP_IN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local NOTIFICATION_POP_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local NOTIFICATION_COUNT = 0

local ActiveNotifications: { [string]: {
    Frame: Frame,
    Count: number,
    Type: string,
    Token: any,
} } = {}

local PendingNotifications: { NotificationData } = {}

local function Get_Notification_Key(Text: string, Type: string): string
    return `{Type}\0{Text}`
end

local function Get_Notification_Sound(): Sound?
    local UISounds = SoundService:FindFirstChild("UI")
    local Sound = UISounds and UISounds:FindFirstChild("Notification")

    if Sound and Sound:IsA("Sound") then
        return Sound
    end

    return nil
end

local function Get_Or_Create_Scale(Frame: Frame): UIScale
    local Scale = Frame:FindFirstChildOfClass("UIScale")

    if Scale then
        return Scale
    end

    Scale = Instance.new("UIScale")
    Scale.Scale = 1
    Scale.Parent = Frame

    return Scale
end

local function Play_Notification_Pop(Frame: Frame)
    local Scale = Get_Or_Create_Scale(Frame)

    Scale.Scale = 0
    TweenService:Create(Scale, NOTIFICATION_POP_IN, { Scale = 1 }):Play()
end

local function Play_Notification_Remove(Frame: Frame, Callback: () -> ())
    local Scale = Get_Or_Create_Scale(Frame)
    local Tween = TweenService:Create(Scale, NOTIFICATION_POP_OUT, { Scale = 0 })

    Tween.Completed:Connect(Callback)
    Tween:Play()
end

local function Play_Notification_Sound()
    local Sound = Get_Notification_Sound()

    if not Sound then
        return
    end

    Sound:Stop()
    Sound.TimePosition = 0
    Sound:Play()
end

local function Remove_Active_By_Frame(Frame: Frame)
    for Key, Notification in ActiveNotifications do
        if Notification.Frame == Frame then
            ActiveNotifications[Key] = nil
            return
        end
    end
end

local function Destroy_Notification_Frame(Frame: Frame)
    if not Frame.Parent then
        return
    end

    Play_Notification_Remove(Frame, function()
        if Frame.Parent then
            Frame:Destroy()
        end
    end)
end

local function Handle_Server_Notifications()
    for _, Notification in Network.Notification.Iter() do
        table.insert(PendingNotifications, {
            Text = Notification.Text,
            Duration = Notification.Duration,
            Type = Notification.Type,
        })
    end
end

local function Handle_Local_Notifications()
    for _, Notification in LocalNotifications.Pop_All() do
        table.insert(PendingNotifications, Notification)
    end
end

local function Schedule_Cleanup(Key: string, Type: string, Duration: number, Frame: Frame)
    local Active = ActiveNotifications[Key]

    if not Active then
        return
    end

    local Token = {}
    Active.Token = Token

    task.delay(Duration, function()
        if
            ActiveNotifications[Key]
            and ActiveNotifications[Key].Token == Token
            and ActiveNotifications[Key].Type == Type
            and ActiveNotifications[Key].Frame == Frame
        then
            ActiveNotifications[Key] = nil
            Destroy_Notification_Frame(Frame)
        end
    end)
end

local function Get_Notifications_Frame(): Frame?
    local PlayerGui = LocalPlayer.PlayerGui
    local ScreenGui = PlayerGui:FindFirstChild("Notifications") :: ScreenGui?

    if not ScreenGui then
        return nil
    end

    local Notifications = ScreenGui:FindFirstChild("Notifications") :: Frame?

    if not Notifications then
        return nil
    end

    return Notifications
end

local function Get_Visible_Notifications(Notifications: Frame): { Frame }
    local Visible = {}

    for _, Child in Notifications:GetChildren() do
        if Child:IsA("Frame") and Child.Name ~= "Template" and Child.Name ~= "Announcement_Template" then
            table.insert(Visible, Child)
        end
    end

    table.sort(Visible, function(A, B)
        return A.LayoutOrder < B.LayoutOrder
    end)

    return Visible
end

local function Trim_Visible_Notifications(Notifications: Frame)
    local Visible = Get_Visible_Notifications(Notifications)

    if #Visible < MAX_VISIBLE_NOTIFICATIONS then
        return
    end

    Remove_Active_By_Frame(Visible[1])
    Destroy_Notification_Frame(Visible[1])
end

local function Clear_Existing_Gradients(TextLabel: TextLabel)
    for _, Child in TextLabel:GetChildren() do
        if Child:IsA("UIGradient") then
            Child:Destroy()
        end
    end
end

local function Apply_Notification_Gradient(TextLabel: TextLabel, GradientName: string?, Type: string)
    if not Gradients then
        return
    end

    local Notification_Gradients = Gradients:FindFirstChild("Notification")
    local Gradient = GradientName and Gradients:FindFirstChild(GradientName)
        or Notification_Gradients and Notification_Gradients:FindFirstChild(Type)

    if not Gradient or not Gradient:IsA("UIGradient") then
        return
    end

    Clear_Existing_Gradients(TextLabel)
    Gradient:Clone().Parent = TextLabel
end

local function Get_Notification_Text_Label(Notification: Frame): TextLabel?
    local TextLabel = Notification:FindFirstChildOfClass("TextLabel")

    if TextLabel then
        return TextLabel
    end

    return Notification:FindFirstChildWhichIsA("TextLabel", true)
end

local function Pop_Pending_Notification(): NotificationData?
    if #PendingNotifications <= 0 then
        return nil
    end

    return table.remove(PendingNotifications, 1)
end

local function Create_Notifications()
    local Notifications = Get_Notifications_Frame()

    if not Notifications then
        return
    end

    local Template = Notifications:FindFirstChild("Template") :: Frame?

    if not Template then
        return
    end

    Template.Visible = false

    local Announcement_Template = Notifications:FindFirstChild("Announcement_Template") :: Frame?

    while true do
        local NotificationData = Pop_Pending_Notification()

        if not NotificationData then
            break
        end

        local Text = NotificationData.Text
        local Type = NotificationData.Type
        local Duration = NotificationData.Duration or DEFAULT_NOTIFICATION_DURATION
        local Key = Get_Notification_Key(Text, Type)
        local Existing = ActiveNotifications[Key]

        if Existing and Existing.Frame:IsDescendantOf(Notifications) and Existing.Type == Type then
            Existing.Count += 1

            NOTIFICATION_COUNT += 1
            Existing.Frame.LayoutOrder = NOTIFICATION_COUNT

            local TextLabel = Get_Notification_Text_Label(Existing.Frame)
            if TextLabel then
                TextLabel.Text = string.format("%s (x%s)", Text, Util.Abbreviate_Number(Existing.Count, 1))
            end

            Play_Notification_Pop(Existing.Frame)
            Play_Notification_Sound()

            Schedule_Cleanup(Key, Existing.Type, Duration, Existing.Frame)
            continue
        end

        Trim_Visible_Notifications(Notifications)

        local Notification = if Type == "Announcement" and Announcement_Template
            then Announcement_Template:Clone()
            else Template:Clone()
        Notification.Name = Text
        Notification.Visible = true

        NOTIFICATION_COUNT += 1
        Notification.LayoutOrder = NOTIFICATION_COUNT

        local TextLabel = Get_Notification_Text_Label(Notification)

        if TextLabel then
            TextLabel.Text = Text
            Apply_Notification_Gradient(TextLabel, NotificationData.Gradient, Type)
        end

        Notification.Parent = Notifications

        Play_Notification_Pop(Notification)
        Play_Notification_Sound()

        ActiveNotifications[Key] = {
            Frame = Notification,
            Count = 1,
            Type = Type,
            Token = nil,
        }

        Schedule_Cleanup(Key, Type, Duration, Notification)
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        Handle_Server_Notifications()
        Handle_Local_Notifications()
        Create_Notifications()
    end,
    runConditions = {},
}
