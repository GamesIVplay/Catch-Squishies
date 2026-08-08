local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local EFFECT_LIFETIME = 5

local MissingAssetsWarned = false
type Options = {
    PlaySound: boolean?,
    PlayVFX: boolean?,
}

local function Get_Asset<T>(Parent: Instance?, Name: string, ClassName: string): T?
    local Asset = Parent and Parent:FindFirstChild(Name)

    if Asset and Asset:IsA(ClassName) then
        return Asset :: any
    end

    return nil
end

local function Get_Buy_VFX(): Attachment?
    local Effects = Assets:FindFirstChild("Effects")
    local VFX = Assets:FindFirstChild("VFX")

    return Get_Asset(Effects, "Buy", "Attachment") or Get_Asset(VFX, "Buy", "Attachment")
end

local function Get_Buy_Sound(): Sound?
    local SoundServiceWorld = SoundService:FindFirstChild("World")
    local Sounds = Assets:FindFirstChild("Sounds")
    local WorldSounds = Sounds and Sounds:FindFirstChild("World")

    return Get_Asset(SoundServiceWorld, "Buy", "Sound") or Get_Asset(WorldSounds, "Buy", "Sound")
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
    local BuySound = if ShouldPlaySound then Get_Buy_Sound() else nil

    if BuySound then
        local Sound = BuySound:Clone()
        Sound.PlayOnRemove = true
        Sound.Parent = RootPart
        Sound:Destroy()
    end

    local BuyVFX = if ShouldPlayVFX then Get_Buy_VFX() else nil

    if BuyVFX then
        local Effect = BuyVFX:Clone()
        Effect.Parent = RootPart
        Emit_Attachment(Effect)
        Debris:AddItem(Effect, EFFECT_LIFETIME)
    end

    if not BuySound and not BuyVFX and not MissingAssetsWarned then
        MissingAssetsWarned = true
        warn("[BuyEffect] No buy sound or VFX assets found.")
    end
end
