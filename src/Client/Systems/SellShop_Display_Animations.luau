local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Phases = require(ReplicatedStorage.Shared.Phases)

type DisplayAnimationCache = {
    Animation: Animation,
    Track: AnimationTrack?,
}

local AnimationsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations")
local Plots: Instance? = workspace:FindFirstChild("Plots")
local BoundDisplays: { [Model]: DisplayAnimationCache } = {}
local ScanAccumulator = 0

local SCAN_INTERVAL = 0.5
local DISPLAY_ANIMATION_FADE_TIME = 0.15
local DISPLAY_ANIMATION_SPEED = 1
local SHOP_MODEL_NAMES = {
    FoodShop = true,
    LassoShop = true,
    SellShop = true,
}
local MODEL_ANIMATION_OVERRIDES = {
    Tripple = "Slime Idle",
    Mushroom = "Dumpling Idle",
}

local function Get_Plots(): Instance?
    if Plots and Plots.Parent then
        return Plots
    end

    Plots = workspace:FindFirstChild("Plots")

    return Plots
end

local function Find_Animation(AnimationName: string): Animation?
    local DirectAnimation = AnimationsFolder:FindFirstChild(AnimationName)

    if DirectAnimation and DirectAnimation:IsA("Animation") then
        return DirectAnimation
    end

    for _, Child in AnimationsFolder:GetChildren() do
        if Child:IsA("Animation") and string.lower(Child.Name) == string.lower(AnimationName) then
            return Child
        end
    end

    return nil
end

local function Get_Display_Animation(Model: Model): Animation?
    return Find_Animation(MODEL_ANIMATION_OVERRIDES[Model.Name] or "Idle")
end

local function Get_Animator(Model: Model): Animator?
    local Humanoid = Model:FindFirstChildOfClass("Humanoid")

    if Humanoid then
        local Animator = Humanoid:FindFirstChildOfClass("Animator")

        if not Animator then
            Animator = Instance.new("Animator")
            Animator.Parent = Humanoid
        end

        return Animator
    end

    local AnimationController = Model:FindFirstChildOfClass("AnimationController")

    if not AnimationController then
        return nil
    end

    local Animator = AnimationController:FindFirstChildOfClass("Animator")

    if not Animator then
        Animator = Instance.new("Animator")
        Animator.Parent = AnimationController
    end

    return Animator
end

local function Is_Display_Rig(Model: Model): boolean
    return Model:FindFirstChildOfClass("Humanoid") ~= nil or Model:FindFirstChildOfClass("AnimationController") ~= nil
end

local function Stop_Display_Animation(Model: Model)
    local Cache = BoundDisplays[Model]

    if not Cache then
        return
    end

    if Cache.Track then
        Cache.Track:Stop(DISPLAY_ANIMATION_FADE_TIME)
    end

    BoundDisplays[Model] = nil
end

local function Bind_Display_Animation(Model: Model, DisplayAnimation: Animation)
    local ExistingCache = BoundDisplays[Model]

    if ExistingCache and ExistingCache.Animation == DisplayAnimation then
        return
    end

    if ExistingCache then
        Stop_Display_Animation(Model)
    end

    local Animator = Get_Animator(Model)

    if not Animator then
        return
    end

    for _, Track in Animator:GetPlayingAnimationTracks() do
        if Track.Animation and Track.Animation ~= DisplayAnimation then
            Track:Stop(DISPLAY_ANIMATION_FADE_TIME)
        end
    end

    local Track = Animator:LoadAnimation(DisplayAnimation)
    Track.Looped = true
    Track:Play(DISPLAY_ANIMATION_FADE_TIME)
    Track:AdjustSpeed(DISPLAY_ANIMATION_SPEED)

    BoundDisplays[Model] = {
        Animation = DisplayAnimation,
        Track = Track,
    }
end

local function Bind_Shop_Display_Animations()
    local PlotsFolder = Get_Plots()

    if not PlotsFolder then
        return
    end

    for _, Plot in PlotsFolder:GetChildren() do
        for ShopModelName in SHOP_MODEL_NAMES do
            local ShopModel = Plot:FindFirstChild(ShopModelName)

            if not ShopModel then
                continue
            end

            for _, Descendant in ShopModel:GetDescendants() do
                if Descendant:IsA("Model") and Is_Display_Rig(Descendant) then
                    local DisplayAnimation = Get_Display_Animation(Descendant)

                    if DisplayAnimation then
                        Bind_Display_Animation(Descendant, DisplayAnimation)
                    end
                end
            end
        end
    end
end

local function Cleanup_Display_Animations()
    for Model in BoundDisplays do
        if Model.Parent then
            continue
        end

        Stop_Display_Animation(Model)
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function(_, DeltaTime: number?)
        ScanAccumulator += DeltaTime or 1 / 60

        if ScanAccumulator < SCAN_INTERVAL then
            return
        end

        ScanAccumulator = 0

        Bind_Shop_Display_Animations()
        Cleanup_Display_Animations()
    end,
}
