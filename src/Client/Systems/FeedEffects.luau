local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedFirst.Network)
local Phases = require(ReplicatedStorage.Shared.Phases)

local ModelVFX = require(script.Parent.Parent.Modules.ModelVFX)

local LocalPlayer = Players.LocalPlayer
local PLOT_SQUISHY_FOLDER_NAME = "PlotSquishies"
local EFFECT_LIFETIME = 3
local SOUND_LIFETIME_FALLBACK = 3
local BOUNCE_SCALE_MULTIPLIER = 1.12
local DUPLICATE_EFFECT_WINDOW = 0.2
local BOUNCE_UP_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BOUNCE_DOWN_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local MissingAssetWarned = false
local MissingSoundWarned = false
local BounceSerialByModel = setmetatable({}, { __mode = "k" }) :: { [Model]: number }
local LastEffectAtByKey = {} :: { [string]: number }

local function Get_Feed_Effect(): Attachment?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Effects = Assets and Assets:FindFirstChild("Effects")
    local Feed = Effects and Effects:FindFirstChild("Feed")

    return if Feed and Feed:IsA("Attachment") then Feed else nil
end

local function Get_Click_Sound(): Sound?
    local UiSounds = SoundService:FindFirstChild("UI")
    local Click = UiSounds and UiSounds:FindFirstChild("Click")

    return if Click and Click:IsA("Sound") then Click else nil
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

local function Play_Feed_Sound(Model: Model)
    local ClickSound = Get_Click_Sound()

    if not ClickSound then
        if not MissingSoundWarned then
            MissingSoundWarned = true
            warn("[FeedEffects] SoundService.UI.Click is missing.")
        end

        return
    end

    local TargetAttachment = ModelVFX.FindTargetAttachment(Model)

    if not TargetAttachment then
        return
    end

    local Sound = ClickSound:Clone()

    Sound.Name = "FeedClick"
    Sound.Parent = TargetAttachment
    Sound.TimePosition = 0
    Sound:Play()
    Debris:AddItem(Sound, math.max(SOUND_LIFETIME_FALLBACK, Sound.TimeLength + 0.5))
end

local function Get_Model_Scale(Model: Model): number
    local AttributeScale = Model:GetAttribute("PlotSquishyBaseScale")

    if type(AttributeScale) == "number" and AttributeScale > 0 then
        return AttributeScale
    end

    local Success, Scale = pcall(function()
        return Model:GetScale()
    end)

    return if Success and type(Scale) == "number" and Scale > 0 then Scale else 1
end

local function Scale_Model(Model: Model, Scale: number)
    pcall(function()
        Model:ScaleTo(Scale)
    end)
end

local function Play_Model_Bounce(Model: Model)
    if not Model.Parent then
        return
    end

    local BaseScale = Get_Model_Scale(Model)

    if BaseScale <= 0 then
        return
    end

    local Serial = (BounceSerialByModel[Model] or 0) + 1
    BounceSerialByModel[Model] = Serial

    local ScaleValue = Instance.new("NumberValue")
    local Connection: RBXScriptConnection? = nil

    ScaleValue.Value = BaseScale
    Connection = ScaleValue.Changed:Connect(function(Value)
        if BounceSerialByModel[Model] ~= Serial or not Model.Parent then
            return
        end

        Scale_Model(Model, Value)
    end)

    local function Cleanup()
        if Connection then
            Connection:Disconnect()
            Connection = nil
        end

        ScaleValue:Destroy()
    end

    local UpTween = TweenService:Create(ScaleValue, BOUNCE_UP_INFO, {
        Value = BaseScale * BOUNCE_SCALE_MULTIPLIER,
    })
    local DownTween = TweenService:Create(ScaleValue, BOUNCE_DOWN_INFO, {
        Value = BaseScale,
    })

    UpTween.Completed:Connect(function(PlaybackState)
        if
            BounceSerialByModel[Model] ~= Serial
            or not Model.Parent
            or PlaybackState ~= Enum.PlaybackState.Completed
        then
            Cleanup()
            return
        end

        DownTween:Play()
    end)

    DownTween.Completed:Connect(function()
        if BounceSerialByModel[Model] == Serial and Model.Parent then
            Scale_Model(Model, BaseScale)
        end

        Cleanup()
    end)

    UpTween:Play()
end

local function Play_Feed_Effect(UserId: number, ItemId: string)
    local Key = `{UserId}:{ItemId}`
    local Now = os.clock()
    local LastEffectAt = LastEffectAtByKey[Key]

    if LastEffectAt and Now - LastEffectAt <= DUPLICATE_EFFECT_WINDOW then
        return
    end

    LastEffectAtByKey[Key] = Now

    local Model = Find_Plot_Squishy_Model(UserId, ItemId)

    if not Model then
        return
    end

    local FeedEffect = Get_Feed_Effect()

    if not FeedEffect then
        if not MissingAssetWarned then
            MissingAssetWarned = true
            warn("[FeedEffects] ReplicatedStorage.Assets.Effects.Feed is missing.")
        end

        return
    end

    if not ModelVFX.PlayAttachmentContents(Model, FeedEffect, "FeedEffect", EFFECT_LIFETIME) then
        return
    end

    Play_Model_Bounce(Model)

    if UserId == LocalPlayer.UserId then
        Play_Feed_Sound(Model)
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = function()
        for _, Data in Network.FeedEffect.Iter() do
            Play_Feed_Effect(Data.PlayerUserId, Data.ItemId)
        end
    end,
    runConditions = {},
}
