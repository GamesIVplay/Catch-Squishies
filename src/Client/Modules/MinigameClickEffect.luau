local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local MinigameClickEffect = {}

local CLICK_EFFECT_NAME = "ClickEffect"
local CLICK_EFFECT_LIFETIME = 0.35
local CLICK_EFFECT_START_SCALE = 0.65
local CLICK_EFFECT_END_SCALE = 1.35
local CLICK_EFFECT_RISE_PIXELS = -18

local function Find_Click_Effect_Template(MinigameGui: ScreenGui?, MinigameFrame: GuiObject?): GuiObject?
    local Candidate = MinigameFrame and MinigameFrame:FindFirstChild(CLICK_EFFECT_NAME, true)

    if not Candidate and MinigameGui then
        for _, Descendant in MinigameGui:GetDescendants() do
            if string.lower(Descendant.Name) == string.lower(CLICK_EFFECT_NAME) then
                Candidate = Descendant
                break
            end
        end
    end

    if not Candidate or not Candidate:IsA("GuiObject") then
        return nil
    end

    Candidate.Visible = false

    return Candidate
end

local function Get_Click_Point(MinigameFrame: GuiObject?, ScreenPosition: Vector2?): Vector2?
    if ScreenPosition then
        return ScreenPosition
    end

    if not MinigameFrame then
        return nil
    end

    local AbsolutePosition = MinigameFrame.AbsolutePosition
    local AbsoluteSize = MinigameFrame.AbsoluteSize

    return Vector2.new(AbsolutePosition.X + AbsoluteSize.X * 0.5, AbsolutePosition.Y + AbsoluteSize.Y * 0.5)
end

local function Get_Effect_Scale(Effect: GuiObject): UIScale
    local ExistingScale = Effect:FindFirstChild("CatchClickEffectScale")

    if ExistingScale and ExistingScale:IsA("UIScale") then
        return ExistingScale
    end

    local Scale = Instance.new("UIScale")

    Scale.Name = "CatchClickEffectScale"
    Scale.Parent = Effect

    return Scale
end

local function Disable_Input(Effect: GuiObject)
    Effect.Active = false

    if Effect:IsA("GuiButton") then
        Effect.AutoButtonColor = false
    end

    for _, Descendant in Effect:GetDescendants() do
        if not Descendant:IsA("GuiObject") then
            continue
        end

        Descendant.Active = false

        if Descendant:IsA("GuiButton") then
            Descendant.AutoButtonColor = false
        end
    end
end

local function Tween_Transparency(Effect: GuiObject, TweenInfoData: TweenInfo)
    local function Tween_Object(Object: Instance)
        local Goals = {}

        if Object:IsA("GuiObject") then
            Goals.BackgroundTransparency = 1
        end

        if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then
            Goals.ImageTransparency = 1
        end

        if Object:IsA("TextLabel") or Object:IsA("TextButton") or Object:IsA("TextBox") then
            Goals.TextTransparency = 1
            Goals.TextStrokeTransparency = 1
        end

        if Object:IsA("UIStroke") then
            Goals.Transparency = 1
        end

        if next(Goals) then
            TweenService:Create(Object, TweenInfoData, Goals):Play()
        end
    end

    Tween_Object(Effect)

    for _, Descendant in Effect:GetDescendants() do
        Tween_Object(Descendant)
    end
end

local function Is_Visible_Object(Object: Instance, Root: GuiObject): boolean
    if not Object:IsA("GuiObject") then
        return false
    end

    if Object ~= Root and not Object.Visible then
        return false
    end

    if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then
        return Object.Image ~= "" and Object.ImageTransparency < 1
    end

    if Object:IsA("TextLabel") or Object:IsA("TextButton") or Object:IsA("TextBox") then
        return Object.Text ~= "" and Object.TextTransparency < 1
    end

    return Object.BackgroundTransparency < 1
end

local function Get_Visual_Offset(Template: GuiObject): Vector2
    local MinX = math.huge
    local MinY = math.huge
    local MaxX = -math.huge
    local MaxY = -math.huge

    local function Include_Object(Object: Instance)
        if not Is_Visible_Object(Object, Template) then
            return
        end

        local GuiObject = Object :: GuiObject
        local Position = GuiObject.AbsolutePosition
        local Size = GuiObject.AbsoluteSize

        MinX = math.min(MinX, Position.X)
        MinY = math.min(MinY, Position.Y)
        MaxX = math.max(MaxX, Position.X + Size.X)
        MaxY = math.max(MaxY, Position.Y + Size.Y)
    end

    Include_Object(Template)

    for _, Descendant in Template:GetDescendants() do
        Include_Object(Descendant)
    end

    if MinX == math.huge then
        return Vector2.zero
    end

    local RootPosition = Template.AbsolutePosition
    local RootSize = Template.AbsoluteSize
    local RootCenter = Vector2.new(RootPosition.X + RootSize.X * 0.5, RootPosition.Y + RootSize.Y * 0.5)
    local VisualCenter = Vector2.new((MinX + MaxX) * 0.5, (MinY + MaxY) * 0.5)

    return VisualCenter - RootCenter
end

function MinigameClickEffect.Play(MinigameGui: ScreenGui?, MinigameFrame: GuiObject?, ScreenPosition: Vector2?)
    local Template = Find_Click_Effect_Template(MinigameGui, MinigameFrame)

    if not Template then
        return
    end

    local EffectParent = Template.Parent
    local Point = Get_Click_Point(MinigameFrame, ScreenPosition)

    if not EffectParent or not Point then
        return
    end

    local RootPoint = Point - Get_Visual_Offset(Template)
    local LocalPoint = RootPoint

    if EffectParent:IsA("GuiObject") then
        LocalPoint -= EffectParent.AbsolutePosition
    end

    local Effect = Template:Clone()

    Effect.Name = "RuntimeClickEffect"
    Effect.AnchorPoint = Vector2.new(0.5, 0.5)
    Effect.Position = UDim2.fromOffset(LocalPoint.X, LocalPoint.Y)

    if Template.AbsoluteSize.X > 0 and Template.AbsoluteSize.Y > 0 then
        Effect.Size = UDim2.fromOffset(Template.AbsoluteSize.X, Template.AbsoluteSize.Y)
    end

    Effect.Visible = true
    Effect.ZIndex = Template.ZIndex + 100
    Disable_Input(Effect)
    Effect.Parent = EffectParent

    for _, Descendant in Effect:GetDescendants() do
        if Descendant:IsA("GuiObject") then
            Descendant.ZIndex += 100
        end
    end

    local Scale = Get_Effect_Scale(Effect)
    local TweenInfoData = TweenInfo.new(CLICK_EFFECT_LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    Scale.Scale = CLICK_EFFECT_START_SCALE

    TweenService:Create(Scale, TweenInfoData, {
        Scale = CLICK_EFFECT_END_SCALE,
    }):Play()
    TweenService:Create(Effect, TweenInfoData, {
        Position = UDim2.fromOffset(LocalPoint.X, LocalPoint.Y + CLICK_EFFECT_RISE_PIXELS),
    }):Play()
    Tween_Transparency(Effect, TweenInfoData)

    Debris:AddItem(Effect, CLICK_EFFECT_LIFETIME + 0.1)
end

return MinigameClickEffect
