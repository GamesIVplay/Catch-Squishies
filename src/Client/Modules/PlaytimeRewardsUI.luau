local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Network = require(ReplicatedFirst.Network)
local peek = Fusion.peek

local FusionValues = require(script.Parent.FusionValues)
local PlaytimeRewards = require(ReplicatedStorage.Shared.Modules.PlaytimeRewards)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local CLAIMABLE_BUTTON_IMAGE = "rbxassetid://78335708331083"
local LOCKED_BUTTON_IMAGE = "rbxassetid://96197513588084"
local BUTTON_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ICON_HOVER_SCALE = 1.08
local EXCLAMATION_BOUNCE_INTERVAL = 2.4
local EXCLAMATION_BOUNCE_SCALE = 1.18

local MainGui: ScreenGui? = nil
local BindButtonMotion: ((GuiButton) -> ())? = nil
local IsUiBlocked: (() -> boolean)? = nil
local BoundCards: { [GuiObject]: boolean } = {}
local Exclamation: GuiObject? = nil
local LastExclamationBounce = 0
local ExclamationBounceActive = false

local function Tween(InstanceToTween: Instance, Info: TweenInfo, Properties)
    local CreatedTween = TweenService:Create(InstanceToTween, Info, Properties)
    CreatedTween:Play()

    return CreatedTween
end

local function Get_Ui_Sound(SoundName: string): Sound?
    local UiSounds = SoundService:FindFirstChild("UI")

    if not UiSounds then
        return nil
    end

    local Sound = UiSounds:FindFirstChild(SoundName)

    if Sound and Sound:IsA("Sound") then
        return Sound
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

local function Bind_Icon_Hover(Icon: GuiObject?)
    if not Icon or Icon:GetAttribute("PlaytimeIconHoverBound") then
        return
    end

    Icon:SetAttribute("PlaytimeIconHoverBound", true)
    Icon.Active = true

    local Scale = Get_Or_Create_Scale(Icon, "PlaytimeIconHoverScale")

    Icon.MouseEnter:Connect(function()
        Play_Ui_Sound("Hover")
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = ICON_HOVER_SCALE })
    end)

    Icon.MouseLeave:Connect(function()
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = 1 })
    end)
end

local function Get_Frames(): Instance?
    return MainGui and MainGui:FindFirstChild("Frames") or nil
end

local function Get_Playtime_Frame(): GuiObject?
    local Frames = Get_Frames()
    local Frame = Frames and Frames:FindFirstChild("PlaytimeRewards")

    if Frame and Frame:IsA("GuiObject") then
        return Frame
    end

    return nil
end

local function Get_Rewards_Frame(): Instance?
    local Frame = Get_Playtime_Frame()

    return Frame and Frame:FindFirstChild("Rewards") or nil
end

local function Get_Hud_Rewards_Exclamation(): GuiObject?
    if not MainGui then
        return nil
    end

    local Hud = MainGui:FindFirstChild("Hud Frame")
    local Buttons = Hud and Hud:FindFirstChild("Buttons")
    local RewardsButton = Buttons and Buttons:FindFirstChild("Rewards")
    local Candidate = RewardsButton and RewardsButton:FindFirstChild("Exclamation")

    if Candidate and Candidate:IsA("GuiObject") then
        return Candidate
    end

    return nil
end

local function Bounce_Exclamation()
    if not Exclamation or ExclamationBounceActive then
        return
    end

    ExclamationBounceActive = true

    local Scale = Get_Or_Create_Scale(Exclamation, "ExclamationBounceScale")

    Tween(Scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = EXCLAMATION_BOUNCE_SCALE,
    })

    task.delay(0.16, function()
        if Exclamation and Exclamation.Parent then
            Tween(Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Scale = 1,
            })
        end

        task.delay(0.18, function()
            ExclamationBounceActive = false
        end)
    end)
end

--[[local function Format_Cash_Reward(Amount: number): string
    return "$" .. Util.Format_Number_With_Commas(math.max(0, math.floor(Amount + 0.5)))
end]]

--[[local function Get_Reward_Title(Reward): string
    if type(Reward) ~= "table" then
        return ""
    end

    if Reward.Type == "Cash" and type(Reward.Amount) == "number" then
        return Format_Cash_Reward(Reward.Amount)
    end

    if Reward.Type == "Squishy" and type(Reward.Kind) == "string" and type(Reward.Name) == "string" then
        return `{Reward.Name} {Reward.Kind}`
    end

    return ""
end]]

local function Is_Reward_Claimed(RewardIndex: number, ClaimedRewards): boolean
    if type(ClaimedRewards) ~= "table" then
        return false
    end

    return table.find(ClaimedRewards, RewardIndex) ~= nil
end

local function Get_Playtime_Elapsed(CurrentServerTime: number?): number
    local StartedAt = peek(FusionValues.PlaytimeStart)

    if type(StartedAt) ~= "number" or StartedAt <= 0 then
        return 0
    end

    return math.max((CurrentServerTime or workspace:GetServerTimeNow()) - StartedAt, 0)
end

local function Is_Reward_Ready(RewardIndex: number, CurrentServerTime: number?, ClaimedRewards): boolean
    local Reward = PlaytimeRewards[RewardIndex]

    if type(Reward) ~= "table" or Is_Reward_Claimed(RewardIndex, ClaimedRewards) then
        return false
    end

    return Get_Playtime_Elapsed(CurrentServerTime) >= Reward.Time
end

local function Find_Text_Label(Parent: Instance?, Name: string): TextLabel?
    local Candidate = Parent and Parent:FindFirstChild(Name)

    if Candidate and Candidate:IsA("TextLabel") then
        return Candidate
    end

    return nil
end

local function Get_Button_Label(Button: Instance?): TextLabel?
    local Label = Find_Text_Label(Button, "Title")

    if Label or not Button then
        return Label
    end

    return Button:FindFirstChildWhichIsA("TextLabel", true)
end

local function Set_Reward_Visuals(Card: GuiObject, Reward)
    --local Title = Find_Text_Label(Card, "Title")
    local Icon = Card:FindFirstChild("Icon")

    --[[if Title then
        Title.Text = Get_Reward_Title(Reward)
    end]]

    if
        Icon
        and Icon:IsA("ImageLabel")
        and type(Reward) == "table"
        and Reward.Type == "Squishy"
        and type(Reward.Kind) == "string"
        and type(Reward.Name) == "string"
    then
        local SquishyData = Squishies.GetData(Reward.Kind :: any, Reward.Name)

        if SquishyData then
            Icon.Image = SquishyData.Image
        end
    end

    if Icon and Icon:IsA("GuiObject") then
        Bind_Icon_Hover(Icon)
    end
end

local function Update_Button(
    Button: ImageButton?,
    RewardIndex: number,
    Reward,
    CurrentServerTime: number,
    ClaimedRewards
)
    if not Button then
        return
    end

    local Label = Get_Button_Label(Button)
    local Claimed = Is_Reward_Claimed(RewardIndex, ClaimedRewards)
    local Elapsed = Get_Playtime_Elapsed(CurrentServerTime)
    local Ready = not Claimed and Elapsed >= Reward.Time

    if Claimed then
        Button.Image = CLAIMABLE_BUTTON_IMAGE

        if Label then
            Label.Text = "Claimed"
        end

        return
    end

    if Ready then
        Button.Image = CLAIMABLE_BUTTON_IMAGE

        if Label then
            Label.Text = "Claim"
        end

        return
    end

    Button.Image = LOCKED_BUTTON_IMAGE

    if Label then
        Label.Text = Util.Format_Seconds(math.max(math.ceil(Reward.Time - Elapsed), 0))
    end
end

local function Bind_Reward_Card(Card: GuiObject, RewardIndex: number, Reward)
    if BoundCards[Card] then
        return
    end

    BoundCards[Card] = true
    Card.LayoutOrder = RewardIndex
    Set_Reward_Visuals(Card, Reward)

    local Button = Card:FindFirstChild("Button")

    if not Button or not Button:IsA("ImageButton") then
        return
    end

    if BindButtonMotion then
        BindButtonMotion(Button)
    end

    if Button:GetAttribute("PlaytimeRewardClaimBound") then
        return
    end

    Button:SetAttribute("PlaytimeRewardClaimBound", true)
    Button.Activated:Connect(function()
        if IsUiBlocked and IsUiBlocked() then
            return
        end

        local ClaimedRewards = peek(FusionValues.ClaimedPlaytimeRewards)

        if not Is_Reward_Ready(RewardIndex, nil, ClaimedRewards) then
            return
        end

        Network.ClaimPlaytimeReward.Fire(RewardIndex)
    end)
end

local function Bind_Rewards()
    local RewardsFrame = Get_Rewards_Frame()

    if not RewardsFrame then
        return
    end

    for _, Child in RewardsFrame:GetChildren() do
        if not Child:IsA("GuiObject") then
            continue
        end

        local RewardIndex = tonumber(Child.Name)
        local Reward = if RewardIndex then PlaytimeRewards[RewardIndex] else nil

        if not RewardIndex or not Reward then
            Child.Visible = false
            continue
        end

        Child.Visible = true
        Bind_Reward_Card(Child, RewardIndex, Reward)
    end
end

local function Update_Rewards()
    local RewardsFrame = Get_Rewards_Frame()

    if not RewardsFrame then
        return
    end

    if not Exclamation or not Exclamation.Parent then
        Exclamation = Get_Hud_Rewards_Exclamation()
    end

    local CurrentServerTime = workspace:GetServerTimeNow()
    local ClaimedRewards = peek(FusionValues.ClaimedPlaytimeRewards)
    local HasReadyReward = false

    for _, Child in RewardsFrame:GetChildren() do
        if not Child:IsA("GuiObject") then
            continue
        end

        local RewardIndex = tonumber(Child.Name)
        local Reward = if RewardIndex then PlaytimeRewards[RewardIndex] else nil

        if not RewardIndex or not Reward then
            continue
        end

        Set_Reward_Visuals(Child, Reward)

        local Button = Child:FindFirstChild("Button")
        Update_Button(
            if Button and Button:IsA("ImageButton") then Button else nil,
            RewardIndex,
            Reward,
            CurrentServerTime,
            ClaimedRewards
        )

        HasReadyReward = HasReadyReward or Is_Reward_Ready(RewardIndex, CurrentServerTime, ClaimedRewards)
    end

    if Exclamation and Exclamation.Parent then
        Exclamation.Visible = HasReadyReward

        if not HasReadyReward then
            LastExclamationBounce = 0
            return
        end

        local Now = os.clock()

        if Now - LastExclamationBounce >= EXCLAMATION_BOUNCE_INTERVAL then
            LastExclamationBounce = Now
            Bounce_Exclamation()
        end
    end
end

local PlaytimeRewardsUI = {}

function PlaytimeRewardsUI.Initialize(
    CandidateMainGui: ScreenGui,
    CandidateBindButtonMotion: (GuiButton) -> (),
    CandidateIsUiBlocked: () -> boolean
)
    MainGui = CandidateMainGui
    BindButtonMotion = CandidateBindButtonMotion
    IsUiBlocked = CandidateIsUiBlocked
    Exclamation = Get_Hud_Rewards_Exclamation()

    Bind_Rewards()
    Update_Rewards()
end

function PlaytimeRewardsUI.Step()
    if not MainGui then
        return
    end

    Bind_Rewards()
    Update_Rewards()
end

return table.freeze(PlaytimeRewardsUI)
