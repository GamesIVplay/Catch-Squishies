local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedFirst.Network)
local Phases = require(ReplicatedStorage.Shared.Phases)

local PlayCollectEffect = require(script.Parent.Parent.Modules.CollectEffect)
local LocalPlayer = Players.LocalPlayer

local PLOT_SQUISHY_FOLDER_NAME = "PlotSquishies"
local COLLECT_HIGHLIGHT_NAME = "PlotSquishyCollectHighlight"
local COLLECT_HIGHLIGHT_IN_TWEEN_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local COLLECT_HIGHLIGHT_OUT_TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function Play_Effect_For_Player(UserId: number)
    local Player = Players:GetPlayerByUserId(UserId)

    if not Player then
        return
    end

    PlayCollectEffect(Player.Character, {
        PlaySound = UserId == LocalPlayer.UserId,
    })
end

local function Find_Plot_Squishy_Model(UserId: number, ItemId: string): Model?
    local Folder = workspace:FindFirstChild(PLOT_SQUISHY_FOLDER_NAME)

    if not Folder then
        return nil
    end

    for _, Child in Folder:GetChildren() do
        if not Child:IsA("Model") then
            continue
        end

        if Child:GetAttribute("PlotSquishyOwnerUserId") == UserId and Child:GetAttribute("PlotSquishyId") == ItemId then
            return Child
        end
    end

    return nil
end

local function Play_Collect_Highlight(UserId: number, ItemId: string)
    local Model = Find_Plot_Squishy_Model(UserId, ItemId)

    if not Model then
        return
    end

    local ExistingHighlight = Model:FindFirstChild(COLLECT_HIGHLIGHT_NAME)

    if ExistingHighlight then
        ExistingHighlight:Destroy()
    end

    local Highlight = Instance.new("Highlight")
    Highlight.Name = COLLECT_HIGHLIGHT_NAME
    Highlight.FillColor = Color3.fromRGB(255, 255, 255)
    Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    Highlight.FillTransparency = 1
    Highlight.OutlineTransparency = 1
    Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    Highlight.Parent = Model

    local TweenIn = TweenService:Create(Highlight, COLLECT_HIGHLIGHT_IN_TWEEN_INFO, {
        FillTransparency = 0.18,
        OutlineTransparency = 0.05,
    })

    TweenIn:Play()
    TweenIn.Completed:Once(function()
        if not Highlight.Parent then
            return
        end

        local TweenOut = TweenService:Create(Highlight, COLLECT_HIGHLIGHT_OUT_TWEEN_INFO, {
            FillTransparency = 1,
            OutlineTransparency = 1,
        })

        TweenOut:Play()
        TweenOut.Completed:Once(function()
            Highlight:Destroy()
        end)
    end)
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = function()
        for _, Data in Network.CollectEffect.Iter() do
            Play_Effect_For_Player(Data.PlayerUserId)
            Play_Collect_Highlight(Data.PlayerUserId, Data.ItemId)
        end
    end,
    runConditions = {},
}
