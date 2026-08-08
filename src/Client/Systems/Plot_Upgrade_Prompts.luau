local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedFirst.Network)
local Phases = require(ReplicatedStorage.Shared.Phases)

local LocalPlayer = Players.LocalPlayer
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local BillboardsFolder = AssetsFolder:WaitForChild("Billboards")
local UpArrowTemplate = BillboardsFolder:WaitForChild("UpArrow") :: BillboardGui
local Plots = workspace:WaitForChild("Plots")

local PROMPT_FOLDER_NAME = "ZoneUpgradePrompts"
local PROMPT_ATTACHMENT_NAME = "PromptAttachment"
local LOCAL_PROMPT_NAME = "Prompt"
local LOCAL_PROMPT_ATTRIBUTE = "ClientPlotUpgradePrompt"
local UP_ARROW_NAME = "UpArrow"
local UP_ARROW_FLOAT_AMPLITUDE = 0.35
local UP_ARROW_FLOAT_SPEED = 1.8
local DEFAULT_ACTION_TEXT = "Unlock Area"
local DEFAULT_HOLD_DURATION = 0.15
local DEFAULT_MAX_ACTIVATION_DISTANCE = 5

local function Get_Local_Root(): BasePart?
    local Character = LocalPlayer.Character

    if not Character then
        return nil
    end

    local Root = Character:FindFirstChild("HumanoidRootPart")

    if Root and Root:IsA("BasePart") then
        return Root
    end

    return nil
end

local function Is_Local_Player_Plot(Plot: Instance): boolean
    return Plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId
end

local function Get_Or_Create_Up_Arrow(Attachment: Attachment): BillboardGui
    local ExistingArrow = Attachment:FindFirstChild(UP_ARROW_NAME)

    if ExistingArrow and ExistingArrow:IsA("BillboardGui") then
        return ExistingArrow
    end

    if ExistingArrow then
        ExistingArrow:Destroy()
    end

    local UpArrow = UpArrowTemplate:Clone()
    UpArrow.Name = UP_ARROW_NAME
    UpArrow.Enabled = false
    UpArrow:SetAttribute("OriginalStudsOffsetWorldSpace", UpArrow.StudsOffsetWorldSpace)
    UpArrow:SetAttribute("FloatPhase", math.random() * math.pi * 2)
    UpArrow.Parent = Attachment

    return UpArrow
end

local function Disable_Existing_Arrow(Attachment: Attachment)
    local UpArrow = Attachment:FindFirstChild(UP_ARROW_NAME)

    if UpArrow and UpArrow:IsA("BillboardGui") then
        UpArrow.Enabled = false
    end
end

local function Remove_Extra_Prompts(Attachment: Attachment): ProximityPrompt?
    local LocalPrompt: ProximityPrompt? = nil

    for _, Child in Attachment:GetChildren() do
        if not Child:IsA("ProximityPrompt") then
            continue
        end

        if not LocalPrompt and Child:GetAttribute(LOCAL_PROMPT_ATTRIBUTE) == true then
            LocalPrompt = Child
            Child.Name = LOCAL_PROMPT_NAME
            continue
        end

        Child:Destroy()
    end

    return LocalPrompt
end

local function Get_Or_Create_Local_Prompt(Attachment: Attachment): ProximityPrompt
    local Prompt = Remove_Extra_Prompts(Attachment)

    if Prompt then
        return Prompt
    end

    Prompt = Instance.new("ProximityPrompt")
    Prompt.Name = LOCAL_PROMPT_NAME
    Prompt:SetAttribute(LOCAL_PROMPT_ATTRIBUTE, true)
    Prompt.Style = Enum.ProximityPromptStyle.Custom
    Prompt.ActionText = DEFAULT_ACTION_TEXT
    Prompt.ObjectText = ""
    Prompt.HoldDuration = DEFAULT_HOLD_DURATION
    Prompt.MaxActivationDistance = DEFAULT_MAX_ACTIVATION_DISTANCE
    Prompt.RequiresLineOfSight = false
    Prompt.Parent = Attachment

    Prompt.Triggered:Connect(function()
        local UpgradeName = Attachment:GetAttribute("UpgradeName")

        if type(UpgradeName) ~= "string" or UpgradeName == "" then
            return
        end

        Network.RequestPlotAreaUnlock.Fire(UpgradeName)
    end)

    return Prompt
end

local function Sync_Local_Prompt(Prompt: ProximityPrompt, Attachment: Attachment, Enabled: boolean)
    local ActionText = Attachment:GetAttribute("ActionText")
    local ObjectText = Attachment:GetAttribute("ObjectText")
    local HoldDuration = Attachment:GetAttribute("HoldDuration")
    local RequiresLineOfSight = Attachment:GetAttribute("RequiresLineOfSight")
    local DesiredActionText = if type(ActionText) == "string" then ActionText else DEFAULT_ACTION_TEXT
    local DesiredObjectText = if type(ObjectText) == "string" then ObjectText else ""
    local DesiredHoldDuration = if type(HoldDuration) == "number" then HoldDuration else DEFAULT_HOLD_DURATION
    local DesiredRequiresLineOfSight = if type(RequiresLineOfSight) == "boolean" then RequiresLineOfSight else false

    if Prompt.Style ~= Enum.ProximityPromptStyle.Custom then
        Prompt.Style = Enum.ProximityPromptStyle.Custom
    end

    if Prompt.ActionText ~= DesiredActionText then
        Prompt.ActionText = DesiredActionText
    end

    if Prompt.ObjectText ~= DesiredObjectText then
        Prompt.ObjectText = DesiredObjectText
    end

    if Prompt.HoldDuration ~= DesiredHoldDuration then
        Prompt.HoldDuration = DesiredHoldDuration
    end

    if Prompt.MaxActivationDistance ~= DEFAULT_MAX_ACTIVATION_DISTANCE then
        Prompt.MaxActivationDistance = DEFAULT_MAX_ACTIVATION_DISTANCE
    end

    if Prompt.RequiresLineOfSight ~= DesiredRequiresLineOfSight then
        Prompt.RequiresLineOfSight = DesiredRequiresLineOfSight
    end

    if Prompt.Enabled ~= Enabled then
        Prompt.Enabled = Enabled
    end
end

local function Update_Up_Arrow_Float(UpArrow: BillboardGui)
    local OriginalOffset = UpArrow:GetAttribute("OriginalStudsOffsetWorldSpace")

    if typeof(OriginalOffset) ~= "Vector3" then
        OriginalOffset = UpArrow.StudsOffsetWorldSpace
        UpArrow:SetAttribute("OriginalStudsOffsetWorldSpace", OriginalOffset)
    end

    local Phase = UpArrow:GetAttribute("FloatPhase")

    if type(Phase) ~= "number" then
        Phase = math.random() * math.pi * 2
        UpArrow:SetAttribute("FloatPhase", Phase)
    end

    local Alpha = os.clock() * UP_ARROW_FLOAT_SPEED + Phase
    local FloatOffset = (math.sin(Alpha) * 0.5 + 0.5) * UP_ARROW_FLOAT_AMPLITUDE

    UpArrow.StudsOffsetWorldSpace = (OriginalOffset :: Vector3) + Vector3.new(0, FloatOffset, 0)
end

local function Should_Show_Up_Arrow(Prompt: ProximityPrompt, Attachment: Attachment, Root: BasePart?): boolean
    if not Prompt.Enabled or not Root then
        return false
    end

    local Distance = (Root.Position - Attachment.WorldPosition).Magnitude

    return Distance > Prompt.MaxActivationDistance
end

local function Update_Prompt(Plot: Instance, Attachment: Attachment, Root: BasePart?)
    local Enabled = Is_Local_Player_Plot(Plot) and Attachment:GetAttribute("ClientEnabled") == true
    local Prompt = Get_Or_Create_Local_Prompt(Attachment)

    Sync_Local_Prompt(Prompt, Attachment, Enabled)

    if not Enabled then
        Disable_Existing_Arrow(Attachment)
        return
    end

    local UpArrow = Get_Or_Create_Up_Arrow(Attachment)
    UpArrow.Enabled = Should_Show_Up_Arrow(Prompt, Attachment, Root)

    if UpArrow.Enabled then
        Update_Up_Arrow_Float(UpArrow)
    end
end

local function Update_Plot_Prompts()
    local Root = Get_Local_Root()

    for _, Plot in Plots:GetChildren() do
        local PromptFolder = Plot:FindFirstChild(PROMPT_FOLDER_NAME)

        if not PromptFolder then
            continue
        end

        for _, PromptPart in PromptFolder:GetChildren() do
            local Attachment = PromptPart:FindFirstChild(PROMPT_ATTACHMENT_NAME)

            if Attachment and Attachment:IsA("Attachment") then
                Update_Prompt(Plot, Attachment, Root)
            end
        end
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        Update_Plot_Prompts()
    end,
}
