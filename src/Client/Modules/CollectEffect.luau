local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local EFFECT_LIFETIME = 3
local HIGHLIGHT_LIFETIME = 0.15

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

local function Get_Collect_VFX(): Attachment?
    local VFX = Assets:FindFirstChild("VFX")
    local Effects = Assets:FindFirstChild("Effects")

    return Get_Asset(VFX, "Collect", "Attachment") or Get_Asset(Effects, "Collect", "Attachment")
end

local function Get_Collect_Sound(): Sound?
    local Sounds = Assets:FindFirstChild("Sounds")
    local WorldSounds = Sounds and Sounds:FindFirstChild("World")
    local SoundServiceWorld = SoundService:FindFirstChild("World")

    return Get_Asset(WorldSounds, "Cash", "Sound")
        or Get_Asset(SoundServiceWorld, "Cash", "Sound")
        or Get_Asset(WorldSounds, "Collect", "Sound")
        or Get_Asset(SoundServiceWorld, "Collect", "Sound")
end

local function Get_Collect_Highlight(): Highlight?
    local Highlights = Assets:FindFirstChild("Highlights")

    return Get_Asset(Highlights, "Green", "Highlight")
        or Get_Asset(Highlights, "Collect", "Highlight")
        or Get_Asset(Highlights, "Buy", "Highlight")
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
    local CollectSound = if ShouldPlaySound then Get_Collect_Sound() else nil

    if CollectSound then
        local Sound = CollectSound:Clone()
        Sound.PlayOnRemove = true
        Sound.Parent = RootPart
        Sound:Destroy()
    end

    local CollectVFX = if ShouldPlayVFX then Get_Collect_VFX() else nil

    if CollectVFX then
        local Effect = CollectVFX:Clone()
        Effect.Parent = RootPart
        Emit_Attachment(Effect)
        Debris:AddItem(Effect, EFFECT_LIFETIME)
    end

    local CollectHighlight = if ShouldPlayHighlight then Get_Collect_Highlight() else nil

    if CollectHighlight then
        local Highlight = CollectHighlight:Clone()
        Highlight.Parent = Character
        Debris:AddItem(Highlight, HIGHLIGHT_LIFETIME)
    end

    if not CollectSound and not CollectVFX and not CollectHighlight and not MissingAssetsWarned then
        MissingAssetsWarned = true
        warn("[CollectEffect] No collect sound, VFX, or highlight assets found.")
    end
end
