local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local EFFECT_LIFETIME = 5

local MissingAssetsWarned = false
type Options = {
    PlaySound: boolean?,
    PlayVFX: boolean?,
    PlayHighlight: boolean?,
}

local function Get_Asset<T>(Parent: Instance?, Name: string, ClassName: string): T?
    local Asset = Parent and Parent:FindFirstChild(Name)

    if Asset and Asset:IsA(ClassName) then
        return Asset :: any
    end

    return nil
end

local function Find_Asset<T>(Parent: Instance?, ClassName: string, Names: { string }): T?
    for _, Name in Names do
        local Asset = Get_Asset(Parent, Name, ClassName)

        if Asset then
            return Asset
        end
    end

    return nil
end

local function Get_Robux_Purchase_VFX(): Attachment?
    local Effects = Assets:FindFirstChild("Effects")
    local VFX = Assets:FindFirstChild("VFX")
    local Names = { "Robux_Purchase", "robux_purchase", "RobuxPurchase", "Robux Purchase" }

    return Find_Asset(VFX, "Attachment", Names) or Find_Asset(Effects, "Attachment", Names)
end

local function Get_Robux_Purchase_Sound(): Sound?
    local SoundServiceWorld = SoundService:FindFirstChild("World")
    local Sounds = Assets:FindFirstChild("Sounds")
    local WorldSounds = Sounds and Sounds:FindFirstChild("World")
    local Names = { "Robux_Purchase", "robux_purchase", "RobuxPurchase", "Robux Purchase" }

    return Find_Asset(WorldSounds, "Sound", Names) or Find_Asset(SoundServiceWorld, "Sound", Names)
end

local function Get_Robux_Purchase_Highlight(): Highlight?
    local Highlights = Assets:FindFirstChild("Highlights")

    return Find_Asset(
        Highlights,
        "Highlight",
        { "Robux_Purchase", "robux_purchase", "RobuxPurchase", "Robux Purchase" }
    )
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

return function(Character: Model?, Options: Options?)
    if not Character then
        return
    end

    local RootPart = Get_Root_Part(Character)

    if not RootPart then
        return
    end

    local ShouldPlaySound = not Options or Options.PlaySound ~= false
    local ShouldPlayVFX = not Options or Options.PlayVFX ~= false
    local ShouldPlayHighlight = not Options or Options.PlayHighlight ~= false
    local PurchaseSound = if ShouldPlaySound then Get_Robux_Purchase_Sound() else nil

    if PurchaseSound then
        local Sound = PurchaseSound:Clone()
        Sound.PlayOnRemove = true
        Sound.Parent = RootPart
        Sound:Destroy()
    end

    local PurchaseHighlight = if ShouldPlayHighlight then Get_Robux_Purchase_Highlight() else nil

    if PurchaseHighlight then
        local Highlight = PurchaseHighlight:Clone()
        Highlight.Parent = Character
        Debris:AddItem(Highlight, 0.15)
    end

    local PurchaseVFX = if ShouldPlayVFX then Get_Robux_Purchase_VFX() else nil

    if PurchaseVFX then
        local Effect = PurchaseVFX:Clone()
        Effect.Parent = RootPart
        Emit_Attachment(Effect)
        Debris:AddItem(Effect, EFFECT_LIFETIME)
    end

    if not PurchaseSound and not PurchaseVFX and not PurchaseHighlight and not MissingAssetsWarned then
        MissingAssetsWarned = true
        warn("[RobuxPurchaseEffect] No robux purchase sound, VFX, or highlight assets found.")
    end
end
