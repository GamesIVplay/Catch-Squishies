local ScreenDarkener = {}
ScreenDarkener.__index = ScreenDarkener

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

function ScreenDarkener.New(Padding, TweenTime)
    local Self = setmetatable({}, ScreenDarkener)

    Self.Player = Players.LocalPlayer
    Self.Camera = workspace.CurrentCamera

    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local Visuals = PlayerGui:WaitForChild("Visuals", 15)
    if not Visuals then
        warn("[ScreenDarkener] Visuals ScreenGui not found in PlayerGui")
        return nil
    end

    local CanvasGroup = Visuals:WaitForChild("CanvasGroup", 10)
    if not CanvasGroup then
        warn("[ScreenDarkener] CanvasGroup not found in Visuals")
        return nil
    end

    Self.CanvasGroup = CanvasGroup
    Self.TopFrame = CanvasGroup:WaitForChild("Top", 5)
    Self.BottomFrame = CanvasGroup:WaitForChild("Bottom", 5)
    Self.LeftFrame = CanvasGroup:WaitForChild("Left", 5)
    Self.RightFrame = CanvasGroup:WaitForChild("Right", 5)

    Self.Padding = Padding or 5
    Self.TweenTime = TweenTime or 0.2
    Self.Tweens = {}
    Self.LastGoal = {}
    Self.Target = nil
    Self.Connection = nil
    Self.StateToken = 0

    return Self
end

function ScreenDarkener:CancelTweens()
    for Frame, Tween in self.Tweens do
        Tween:Cancel()
        self.Tweens[Frame] = nil
    end
end

function ScreenDarkener:TweenFrame(Frame, Goal)
    local CurrentTween = self.Tweens[Frame]
    if CurrentTween then
        CurrentTween:Cancel()
    end

    self.Tweens[Frame] =
        TweenService:Create(Frame, TweenInfo.new(self.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), Goal)
    self.Tweens[Frame]:Play()
end

function ScreenDarkener:OffScreenGoals()
    local ScreenW = self.CanvasGroup.AbsoluteSize.X
    local ScreenH = self.CanvasGroup.AbsoluteSize.Y
    return {
        [self.TopFrame] = { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(ScreenW, 0) },
        [self.BottomFrame] = { Position = UDim2.fromOffset(0, ScreenH), Size = UDim2.fromOffset(ScreenW, 0) },
        [self.LeftFrame] = { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(0, ScreenH) },
        [self.RightFrame] = { Position = UDim2.fromOffset(ScreenW, 0), Size = UDim2.fromOffset(0, ScreenH) },
    }
end

function ScreenDarkener:UpdateLoop()
    self.Connection = RunService.RenderStepped:Connect(function()
        if not self.Target then
            return
        end
        local ScreenW = self.CanvasGroup.AbsoluteSize.X
        local ScreenH = self.CanvasGroup.AbsoluteSize.Y
        local Goals = {}

        local CX, CY, R
        local AnyOnScreen = true

        local GuiService = game:GetService("GuiService")
        local Inset = GuiService:GetGuiInset()

        if self.Target:IsA("GuiObject") then
            local AbsPos = self.Target.AbsolutePosition
            local AbsSize = self.Target.AbsoluteSize

            local Parent = self.Target.Parent
            while Parent do
                if Parent:IsA("ScrollingFrame") then
                    AbsPos = AbsPos - Vector2.new(Parent.CanvasPosition.X, Parent.CanvasPosition.Y)
                end
                Parent = Parent.Parent
            end

            local MinX = AbsPos.X + Inset.X - self.Padding
            local MinY = AbsPos.Y + Inset.Y - self.Padding
            local MaxX = AbsPos.X + Inset.X + AbsSize.X + self.Padding
            local MaxY = AbsPos.Y + Inset.Y + AbsSize.Y + self.Padding

            CX = (MinX + MaxX) / 2
            CY = (MinY + MaxY) / 2
            R = math.max(MaxX - MinX, MaxY - MinY) / 2
        elseif self.Target:IsA("BasePart") then
            local Part = self.Target
            local Camera = workspace.CurrentCamera or self.Camera
            self.Camera = Camera
            local Corners = {
                Part.Position + Vector3.new(Part.Size.X / 2, Part.Size.Y / 2, Part.Size.Z / 2),
                Part.Position + Vector3.new(-Part.Size.X / 2, Part.Size.Y / 2, Part.Size.Z / 2),
                Part.Position + Vector3.new(Part.Size.X / 2, -Part.Size.Y / 2, Part.Size.Z / 2),
                Part.Position + Vector3.new(-Part.Size.X / 2, -Part.Size.Y / 2, Part.Size.Z / 2),
                Part.Position + Vector3.new(Part.Size.X / 2, Part.Size.Y / 2, -Part.Size.Z / 2),
                Part.Position + Vector3.new(-Part.Size.X / 2, Part.Size.Y / 2, -Part.Size.Z / 2),
                Part.Position + Vector3.new(Part.Size.X / 2, -Part.Size.Y / 2, -Part.Size.Z / 2),
                Part.Position + Vector3.new(-Part.Size.X / 2, -Part.Size.Y / 2, -Part.Size.Z / 2),
            }

            local MinX, MaxX, MinY, MaxY = math.huge, -math.huge, math.huge, -math.huge
            AnyOnScreen = false

            for _, Corner in ipairs(Corners) do
                local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Corner)
                if OnScreen then
                    AnyOnScreen = true
                    MinX = math.min(MinX, ScreenPos.X)
                    MaxX = math.max(MaxX, ScreenPos.X)
                    MinY = math.min(MinY, ScreenPos.Y)
                    MaxY = math.max(MaxY, ScreenPos.Y)
                end
            end

            if AnyOnScreen then
                CX = (MinX + MaxX) / 2
                CY = (MinY + MaxY) / 2
                R = math.max(MaxX - MinX, MaxY - MinY) / 2 + self.Padding
            end
        else
            AnyOnScreen = false
        end

        if not AnyOnScreen or not R then
            Goals = self:OffScreenGoals()
        else
            -- 4 frames create a square hole, ImageLabel fills it with circular cutout
            local holeLeft = math.ceil(CX - R)
            local holeRight = math.floor(CX + R)
            local holeTop = math.ceil(CY - R)
            local holeBottom = math.floor(CY + R)

            Goals[self.TopFrame] = {
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.fromOffset(ScreenW, math.max(0, holeTop)),
            }
            Goals[self.BottomFrame] = {
                Position = UDim2.fromOffset(0, holeBottom),
                Size = UDim2.fromOffset(ScreenW, math.max(0, ScreenH - holeBottom)),
            }
            Goals[self.LeftFrame] = {
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.fromOffset(math.max(0, holeLeft), ScreenH),
            }
            Goals[self.RightFrame] = {
                Position = UDim2.fromOffset(holeRight, 0),
                Size = UDim2.fromOffset(math.max(0, ScreenW - holeRight), ScreenH),
            }
        end

        -- Set positions directly (no tweening) so all elements stay in sync
        for Frame, Goal in pairs(Goals) do
            Frame.Position = Goal.Position
            Frame.Size = Goal.Size
        end
    end)
end

function ScreenDarkener:Activate(Target, Padding)
    self.StateToken += 1
    self:CancelTweens()
    self.CanvasGroup.Visible = true
    local OffGoals = self:OffScreenGoals()
    for Frame, Goal in pairs(OffGoals) do
        Frame.Position = Goal.Position
        Frame.Size = Goal.Size
    end

    if Padding then
        self.Padding = Padding
    end

    self.Target = Target
    if self.Connection then
        self.Connection:Disconnect()
    end
    self:UpdateLoop()
end

function ScreenDarkener:Deactivate()
    self.StateToken += 1
    local StateToken = self.StateToken
    self.Target = nil

    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    local OffGoals = self:OffScreenGoals()
    for Frame, Goal in pairs(OffGoals) do
        self:TweenFrame(Frame, Goal)
    end

    -- Hide after tween completes
    task.delay(self.TweenTime, function()
        if self.CanvasGroup and self.StateToken == StateToken and not self.Target then
            self.CanvasGroup.Visible = false
        end
    end)
end

function ScreenDarkener:Switch(NewTarget, Padding)
    self.StateToken += 1
    self:CancelTweens()
    self.CanvasGroup.Visible = true

    if Padding then
        self.Padding = Padding
    end
    self.Target = NewTarget
end

return ScreenDarkener
