local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Phases = require(ReplicatedStorage.Shared.Phases)

local Plots: Instance? = workspace:FindFirstChild("Plots")

local REVEAL_RISE_OFFSET = Vector3.new(0, -3, 0)
local REVEAL_TWEEN_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local BoundZones: { [Model]: boolean } = {}
local LastRevealSerials: { [Model]: number } = setmetatable({}, { __mode = "k" })
local ActivePartTweens: { [BasePart]: Tween } = setmetatable({}, { __mode = "k" })

local function Get_Plots(): Instance?
    if Plots and Plots.Parent then
        return Plots
    end

    Plots = workspace:FindFirstChild("Plots")

    return Plots
end

local function Get_Target_Transparency(Part: BasePart): number
    local OriginalTransparency = Part:GetAttribute("PlotZoneOriginalTransparency")

    if type(OriginalTransparency) == "number" then
        return OriginalTransparency
    end

    return Part.Transparency
end

local function Stop_Part_Tween(Part: BasePart)
    local Tween = ActivePartTweens[Part]

    if not Tween then
        return
    end

    Tween:Cancel()
    ActivePartTweens[Part] = nil
end

local function Stop_Zone_Tweens(Zone: Model)
    for _, Descendant in Zone:GetDescendants() do
        if not Descendant:IsA("BasePart") then
            continue
        end

        Stop_Part_Tween(Descendant)
    end
end

local function Animate_Part_Reveal(Part: BasePart)
    Stop_Part_Tween(Part)

    local TargetCFrame = Part.CFrame
    local TargetTransparency = Get_Target_Transparency(Part)

    Part.CFrame = TargetCFrame + REVEAL_RISE_OFFSET
    Part.Transparency = 1

    local Tween = TweenService:Create(Part, REVEAL_TWEEN_INFO, {
        CFrame = TargetCFrame,
        Transparency = TargetTransparency,
    })

    ActivePartTweens[Part] = Tween
    Tween.Completed:Connect(function()
        if ActivePartTweens[Part] ~= Tween then
            return
        end

        ActivePartTweens[Part] = nil
        Part.CFrame = TargetCFrame
        Part.Transparency = TargetTransparency
    end)
    Tween:Play()
end

local function Animate_Zone_Reveal(Zone: Model)
    for _, Descendant in Zone:GetDescendants() do
        if not Descendant:IsA("BasePart") then
            continue
        end

        Animate_Part_Reveal(Descendant)
    end
end

local function Handle_Zone_State_Changed(Zone: Model)
    if Zone:GetAttribute("Unlocked") ~= true then
        Stop_Zone_Tweens(Zone)
        return
    end

    local RevealSerial = Zone:GetAttribute("RevealSerial")

    if type(RevealSerial) ~= "number" then
        return
    end

    if LastRevealSerials[Zone] == RevealSerial then
        return
    end

    LastRevealSerials[Zone] = RevealSerial
    Animate_Zone_Reveal(Zone)
end

local function Bind_Zone(Zone: Model)
    if BoundZones[Zone] then
        return
    end

    BoundZones[Zone] = true
    LastRevealSerials[Zone] = if type(Zone:GetAttribute("RevealSerial")) == "number"
        then Zone:GetAttribute("RevealSerial") :: number
        else 0

    Zone:GetAttributeChangedSignal("RevealSerial"):Connect(function()
        Handle_Zone_State_Changed(Zone)
    end)

    Zone:GetAttributeChangedSignal("Unlocked"):Connect(function()
        Handle_Zone_State_Changed(Zone)
    end)
end

local function Bind_Plot(Plot: Instance)
    local Zones = Plot:FindFirstChild("Zones")

    if not Zones then
        return
    end

    for _, Zone in Zones:GetChildren() do
        if Zone:IsA("Model") then
            Bind_Zone(Zone)
        end
    end
end

local function Bind_Plots()
    local CurrentPlots = Get_Plots()

    if not CurrentPlots then
        return
    end

    for _, Plot in CurrentPlots:GetChildren() do
        Bind_Plot(Plot)
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        Bind_Plots()
    end,
}
