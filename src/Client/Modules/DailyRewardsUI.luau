local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Network = require(ReplicatedFirst.Network)
local peek = Fusion.peek

local DailyRewards = require(ReplicatedStorage.Shared.Modules.DailyRewards)
local FusionValues = require(script.Parent.FusionValues)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local LocalPlayer = Players.LocalPlayer
local CLAIMABLE_BUTTON_IMAGE = "rbxassetid://71800159074296"
local LOCKED_BUTTON_IMAGE = "rbxassetid://78634676283957"
local BUTTON_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ICON_HOVER_SCALE = 1.08
local CLAIM_ALL_BOUND_ATTRIBUTE = "DailyRewardsClaimAllProductBound"

local MainGui: ScreenGui? = nil
local BindButtonMotion: ((GuiButton) -> ())? = nil
local IsUiBlocked: (() -> boolean)? = nil
local BoundCards: { [GuiObject]: boolean } = {}

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
    if not Icon or Icon:GetAttribute("DailyRewardIconHoverBound") then
        return
    end

    Icon:SetAttribute("DailyRewardIconHoverBound", true)
    Icon.Active = true

    local Scale = Get_Or_Create_Scale(Icon, "DailyRewardIconHoverScale")

    Icon.MouseEnter:Connect(function()
        Play_Ui_Sound("Hover")
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = ICON_HOVER_SCALE })
    end)

    Icon.MouseLeave:Connect(function()
        Tween(Scale, BUTTON_TWEEN_INFO, { Scale = 1 })
    end)
end

local function Get_Daily_Rewards_Frame(): GuiObject?
    if not MainGui then
        return nil
    end

    local Frames = MainGui:FindFirstChild("Frames")
    local Frame = Frames and Frames:FindFirstChild("DailyRewards")

    if Frame and Frame:IsA("GuiObject") then
        return Frame
    end

    return nil
end

local function Bind_Claim_All(Frame: GuiObject)
    local ClaimAll = Frame:FindFirstChild("Claim All")

    if ClaimAll and ClaimAll:IsA("GuiButton") and BindButtonMotion then
        BindButtonMotion(ClaimAll)
    end

    if not ClaimAll or not ClaimAll:IsA("GuiButton") or ClaimAll:GetAttribute(CLAIM_ALL_BOUND_ATTRIBUTE) then
        return
    end

    ClaimAll:SetAttribute(CLAIM_ALL_BOUND_ATTRIBUTE, true)
    ClaimAll.Activated:Connect(function()
        if IsUiBlocked and IsUiBlocked() then
            return
        end

        local Product = RobuxProducts.Get("ClaimAllDailyRewards")

        if Product and type(Product.ProductId) == "number" then
            MarketplaceService:PromptProductPurchase(LocalPlayer, Product.ProductId)
        end
    end)
end

local function Get_Reward_Cards(Frame: GuiObject): { GuiObject }
    local RewardsFrame = Frame:FindFirstChild("Rewards")
    local Cards = {}

    if not RewardsFrame then
        return Cards
    end

    for _, RewardCard in RewardsFrame:GetChildren() do
        if not RewardCard:IsA("GuiObject") then
            continue
        end

        table.insert(Cards, RewardCard)
    end

    table.sort(Cards, function(Left: GuiObject, Right: GuiObject): boolean
        if Left.LayoutOrder == Right.LayoutOrder then
            return Left.Name < Right.Name
        end

        return Left.LayoutOrder < Right.LayoutOrder
    end)

    return Cards
end

local function Is_Reward_Claimed(RewardIndex: number, ClaimedRewards): boolean
    if type(ClaimedRewards) ~= "table" then
        return false
    end

    return table.find(ClaimedRewards, RewardIndex) ~= nil
end

local function Get_Next_Daily_Reward_Index(ClaimedRewards): number?
    for RewardIndex = 1, #DailyRewards do
        if not Is_Reward_Claimed(RewardIndex, ClaimedRewards) then
            return RewardIndex
        end
    end

    return nil
end

local function Get_Reward_Remaining(Reward, LastClaimAt: number, CurrentServerTime: number): number
    if type(LastClaimAt) ~= "number" or LastClaimAt <= 0 then
        return 0
    end

    return math.max(math.ceil((Reward.Time or 0) - math.max(CurrentServerTime - LastClaimAt, 0)), 0)
end

local function Is_Reward_Ready(RewardIndex: number, CurrentServerTime: number?, ClaimedRewards): boolean
    if Is_Reward_Claimed(RewardIndex, ClaimedRewards) then
        return false
    end

    if Get_Next_Daily_Reward_Index(ClaimedRewards) ~= RewardIndex then
        return false
    end

    local Reward = DailyRewards[RewardIndex]

    if not Reward then
        return false
    end

    return Get_Reward_Remaining(
        Reward,
        peek(FusionValues.DailyStart),
        CurrentServerTime or workspace:GetServerTimeNow()
    ) <= 0
end

local function Find_Text_Label(Parent: Instance?, Names: { string }): TextLabel?
    if not Parent then
        return nil
    end

    for _, Name in Names do
        local Candidate = Parent:FindFirstChild(Name)

        if Candidate and Candidate:IsA("TextLabel") then
            return Candidate
        end
    end

    return nil
end

local function Get_Button_Label(Button: Instance?): TextLabel?
    return Find_Text_Label(Button, { "Title", "Claimed", "Locked" })
        or (if Button then Button:FindFirstChildWhichIsA("TextLabel", true) else nil)
end

--[[local function Get_Reward_Title(Reward): string
    if type(Reward) ~= "table" then
        return ""
    end

    if Reward.Type == "Squishy" and type(Reward.Kind) == "string" and type(Reward.Name) == "string" then
        return `{Reward.Name} {Reward.Kind}`
    end

    return ""
end]]

--[[local function Set_Reward_Title(Card: GuiObject, Reward)
    local Title = Find_Text_Label(Card, { "Title", "TItle" })

    if Title then
        Title.Text = Get_Reward_Title(Reward)
    end
end]]

local function Set_Button_State(
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
    local NextIndex = Get_Next_Daily_Reward_Index(ClaimedRewards)
    local IsNextReward = NextIndex == RewardIndex
    local Remaining = if IsNextReward
        then Get_Reward_Remaining(Reward, peek(FusionValues.DailyStart), CurrentServerTime)
        else 0

    if Claimed then
        Button.Image = CLAIMABLE_BUTTON_IMAGE

        if Label then
            Label.Text = "Claimed"
        end

        return
    end

    if not IsNextReward then
        Button.Image = LOCKED_BUTTON_IMAGE

        if Label then
            Label.Text = "Locked"
        end

        return
    end

    if Remaining <= 0 then
        Button.Image = CLAIMABLE_BUTTON_IMAGE

        if Label then
            Label.Text = "Claim"
        end

        return
    end

    Button.Image = LOCKED_BUTTON_IMAGE

    if Label then
        Label.Text = Util.Format_Seconds(Remaining)
    end
end

local function Bind_Reward_Card(Card: GuiObject, RewardIndex: number)
    if BoundCards[Card] then
        return
    end

    BoundCards[Card] = true
    Card.LayoutOrder = RewardIndex

    local Icon = Card:FindFirstChild("Icon")

    if Icon and Icon:IsA("GuiObject") then
        Bind_Icon_Hover(Icon)
    end

    local Button = Card:FindFirstChild("Button")

    if not Button or not Button:IsA("ImageButton") then
        return
    end

    if BindButtonMotion then
        BindButtonMotion(Button)
    end

    if Button:GetAttribute("DailyRewardClaimBound") then
        return
    end

    Button:SetAttribute("DailyRewardClaimBound", true)
    Button.Activated:Connect(function()
        if IsUiBlocked and IsUiBlocked() then
            return
        end

        local ClaimedRewards = peek(FusionValues.ClaimedDailyRewards)

        if not Is_Reward_Ready(RewardIndex, nil, ClaimedRewards) then
            return
        end

        Network.ClaimDailyReward.Fire(RewardIndex)
    end)
end

local function Update_Rewards(Frame: GuiObject)
    local CurrentServerTime = workspace:GetServerTimeNow()
    local ClaimedRewards = peek(FusionValues.ClaimedDailyRewards)
    local Cards = Get_Reward_Cards(Frame)

    for RewardIndex, Card in Cards do
        local Reward = DailyRewards[RewardIndex]

        if not Reward then
            Card.Visible = false
            continue
        end

        Card.Visible = true
        Bind_Reward_Card(Card, RewardIndex)
        --Set_Reward_Title(Card, Reward)

        local Button = Card:FindFirstChild("Button")
        Set_Button_State(
            if Button and Button:IsA("ImageButton") then Button else nil,
            RewardIndex,
            Reward,
            CurrentServerTime,
            ClaimedRewards
        )
    end
end

local DailyRewardsUI = {}

function DailyRewardsUI.Has_Ready_Reward(): boolean
    local ClaimedRewards = peek(FusionValues.ClaimedDailyRewards)
    local NextRewardIndex = Get_Next_Daily_Reward_Index(ClaimedRewards)

    return NextRewardIndex ~= nil and Is_Reward_Ready(NextRewardIndex, nil, ClaimedRewards)
end

function DailyRewardsUI.Initialize(
    CandidateMainGui: ScreenGui,
    CandidateBindButtonMotion: (GuiButton) -> (),
    CandidateIsUiBlocked: (() -> boolean)?
)
    MainGui = CandidateMainGui
    BindButtonMotion = CandidateBindButtonMotion
    IsUiBlocked = CandidateIsUiBlocked

    DailyRewardsUI.Step()
end

function DailyRewardsUI.Step()
    local Frame = Get_Daily_Rewards_Frame()

    if not Frame then
        return
    end

    Bind_Claim_All(Frame)
    Update_Rewards(Frame)
end

return table.freeze(DailyRewardsUI)
