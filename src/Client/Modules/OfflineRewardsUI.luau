local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Network = require(ReplicatedFirst.Network)
local peek = Fusion.peek

local FusionValues = require(script.Parent.FusionValues)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local LocalPlayer = Players.LocalPlayer

local X5_MULTIPLIER = 5
local OFFLINE_FRAME_NAME = "OfflineReward"
local CLOSE_BOUND_ATTRIBUTE = "UiFrameCloseBound"
local BUTTON_BOUND_ATTRIBUTE = "OfflineRewardButtonBound"

local MainGui: ScreenGui? = nil
local BindButtonMotion: ((GuiButton) -> ())? = nil
local IsUiBlocked: (() -> boolean)? = nil
local OpenFrame: ((string, boolean?) -> ())? = nil
local CloseFrame: (() -> ())? = nil
local OpenDailyRewards: (() -> ())? = nil
local HasDailyRewardReady: (() -> boolean)? = nil

local ReceivedOfflineReward = false
local CurrentOfflineCash = 0
local CurrentOfflineSeconds = 0
local Claiming = false
local ClaimRequestId = 0
local DailyOpenRequestId = 0
local WasClaimable = false

local OfflineRewardsUI = {}

local function Get_Offline_Frame(): GuiObject?
    if not MainGui then
        return nil
    end

    local Frames = MainGui:FindFirstChild("Frames")
    local Frame = Frames and Frames:FindFirstChild(OFFLINE_FRAME_NAME)

    return if Frame and Frame:IsA("GuiObject") then Frame else nil
end

local function Find_Text_Label(Parent: Instance?, Name: string): TextLabel?
    local Candidate = Parent and Parent:FindFirstChild(Name, true)

    return if Candidate and Candidate:IsA("TextLabel") then Candidate else nil
end

local function Get_Button(Frame: GuiObject, Name: string): GuiButton?
    local Button = Frame:FindFirstChild(Name, true)

    return if Button and Button:IsA("GuiButton") then Button else nil
end

local function Format_Cash(Amount: number): string
    return "$" .. Util.Format_Number_With_Commas(math.max(0, math.floor(Amount)))
end

local function Format_Offline_Time(Seconds: number): string
    Seconds = math.max(0, math.floor(Seconds))

    local Days = math.floor(Seconds / 86400)
    local Hours = math.floor((Seconds % 86400) / 3600)
    local Minutes = math.floor((Seconds % 3600) / 60)
    local RemainingSeconds = Seconds % 60

    if Days > 0 then
        return `{Days}d {Hours}h`
    end

    if Hours > 0 then
        return `{Hours}h {Minutes}m`
    end

    return `{Minutes}m {RemainingSeconds}s`
end

local function Is_Tutorial_Complete(): boolean
    return peek(FusionValues.TutorialStepReceived) == true
        and TutorialSteps.Is_Complete(peek(FusionValues.TutorialStep))
end

local function Can_Open_Offline_Frame(): boolean
    return CurrentOfflineCash > 0 and not Claiming and Is_Tutorial_Complete() and not (IsUiBlocked and IsUiBlocked())
end

local function Set_Text(Inst: Instance?, Text: string)
    if Inst and Inst:IsA("TextLabel") then
        Inst.Text = Text
    end
end

local function Update_Offline_Frame(Frame: GuiObject)
    local TimeLabel = Find_Text_Label(Frame, "Time")
    local ClaimButton = Get_Button(Frame, "Claim")
    local X5Button = Get_Button(Frame, "Claimx5")

    Set_Text(TimeLabel, Format_Offline_Time(CurrentOfflineSeconds))
    Set_Text(ClaimButton and ClaimButton:FindFirstChild("Amount"), Format_Cash(CurrentOfflineCash))
    Set_Text(X5Button and X5Button:FindFirstChild("Amount"), Format_Cash(CurrentOfflineCash * X5_MULTIPLIER))

    for _, Descendant in Frame:GetChildren() do
        if Descendant.Name == "Playtime Rewards" and Descendant:IsA("TextLabel") then
            Descendant.Text = "Offline Rewards"
        end
    end
end

local function Request_Claim()
    if Claiming or CurrentOfflineCash <= 0 then
        return
    end

    Claiming = true
    ClaimRequestId += 1
    local RequestId = ClaimRequestId
    Network.ClaimOfflineReward.Fire()

    if CloseFrame then
        CloseFrame()
    end

    task.delay(6, function()
        if RequestId ~= ClaimRequestId or CurrentOfflineCash <= 0 then
            return
        end

        Claiming = false
    end)
end

local function Prompt_X5()
    if Claiming or CurrentOfflineCash <= 0 then
        return
    end

    local Product = RobuxProducts.Get("OfflineRewardX5")

    if not Product or type(Product.ProductId) ~= "number" then
        return
    end

    MarketplaceService:PromptProductPurchase(LocalPlayer, Product.ProductId)
end

local function Bind_Button(Button: GuiButton?, Activated: () -> ())
    if not Button then
        return
    end

    if BindButtonMotion then
        BindButtonMotion(Button)
    end

    if Button:GetAttribute(BUTTON_BOUND_ATTRIBUTE) then
        return
    end

    Button:SetAttribute(BUTTON_BOUND_ATTRIBUTE, true)
    Button.Activated:Connect(Activated)
end

local function Bind_Frame(Frame: GuiObject)
    if CurrentOfflineCash > 0 then
        Update_Offline_Frame(Frame)
    end

    Bind_Button(Get_Button(Frame, "Claim"), Request_Claim)

    local X5Button = Get_Button(Frame, "Claimx5")
    Bind_Button(X5Button, Prompt_X5)

    local CloseButton = Get_Button(Frame, "Close Button")

    if CloseButton then
        CloseButton:SetAttribute(CLOSE_BOUND_ATTRIBUTE, true)
        Bind_Button(CloseButton, Request_Claim)
    end
end

local function Try_Open_Daily_Rewards()
    if not OpenDailyRewards or not HasDailyRewardReady or not HasDailyRewardReady() then
        return
    end

    DailyOpenRequestId += 1
    local RequestId = DailyOpenRequestId

    task.delay(0.45, function()
        if RequestId ~= DailyOpenRequestId or CurrentOfflineCash > 0 or Claiming then
            return
        end

        if OpenDailyRewards and HasDailyRewardReady and HasDailyRewardReady() then
            OpenDailyRewards()
        end
    end)
end

local function Apply_Offline_Reward(Amount: number, Seconds: number)
    local WasPreviouslyClaimable = CurrentOfflineCash > 0 or WasClaimable
    local NewOfflineCash = math.max(0, math.floor(tonumber(Amount) or 0))
    local NewOfflineSeconds = math.max(0, math.floor(tonumber(Seconds) or 0))

    ReceivedOfflineReward = true
    CurrentOfflineCash = NewOfflineCash
    CurrentOfflineSeconds = NewOfflineSeconds
    WasClaimable = CurrentOfflineCash > 0

    if CurrentOfflineCash > 0 then
        DailyOpenRequestId += 1
    end

    local Frame = Get_Offline_Frame()

    if Frame then
        if CurrentOfflineCash > 0 then
            Update_Offline_Frame(Frame)
        elseif Frame.Visible then
            if CloseFrame then
                CloseFrame()
            else
                Frame.Visible = false
            end
        end
    end

    if CurrentOfflineCash <= 0 then
        Claiming = false
        ClaimRequestId += 1

        if WasPreviouslyClaimable then
            Try_Open_Daily_Rewards()
        end
    end
end

local function Receive_Offline_Reward()
    for _, Data in Network.OfflineRewardChanged.Iter() do
        if type(Data) ~= "table" then
            Apply_Offline_Reward(0, 0)
            continue
        end

        Apply_Offline_Reward(Data.Amount, Data.Seconds)
    end
end

function OfflineRewardsUI.Is_Ready_For_Daily_Rewards(): boolean
    return ReceivedOfflineReward and CurrentOfflineCash <= 0
end

function OfflineRewardsUI.Is_Blocking_Other_Frames(): boolean
    local Frame = Get_Offline_Frame()

    return CurrentOfflineCash > 0 and Frame ~= nil and Frame.Visible
end

function OfflineRewardsUI.Initialize(
    CandidateMainGui: ScreenGui,
    CandidateBindButtonMotion: (GuiButton) -> (),
    CandidateIsUiBlocked: (() -> boolean)?,
    CandidateOpenFrame: (string, boolean?) -> (),
    CandidateCloseFrame: () -> (),
    CandidateOpenDailyRewards: () -> (),
    CandidateHasDailyRewardReady: () -> boolean
)
    MainGui = CandidateMainGui
    BindButtonMotion = CandidateBindButtonMotion
    IsUiBlocked = CandidateIsUiBlocked
    OpenFrame = CandidateOpenFrame
    CloseFrame = CandidateCloseFrame
    OpenDailyRewards = CandidateOpenDailyRewards
    HasDailyRewardReady = CandidateHasDailyRewardReady

    local Frame = Get_Offline_Frame()

    if Frame then
        Bind_Frame(Frame)
        Frame.Visible = false
    end
end

function OfflineRewardsUI.Step()
    Receive_Offline_Reward()

    local Frame = Get_Offline_Frame()

    if not Frame then
        return
    end

    Bind_Frame(Frame)

    if Can_Open_Offline_Frame() and not Frame.Visible and OpenFrame then
        OpenFrame(OFFLINE_FRAME_NAME, true)
    end
end

return table.freeze(OfflineRewardsUI)
