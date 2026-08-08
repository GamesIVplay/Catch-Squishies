local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)

local LassoRig = {}

LassoRig.ModelName = "ClientHeldLasso"

local RIGHT_HAND_PART_OFFSET = CFrame.new(0, -0.149724, 0)

local PART_TOP_C0 = CFrame.new(
    1.052666,
    0.033665,
    -0.63913,
    -0.00103,
    0.000625,
    0.999999,
    0,
    0.999999,
    -0.000625,
    -0.999999,
    0,
    -0.00103
)

local PART_TOP_C1 = CFrame.new(1.100008, -0.000006, -0.300011)

local LEFT_HAND_BOTTOM_OFFSET =
    CFrame.new(0.336723, -0.148689, -0.078094, 0, -0.112113, -0.993696, 1, 0, 0, 0, 0.993695, -0.112113)

local R6_RIGHT_ARM_TOP_OFFSET = CFrame.new(0, -1, -0.55) * CFrame.Angles(math.rad(90), 0, math.rad(90))
local R6_LEFT_ARM_BOTTOM_OFFSET = CFrame.new(0, -1, -0.15) * CFrame.Angles(math.rad(90), 0, 0)

local function Get_Assets_Folder(): Folder?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")

    if Assets and Assets:IsA("Folder") then
        return Assets
    end

    return nil
end

function LassoRig.Find_Template(LassoName: string): Model?
    local LassoData = Lassos.Get(LassoName)
    local Assets = Get_Assets_Folder()
    local LassoModels = Assets and Assets:FindFirstChild("Lassos")

    if not LassoData or not LassoModels then
        return nil
    end

    local Template = LassoModels:FindFirstChild(LassoData.ModelName)

    if Template and Template:IsA("Model") then
        return Template
    end

    return nil
end

function LassoRig.Find_Character_Part(Character: Model, R15Name: string, R6Name: string): BasePart?
    local Part = Character:FindFirstChild(R15Name)

    if Part and Part:IsA("BasePart") then
        return Part
    end

    Part = Character:FindFirstChild(R6Name)

    if Part and Part:IsA("BasePart") then
        return Part
    end

    return nil
end

function LassoRig.Prepare_Lasso_Part(Part: BasePart)
    Part.Anchored = false
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.Massless = true
end

function LassoRig.Prepare_Lasso_Model(Model: Model)
    for _, Descendant in Model:GetDescendants() do
        if Descendant:IsA("BasePart") then
            LassoRig.Prepare_Lasso_Part(Descendant)
        end
    end
end

function LassoRig.Set_Effect_Enabled(InstanceToUpdate: Instance, Enabled: boolean)
    if
        InstanceToUpdate:IsA("ParticleEmitter")
        or InstanceToUpdate:IsA("Beam")
        or InstanceToUpdate:IsA("Trail")
        or InstanceToUpdate:IsA("Highlight")
        or InstanceToUpdate:IsA("Fire")
        or InstanceToUpdate:IsA("Smoke")
        or InstanceToUpdate:IsA("Sparkles")
        or InstanceToUpdate:IsA("PointLight")
        or InstanceToUpdate:IsA("SpotLight")
        or InstanceToUpdate:IsA("SurfaceLight")
        or InstanceToUpdate:IsA("BillboardGui")
        or InstanceToUpdate:IsA("SurfaceGui")
    then
        pcall(function()
            (InstanceToUpdate :: any).Enabled = Enabled
        end)
    end
end

function LassoRig.Set_Visual_Instance_Visible(Root: Instance?, Visible: boolean, VisibleTransparency: number?)
    if not Root then
        return
    end

    if Root:IsA("BasePart") then
        Root.Transparency = if Visible then VisibleTransparency or 0 else 1
    end

    for _, Descendant in Root:GetDescendants() do
        if Descendant:IsA("BasePart") then
            Descendant.Transparency = if Visible then VisibleTransparency or 0 else 1
        else
            LassoRig.Set_Effect_Enabled(Descendant, Visible)
        end
    end
end

function LassoRig.Capture_Visual_State(Root: Instance?): any
    local State = {
        BaseParts = {},
        Effects = {},
    }

    if not Root then
        return State
    end

    local function Capture_Instance(InstanceToCapture: Instance)
        if InstanceToCapture:IsA("BasePart") then
            table.insert(State.BaseParts, {
                Instance = InstanceToCapture,
                Transparency = InstanceToCapture.Transparency,
            })

            return
        end

        if
            InstanceToCapture:IsA("ParticleEmitter")
            or InstanceToCapture:IsA("Beam")
            or InstanceToCapture:IsA("Trail")
            or InstanceToCapture:IsA("Highlight")
            or InstanceToCapture:IsA("Fire")
            or InstanceToCapture:IsA("Smoke")
            or InstanceToCapture:IsA("Sparkles")
            or InstanceToCapture:IsA("PointLight")
            or InstanceToCapture:IsA("SpotLight")
            or InstanceToCapture:IsA("SurfaceLight")
            or InstanceToCapture:IsA("BillboardGui")
            or InstanceToCapture:IsA("SurfaceGui")
        then
            local Success, Enabled = pcall(function()
                return (InstanceToCapture :: any).Enabled
            end)

            if Success and type(Enabled) == "boolean" then
                table.insert(State.Effects, {
                    Instance = InstanceToCapture,
                    Enabled = Enabled,
                })
            end
        end
    end

    Capture_Instance(Root)

    for _, Descendant in Root:GetDescendants() do
        Capture_Instance(Descendant)
    end

    return State
end

function LassoRig.Set_Visual_State_Visible(State: any, Visible: boolean)
    if type(State) ~= "table" then
        return
    end

    for _, BasePartState in State.BaseParts or {} do
        local Part = BasePartState.Instance

        if Part and Part.Parent and Part:IsA("BasePart") then
            Part.Transparency = if Visible then BasePartState.Transparency else 1
        end
    end

    for _, EffectState in State.Effects or {} do
        local Effect = EffectState.Instance

        if Effect and Effect.Parent then
            LassoRig.Set_Effect_Enabled(Effect, Visible and EffectState.Enabled or false)
        end
    end
end

function LassoRig.Restore_Visual_State(State: any)
    LassoRig.Set_Visual_State_Visible(State, true)
end

local function Create_Rig_Handle(Parent: Instance): Part
    local Handle = Instance.new("Part")

    Handle.Name = "Part"
    Handle.Size = Vector3.new(0.5, 0.5, 0.5)
    Handle.Transparency = 1
    LassoRig.Prepare_Lasso_Part(Handle)
    Handle.Parent = Parent

    return Handle
end

local function Attach_Motor(
    Part0: BasePart,
    Part1: BasePart,
    C0: CFrame,
    C1: CFrame,
    JointName: string,
    Parent: Instance
): Motor6D
    LassoRig.Prepare_Lasso_Part(Part1)
    Part1.CFrame = Part0.CFrame * C0 * C1:Inverse()

    local Joint = Instance.new("Motor6D")

    Joint.Name = JointName
    Joint.Part0 = Part0
    Joint.Part1 = Part1
    Joint.C0 = C0
    Joint.C1 = C1
    Joint.Parent = Parent

    return Joint
end

local function Attach_Weld(
    Part0: BasePart,
    Part1: BasePart,
    C0: CFrame,
    C1: CFrame,
    JointName: string,
    Parent: Instance
): Weld
    LassoRig.Prepare_Lasso_Part(Part1)
    Part1.CFrame = Part0.CFrame * C0 * C1:Inverse()

    local Joint = Instance.new("Weld")

    Joint.Name = JointName
    Joint.Part0 = Part0
    Joint.Part1 = Part1
    Joint.C0 = C0
    Joint.C1 = C1
    Joint.Parent = Parent

    return Joint
end

function LassoRig.Create(Character: Model, LassoName: string, ModelName: string?): Model?
    local Template = LassoRig.Find_Template(LassoName)

    if not Template then
        return nil
    end

    local RightHand = LassoRig.Find_Character_Part(Character, "RightHand", "Right Arm")
    local LeftHand = LassoRig.Find_Character_Part(Character, "LeftHand", "Left Arm")

    if not RightHand then
        return nil
    end

    local Clone = Template:Clone()

    Clone.Name = ModelName or LassoRig.ModelName
    Clone:SetAttribute("LassoName", LassoName)
    Clone.Parent = Character
    LassoRig.Prepare_Lasso_Model(Clone)

    local Top = Clone:FindFirstChild("Top")
    local Bottom = Clone:FindFirstChild("Bottom")

    if not Top or not Top:IsA("BasePart") or not Bottom or not Bottom:IsA("BasePart") then
        Clone:Destroy()
        return nil
    end

    if RightHand.Name == "RightHand" then
        local Handle = Create_Rig_Handle(Clone)

        Attach_Motor(RightHand, Handle, RIGHT_HAND_PART_OFFSET, CFrame.identity, "RightHandPartLasso", Handle)
        Attach_Motor(Handle, Top, PART_TOP_C0, PART_TOP_C1, "PartTopLasso", Top)
    else
        Attach_Motor(RightHand, Top, R6_RIGHT_ARM_TOP_OFFSET, CFrame.identity, "RightArmTopLasso", Top)
    end

    if LeftHand then
        if LeftHand.Name == "LeftHand" then
            Attach_Weld(LeftHand, Bottom, LEFT_HAND_BOTTOM_OFFSET, CFrame.identity, "LeftHandBottomLasso", Bottom)
        else
            Attach_Weld(LeftHand, Bottom, R6_LEFT_ARM_BOTTOM_OFFSET, CFrame.identity, "LeftArmBottomLasso", Bottom)
        end
    else
        Attach_Weld(RightHand, Bottom, RIGHT_HAND_PART_OFFSET, CFrame.identity, "RightHandBottomLasso", Bottom)
    end

    return Clone
end

function LassoRig.Get_Model(Character: Model?, ModelName: string?): Model?
    if not Character then
        return nil
    end

    local Model = Character:FindFirstChild(ModelName or LassoRig.ModelName)

    if Model and Model:IsA("Model") then
        return Model
    end

    return nil
end

function LassoRig.Get_Top(Model: Model?): BasePart?
    local Top = Model and Model:FindFirstChild("Top", true)

    if Top and Top:IsA("BasePart") then
        return Top
    end

    return nil
end

function LassoRig.Get_Bottom(Model: Model?): BasePart?
    local Bottom = Model and Model:FindFirstChild("Bottom", true)

    if Bottom and Bottom:IsA("BasePart") then
        return Bottom
    end

    return nil
end

function LassoRig.Get_Rope_Attachment(Part: BasePart?): Attachment?
    if not Part then
        return nil
    end

    local Attachment = Part:FindFirstChild("RopeAttachment") or Part:FindFirstChildWhichIsA("Attachment")

    if Attachment and Attachment:IsA("Attachment") then
        return Attachment
    end

    return nil
end

function LassoRig.Get_Rope(Model: Model?): RopeConstraint?
    if not Model then
        return nil
    end

    local Bottom = LassoRig.Get_Bottom(Model)
    local BottomAttachment = LassoRig.Get_Rope_Attachment(Bottom)
    local Rope = BottomAttachment and BottomAttachment:FindFirstChildWhichIsA("RopeConstraint")

    if Rope then
        return Rope
    end

    return Model:FindFirstChildWhichIsA("RopeConstraint", true)
end

return LassoRig
