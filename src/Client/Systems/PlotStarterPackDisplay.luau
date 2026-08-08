local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Phases = require(ReplicatedStorage.Shared.Phases)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

type AnimationState = {
    Track: AnimationTrack?,
}

local LocalPlayer = Players.LocalPlayer
local Product = RobuxProducts.Get("StarterPack")
local Plots: Instance? = workspace:FindFirstChild("Plots")
local BoundTouchParts: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local AnimationStates: { [Model]: AnimationState } = setmetatable({}, { __mode = "k" }) :: any
local LastPromptAt = 0
local LastScanAt = -math.huge
local PriceText: string? = nil
local PriceFetchStarted = false

local STARTER_PACK_MODEL_NAME = "StarterPack"
local SCAN_INTERVAL = 0.5
local PROMPT_COOLDOWN_SECONDS = 2
local ROBUX_ICON = utf8.char(0xE002)
local IDLE_ANIMATION_NAME = "Slime Idle"
local FALLBACK_IDLE_ANIMATION_NAME = "Idle"
local ANIMATION_FADE_TIME = 0.15
local ANIMATION_SPEED = 1

local function Get_Plots(): Instance?
    if Plots and Plots.Parent then
        return Plots
    end

    Plots = workspace:FindFirstChild("Plots")

    return Plots
end

local function Get_Local_Player_Plot(): Instance?
    local PlotsFolder = Get_Plots()

    if not PlotsFolder then
        return nil
    end

    for _, Plot in PlotsFolder:GetChildren() do
        if Plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return Plot
        end
    end

    local ExpectedTitle = `{LocalPlayer.Name}'s Plot`

    for _, Plot in PlotsFolder:GetChildren() do
        local OwnerSign = Plot:FindFirstChild("OwnerSign")
        local Title = OwnerSign and OwnerSign:FindFirstChild("Title", true)

        if Title and Title:IsA("TextLabel") and Title.Text == ExpectedTitle then
            return Plot
        end
    end

    return nil
end

local function Set_Model_Visible(Model: Model, Visible: boolean)
    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Descendant.LocalTransparencyModifier = if Visible then 0 else 1
        elseif Descendant:IsA("BillboardGui") or Descendant:IsA("SurfaceGui") or Descendant:IsA("ProximityPrompt") then
            Descendant.Enabled = Visible
        end
    end
end

local function Get_Idle_Animation(): Animation?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Animations = Assets and Assets:FindFirstChild("Animations")

    if not Animations then
        return nil
    end

    local Animation = Animations:FindFirstChild(IDLE_ANIMATION_NAME)
        or Animations:FindFirstChild(FALLBACK_IDLE_ANIMATION_NAME)

    return if Animation and Animation:IsA("Animation") then Animation else nil
end

local function Get_Animator(Model: Model): Animator?
    local AnimationController = Model:FindFirstChildOfClass("AnimationController")

    if not AnimationController then
        return nil
    end

    local Animator = AnimationController:FindFirstChildOfClass("Animator")

    if Animator then
        return Animator
    end

    Animator = Instance.new("Animator")
    Animator.Parent = AnimationController

    return Animator
end

local function Stop_Idle(Model: Model)
    local State = AnimationStates[Model]

    if not State then
        return
    end

    if State.Track then
        State.Track:Stop(ANIMATION_FADE_TIME)
    end

    AnimationStates[Model] = nil
end

local function Play_Idle(Model: Model)
    local State = AnimationStates[Model]

    if State and State.Track and State.Track.IsPlaying then
        return
    end

    local Animator = Get_Animator(Model)
    local Animation = Get_Idle_Animation()

    if not Animator or not Animation then
        return
    end

    local Success, Track = pcall(function()
        return Animator:LoadAnimation(Animation)
    end)

    if not Success or not Track then
        return
    end

    Track.Looped = true
    Track:Play(ANIMATION_FADE_TIME)
    Track:AdjustSpeed(ANIMATION_SPEED)

    AnimationStates[Model] = {
        Track = Track,
    }
end

local function Update_Price_Text(Model: Model)
    if not PriceText then
        return
    end

    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("TextLabel") and Descendant.Name == "Price" and Descendant.Text ~= PriceText then
            Descendant.Text = PriceText
        end
    end
end

local function Fetch_Price_Text()
    if PriceFetchStarted or not Product or type(Product.ProductId) ~= "number" then
        return
    end

    PriceFetchStarted = true

    task.spawn(function()
        local ProductInfo = Util.Get_Product_Info(Product.ProductId)
        local Price = if type(ProductInfo) == "table" then ProductInfo.PriceInRobux else nil

        if type(Price) == "number" then
            PriceText = ROBUX_ICON .. tostring(Price)
        end
    end)
end

local function Prompt_Starter_Pack()
    if not Product or Product.Kind ~= "Product" or type(Product.ProductId) ~= "number" then
        return
    end

    local Now = os.clock()

    if Now - LastPromptAt < PROMPT_COOLDOWN_SECONDS then
        return
    end

    LastPromptAt = Now
    MarketplaceService:PromptProductPurchase(LocalPlayer, Product.ProductId)
end

local function Bind_Touch(Model: Model, IsLocalPlot: boolean)
    if not IsLocalPlot then
        return
    end

    for _, Descendant in Model:GetDescendants() do
        if not Descendant:IsA("BasePart") or BoundTouchParts[Descendant] then
            continue
        end

        BoundTouchParts[Descendant] = true
        Descendant.Touched:Connect(function(Hit: BasePart)
            local Character = LocalPlayer.Character

            if Character and Hit:IsDescendantOf(Character) and Model.Parent == Get_Local_Player_Plot() then
                Prompt_Starter_Pack()
            end
        end)
    end
end

local function Sync_Starter_Packs()
    local PlotsFolder = Get_Plots()
    local LocalPlot = Get_Local_Player_Plot()

    if not PlotsFolder then
        return
    end

    Fetch_Price_Text()

    for _, Plot in PlotsFolder:GetChildren() do
        local Model = Plot:FindFirstChild(STARTER_PACK_MODEL_NAME)

        if not Model or not Model:IsA("Model") then
            continue
        end

        local IsLocalPlot = Plot == LocalPlot

        Set_Model_Visible(Model, IsLocalPlot)
        Update_Price_Text(Model)
        Bind_Touch(Model, IsLocalPlot)

        if IsLocalPlot then
            Play_Idle(Model)
        else
            Stop_Idle(Model)
        end
    end
end

local function Cleanup_Animations()
    for Model in AnimationStates do
        if not Model.Parent then
            Stop_Idle(Model)
        end
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        local Now = os.clock()

        if Now - LastScanAt < SCAN_INTERVAL then
            return
        end

        LastScanAt = Now
        Sync_Starter_Packs()
        Cleanup_Animations()
    end,
    runConditions = {},
}
