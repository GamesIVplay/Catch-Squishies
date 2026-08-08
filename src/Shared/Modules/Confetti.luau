local Default = {
    Count = 1000,
    HorizontalRange = 100,
    MinScale = 0.1,
    MaxScale = 1,
    MinWidth = 15,
    MaxWidth = 30,
    MinHeight = 8,
    MaxHeight = 15,
    MinSpeed = 0.5,
    MaxSpeed = 25,
    MinRotation = 0,
    MaxRotation = 360,
    Colors = {
        Color3.fromRGB(255, 80, 255),
        Color3.fromRGB(80, 203, 255),
        Color3.fromRGB(112, 255, 80),
        Color3.fromRGB(255, 80, 83),
        Color3.fromRGB(255, 220, 80),
    },
}

local Pieces = {}
local Connection

local function CreatePiece(Info)
    local GUI = Info.GUI
    local RandomWidth = math.random(Info.MinWidth, Info.MaxWidth)
    local RandomHeight = math.random(Info.MinHeight, Info.MaxHeight)

    local StartX = math.random(0, workspace.CurrentCamera.ViewportSize.X)

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.fromOffset(RandomWidth, RandomHeight)
    Frame.Position = UDim2.new(0, StartX, -0.5, 0)
    Frame.BorderSizePixel = 0
    Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    Frame.BackgroundColor3 = Info.Colors[math.random(#Info.Colors)]
    Frame.Parent = GUI
    Frame.ZIndex = 99

    local RotationSpeed = math.random(-720, 720) * (0.8 + math.random() * 0.4)

    local HoriziontalSpeed = (math.random() - 0.5) * (Info.HorizontalRange or 100) * (0.7 + math.random() * 0.6)
    local VerticalSpeed = math.random(Info.MinSpeed, Info.MaxSpeed) * (0.6 + math.random() * 0.8)

    local SwayAmplitude = math.random(10, 50) * (0.5 + math.random() * 1.0)
    local SwayFreq = math.random(1, 3) * (0.7 + math.random() * 0.6)
    local SwayOffset = math.random() * 2 * math.pi

    local Gravity = 0.015 * (0.8 + math.random() * 0.4)

    return {
        Frame = Frame,
        BaseWidth = RandomWidth,
        BaseHeight = RandomHeight,
        Rotation = math.random(Info.MinRotation, Info.MaxRotation),
        RotationSpeed = RotationSpeed,
        Velocity = Vector2.new(HoriziontalSpeed, VerticalSpeed),
        Gravity = Gravity,
        MinScale = 0.2 * (0.7 + math.random() * 0.6),

        SwayAmplitude = SwayAmplitude,
        SwayFrequency = SwayFreq,
        SwayOffset = SwayOffset,
        SwayTime = math.random() * 2,
    }
end

local function UpdateConfetti(Delta)
    local ViewportSize = workspace.CurrentCamera.ViewportSize

    for i = #Pieces, 1, -1 do
        local Confetti = Pieces[i]

        Confetti.Velocity = Vector2.new(
            Confetti.Velocity.X,
            Confetti.Velocity.Y + Confetti.Gravity * (0.9 + math.random() * 0.2) * Delta * 60
        )

        Confetti.SwayTime = Confetti.SwayTime + Delta

        local HorizontalSway = Confetti.SwayAmplitude
            * math.sin(Confetti.SwayFrequency * Confetti.SwayTime + Confetti.SwayOffset)
            * (0.8 + math.random() * 0.4)

        local Frame = Confetti.Frame

        local jitterX = (math.random() - 0.5) * 2
        local jitterY = (math.random() - 0.5) * 0.5

        local NewX = Frame.Position.X.Offset + (Confetti.Velocity.X + HorizontalSway + jitterX) * Delta
        local NewY = Frame.Position.Y.Offset + Confetti.Velocity.Y + jitterY
        local NewPosition = UDim2.fromOffset(NewX, NewY)
        Frame.Position = NewPosition

        local RotationVariation = 1 + (math.random() - 0.5) * 0.4
        Confetti.Rotation = (Confetti.Rotation + Confetti.RotationSpeed * RotationVariation * Delta) % 360
        Frame.Rotation = Confetti.Rotation

        local RadRotation = math.rad(Confetti.Rotation)
        local WidthScale = Confetti.MinScale + (1 - Confetti.MinScale) * math.abs(math.cos(RadRotation))
        Frame.Size = UDim2.fromOffset(Confetti.BaseWidth * WidthScale, Confetti.BaseHeight * WidthScale) -- Random height variation)

        if NewY > ViewportSize.Y + 50 then
            Frame:Destroy()
            table.remove(Pieces, i)
        end
    end

    if #Pieces == 0 and Connection then
        Connection:Disconnect()
    end
end

return function(Info: {
    Count: number,
    MinWidth: number,
    MaxWidth: number,
    MinHeight: number,
    MaxHeight: number,
    MinSpeed: number,
    MaxSpeed: number,
    MinRotation: number,
    MaxRotation: number,
    Colors: { Color3 },
    GUI: ScreenGui,
})
    for SettingName, SettingValue in Default do
        if not Info[SettingName] then
            Info[SettingName] = SettingValue
        end
    end

    if not Info.GUI then
        return
    end

    if Connection then
        Connection:Disconnect()
        for _, Piece in Pieces do
            Piece.Frame:Destroy()
        end
    end

    table.clear(Pieces)

    for _ = 1, Info.Count do
        table.insert(Pieces, CreatePiece(Info))
    end

    Connection = game:GetService("RunService").RenderStepped:Connect(UpdateConfetti)
end
