local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Gradients = Assets:WaitForChild("Gradients")

local APPLIED_GRADIENT_ATTRIBUTE = "AppliedRarityGradient"
local RARITY_GRADIENT_NAME = "RarityGradient"

local function Get_Template(Rarity: any): UIGradient?
    local RarityName = if type(Rarity) == "string" and Rarity ~= "" then Rarity else "Common"
    local Gradient = Gradients:FindFirstChild(RarityName)

    if not Gradient or not Gradient:IsA("UIGradient") then
        Gradient = Gradients:FindFirstChild("Common")
    end

    if Gradient and Gradient:IsA("UIGradient") then
        return Gradient
    end

    return nil
end

local function Clear_Text_Gradients(Label: TextLabel)
    for _, Child in Label:GetChildren() do
        if Child:IsA("UIGradient") then
            Child:Destroy()
        end
    end
end

local RarityGradients = {}

function RarityGradients.ClearFromText(Label: TextLabel)
    Clear_Text_Gradients(Label)
    Label:SetAttribute(APPLIED_GRADIENT_ATTRIBUTE, nil)
end

function RarityGradients.ApplyToText(Label: TextLabel, Rarity: any)
    local Template = Get_Template(Rarity)

    if not Template then
        return
    end

    if Label:GetAttribute(APPLIED_GRADIENT_ATTRIBUTE) == Template.Name then
        local ExistingGradient = Label:FindFirstChild(RARITY_GRADIENT_NAME)

        if ExistingGradient and ExistingGradient:IsA("UIGradient") then
            ExistingGradient.Enabled = true
            Label.TextColor3 = Color3.fromRGB(255, 255, 255)
            return
        end
    end

    Clear_Text_Gradients(Label)

    local Gradient = Template:Clone()
    Gradient.Name = RARITY_GRADIENT_NAME
    Gradient.Enabled = true
    Gradient.Parent = Label

    Label:SetAttribute(APPLIED_GRADIENT_ATTRIBUTE, Template.Name)
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
end

return table.freeze(RarityGradients)
