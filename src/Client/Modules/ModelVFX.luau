local Debris = game:GetService("Debris")

local ModelVFX = {}

local BASE_MODEL_SIZE = 4
local MIN_VFX_SCALE = 0.65
local MAX_VFX_SCALE = 3
local DEFAULT_EFFECT_LIFETIME = 3
local EFFECT_ATTRIBUTE = "ModelVFX"
local EFFECT_SOURCE_ATTRIBUTE = "ModelVFXSource"

local DEFAULT_ATTACHMENT_PRIORITY = {
    "FeedAttachment",
    "EventMutationAttachment",
    "MutationAttachment",
    "Attachment",
    "SquishyOverheadAttachment",
    "WalkingSquishyOverheadAttachment",
    "FeedPromptAttachment",
    "PromptAttachment",
}

local function Scale_Number_Sequence(Sequence: NumberSequence, Scale: number): NumberSequence
    local Keypoints = {}

    for _, Keypoint in Sequence.Keypoints do
        table.insert(
            Keypoints,
            NumberSequenceKeypoint.new(Keypoint.Time, Keypoint.Value * Scale, Keypoint.Envelope * Scale)
        )
    end

    return NumberSequence.new(Keypoints)
end

local function Scale_Number_Range(Range: NumberRange, Scale: number): NumberRange
    return NumberRange.new(Range.Min * Scale, Range.Max * Scale)
end

local function Get_Target_Base_Part(Model: Model): BasePart?
    if Model.PrimaryPart and Model.PrimaryPart:IsA("BasePart") then
        return Model.PrimaryPart
    end

    return Model:FindFirstChildWhichIsA("BasePart", true)
end

function ModelVFX.FindTargetAttachment(Model: Model, PriorityNames: { string }?): Attachment?
    for _, Name in PriorityNames or DEFAULT_ATTACHMENT_PRIORITY do
        local Attachment = Model:FindFirstChild(Name, true)

        if Attachment and Attachment:IsA("Attachment") then
            return Attachment
        end
    end

    local Attachment = Model:FindFirstChildWhichIsA("Attachment", true)

    if Attachment then
        return Attachment
    end

    local TargetPart = Get_Target_Base_Part(Model)

    if not TargetPart then
        return nil
    end

    Attachment = Instance.new("Attachment")
    Attachment.Name = "ModelVFXAttachment"
    Attachment.Parent = TargetPart

    return Attachment
end

function ModelVFX.GetModelVfxScale(Model: Model): number
    local _, Size = Model:GetBoundingBox()
    local Largest = math.max(Size.X, Size.Y, Size.Z)

    if Largest <= 0 or Largest ~= Largest then
        return 1
    end

    return math.clamp(Largest / BASE_MODEL_SIZE, MIN_VFX_SCALE, MAX_VFX_SCALE)
end

local function Scale_Vfx_Single(InstanceObject: Instance, Scale: number)
    if InstanceObject:IsA("ParticleEmitter") then
        InstanceObject.Size = Scale_Number_Sequence(InstanceObject.Size, Scale)
        InstanceObject.Speed = Scale_Number_Range(InstanceObject.Speed, math.sqrt(Scale))
    elseif InstanceObject:IsA("Beam") then
        InstanceObject.Width0 *= Scale
        InstanceObject.Width1 *= Scale
        InstanceObject.WidthScale = Scale_Number_Sequence(InstanceObject.WidthScale, Scale)
    elseif InstanceObject:IsA("Trail") then
        InstanceObject.WidthScale = Scale_Number_Sequence(InstanceObject.WidthScale, Scale)
    elseif InstanceObject:IsA("Attachment") then
        InstanceObject.Position *= Scale
    elseif InstanceObject:IsA("BasePart") then
        InstanceObject.Size *= Scale
    elseif InstanceObject:IsA("SpecialMesh") then
        InstanceObject.Scale *= Scale
    elseif InstanceObject:IsA("Fire") or InstanceObject:IsA("Smoke") then
        local Effect = InstanceObject :: any

        Effect.Size = Effect.Size * Scale
    elseif
        InstanceObject:IsA("PointLight")
        or InstanceObject:IsA("SpotLight")
        or InstanceObject:IsA("SurfaceLight")
    then
        local Light = InstanceObject :: any

        Light.Range = Light.Range * Scale
    end
end

function ModelVFX.ScaleInstance(InstanceObject: Instance, Scale: number)
    Scale_Vfx_Single(InstanceObject, Scale)

    for _, Descendant in InstanceObject:GetDescendants() do
        Scale_Vfx_Single(Descendant, Scale)
    end
end

local function Enable_Vfx_Single(InstanceObject: Instance)
    if
        InstanceObject:IsA("ParticleEmitter")
        or InstanceObject:IsA("Trail")
        or InstanceObject:IsA("Beam")
        or InstanceObject:IsA("Light")
    then
        InstanceObject.Enabled = true
    end
end

function ModelVFX.Enable(InstanceObject: Instance)
    Enable_Vfx_Single(InstanceObject)

    for _, Descendant in InstanceObject:GetDescendants() do
        Enable_Vfx_Single(Descendant)
    end
end

local function Emit_Vfx_Single(InstanceObject: Instance)
    if not InstanceObject:IsA("ParticleEmitter") then
        return
    end

    local EmitCount = InstanceObject:GetAttribute("EmitCount")

    InstanceObject:Emit(if type(EmitCount) == "number" then EmitCount else 1)
end

function ModelVFX.Emit(InstanceObject: Instance)
    Emit_Vfx_Single(InstanceObject)

    for _, Descendant in InstanceObject:GetDescendants() do
        Emit_Vfx_Single(Descendant)
    end
end

function ModelVFX.PlayAttachmentContents(
    Model: Model,
    TemplateAttachment: Attachment,
    EffectName: string?,
    Lifetime: number?
): boolean
    local TargetAttachment = ModelVFX.FindTargetAttachment(Model)

    if not TargetAttachment then
        return false
    end

    local Scale = ModelVFX.GetModelVfxScale(Model)
    local DidClone = false
    local NamePrefix = if type(EffectName) == "string" and EffectName ~= "" then EffectName else TemplateAttachment.Name

    for _, Child in TemplateAttachment:GetChildren() do
        local Clone = Child:Clone()
        Clone.Name = `{NamePrefix}_{Child.Name}`
        Clone:SetAttribute(EFFECT_ATTRIBUTE, true)
        Clone:SetAttribute(EFFECT_SOURCE_ATTRIBUTE, TemplateAttachment.Name)
        ModelVFX.ScaleInstance(Clone, Scale)
        Clone.Parent = TargetAttachment
        ModelVFX.Emit(Clone)
        Debris:AddItem(Clone, Lifetime or DEFAULT_EFFECT_LIFETIME)
        DidClone = true
    end

    return DidClone
end

return table.freeze(ModelVFX)
