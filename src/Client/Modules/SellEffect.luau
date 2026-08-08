local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local EFFECT_LIFETIME = 3
local HIGHLIGHT_LIFETIME = 0.15

local MissingAssetsWarned = false

local function Get_Asset<T>(Parent: Instance?, Name: string, ClassName: string): T?
    local Asset = Parent and Parent:FindFirstChild(Name)

    if Asset and Asset:IsA(ClassName) then
        return Asset :: any
    end

    return nil
end

local function Get_Sell_VFX(): Attachment?
    local VFX = Assets:FindFirstChild("VFX")
    local Effects = Assets:FindFirstChild("Effects")

    return Get_Asset(VFX, "Sell", "Attachment") or Get_Asset(Effects, "Sell", "Attachment")
end

local function Get_Cash_Sound(): Sound?
    local Sounds = Assets:FindFirstChild("Sounds")
    local WorldSounds = Sounds and Sounds:FindFirstChild("World")
    local SoundServiceWorld = SoundService:FindFirstChild("World")

    return Get_Asset(WorldSounds, "Cash", "Sound")
        or Get_Asset(SoundServiceWorld, "Cash", "Sound")
        or Get_Asset(WorldSounds, "Collect", "Sound")
        or Get_Asset(SoundServiceWorld, "Collect", "Sound")
end

local function Get_Sell_Highlight(): Highlight?
    local Highlights = Assets:FindFirstChild("Highlights")

    return Get_Asset(Highlights, "Red", "Highlight") or Get_Asset(Highlights, "Sell", "Highlight")
end

local function Get_Root_Part(Character: Model): BasePart?
    local RootPart = Character:FindFirstChild("HumanoidRootPart")
        or Character:FindFirstChild("RootPart")
        or Character.PrimaryPart

    if RootPart and RootPart:IsA("BasePart") then
        return RootPart
    end

    return nil
end

local function Emit_Attachment(Attachment: Attachment)
    for _, Inst in Attachment:GetDescendants() do
        if not Inst:IsA("ParticleEmitter") then
            continue
        end

        local EmitCount = Inst:GetAttribute("EmitCount")

        Inst:Emit(if type(EmitCount) == "number" then EmitCount else 1)
    end
end

return function(Character: Model?)
    if not Character then
        return
    end

    local RootPart = Get_Root_Part(Character)

    if not RootPart then
        return
    end

    local CashSound = Get_Cash_Sound()

    if CashSound then
        local Sound = CashSound:Clone()
        Sound.PlayOnRemove = true
        Sound.Parent = RootPart
        Sound:Destroy()
    end

    local SellVFX = Get_Sell_VFX()

    if SellVFX then
        local Effect = SellVFX:Clone()
        Effect.Parent = RootPart
        Emit_Attachment(Effect)
        Debris:AddItem(Effect, EFFECT_LIFETIME)
    end

    local SellHighlight = Get_Sell_Highlight()

    if SellHighlight then
        local Highlight = SellHighlight:Clone()
        Highlight.Parent = Character
        Debris:AddItem(Highlight, HIGHLIGHT_LIFETIME)
    end

    if not CashSound and not SellVFX and not SellHighlight and not MissingAssetsWarned then
        MissingAssetsWarned = true
        warn("[SellEffect] No cash sound, sell VFX, or highlight assets found.")
    end
end
