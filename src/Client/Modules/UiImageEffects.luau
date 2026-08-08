local RunService = game:GetService("RunService")

local ROTATION_SPEED_DEGREES_PER_SECOND = 24
local SUNBURST_BOUND_ATTRIBUTE = "SunburstRotationBound"

local Root: Instance? = nil
local DescendantAddedConnection: RBXScriptConnection? = nil
local RenderConnection: RBXScriptConnection? = nil
local LastStepAt = os.clock()
local RotatingImages: { [GuiObject]: boolean } = {}

local function Is_Sunburst_Image(InstanceToCheck: Instance): boolean
    if not InstanceToCheck:IsA("ImageLabel") and not InstanceToCheck:IsA("ImageButton") then
        return false
    end

    return string.find(string.lower(InstanceToCheck.Name), "sunburst", 1, true) ~= nil
end

local function Bind_Sunburst_Image(InstanceToBind: Instance)
    if not Is_Sunburst_Image(InstanceToBind) or InstanceToBind:GetAttribute(SUNBURST_BOUND_ATTRIBUTE) then
        return
    end

    InstanceToBind:SetAttribute(SUNBURST_BOUND_ATTRIBUTE, true)
    RotatingImages[InstanceToBind :: GuiObject] = true
end

local function Bind_Root(NewRoot: Instance)
    Bind_Sunburst_Image(NewRoot)

    for _, Descendant in NewRoot:GetDescendants() do
        Bind_Sunburst_Image(Descendant)
    end
end

local function Rects_Intersect(PositionA: Vector2, SizeA: Vector2, PositionB: Vector2, SizeB: Vector2): boolean
    return PositionA.X < PositionB.X + SizeB.X
        and PositionA.X + SizeA.X > PositionB.X
        and PositionA.Y < PositionB.Y + SizeB.Y
        and PositionA.Y + SizeA.Y > PositionB.Y
end

local function Is_Point_In_Rect(Point: Vector2, Position: Vector2, Size: Vector2): boolean
    return Point.X >= Position.X
        and Point.X <= Position.X + Size.X
        and Point.Y >= Position.Y
        and Point.Y <= Position.Y + Size.Y
end

local function Is_Image_In_View(Image: GuiObject): boolean
    if not Root or not Image:IsDescendantOf(Root) or not Image.Visible then
        return false
    end

    local Camera = workspace.CurrentCamera
    local ViewportSize = if Camera then Camera.ViewportSize else Vector2.zero
    local ImagePosition = Image.AbsolutePosition
    local ImageSize = Image.AbsoluteSize
    local ImageCenter = ImagePosition + ImageSize * 0.5

    if ImageSize.X <= 0 or ImageSize.Y <= 0 or ViewportSize.X <= 0 or ViewportSize.Y <= 0 then
        return false
    end

    if not Is_Point_In_Rect(ImageCenter, Vector2.zero, ViewportSize) then
        return false
    end

    local Current = Image.Parent

    while Current and Current ~= Root do
        if Current:IsA("GuiObject") then
            if not Current.Visible then
                return false
            end

            if Current.ClipsDescendants then
                local CurrentPosition = Current.AbsolutePosition
                local CurrentSize = Current.AbsoluteSize

                if CurrentSize.X <= 0 or CurrentSize.Y <= 0 then
                    return false
                end

                if
                    not Rects_Intersect(ImagePosition, ImageSize, CurrentPosition, CurrentSize)
                    or not Is_Point_In_Rect(ImageCenter, CurrentPosition, CurrentSize)
                then
                    return false
                end
            end
        end

        Current = Current.Parent
    end

    return true
end

local function Step()
    local Now = os.clock()
    local DeltaTime = math.clamp(Now - LastStepAt, 0, 0.1)
    local RotationStep = ROTATION_SPEED_DEGREES_PER_SECOND * DeltaTime

    LastStepAt = Now

    for Image in RotatingImages do
        if not Image.Parent then
            RotatingImages[Image] = nil
            continue
        end

        if Is_Image_In_View(Image) then
            Image.Rotation = (Image.Rotation + RotationStep) % 360
        elseif Image.Rotation ~= 0 then
            Image.Rotation = 0
        end
    end
end

local UiImageEffects = {}

function UiImageEffects.Initialize(NewRoot: Instance)
    if Root == NewRoot then
        return
    end

    Root = NewRoot
    table.clear(RotatingImages)
    Bind_Root(NewRoot)

    if DescendantAddedConnection then
        DescendantAddedConnection:Disconnect()
    end

    DescendantAddedConnection = NewRoot.DescendantAdded:Connect(Bind_Sunburst_Image)

    if not RenderConnection then
        RenderConnection = RunService.RenderStepped:Connect(Step)
    end
end

return table.freeze(UiImageEffects)
