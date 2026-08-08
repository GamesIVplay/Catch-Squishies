local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Phases = require(ReplicatedStorage.Shared.Phases)

type Bounds = {
    Center: Vector3,
    HalfSize: Vector3,
}

type GateSide = {
    Model: Model,
    Hinge: BasePart,
    ClosedHingeCFrame: CFrame,
    ModelOffsetFromHinge: CFrame,
}

type EntranceCache = {
    Entrance: Instance,
    ReferenceCFrame: CFrame,
    Bounds: Bounds,
    Left: GateSide,
    Right: GateSide,
    OpenAmount: NumberValue,
    CurrentTween: Tween?,
    TargetOpenAmount: number,
    State: "Open" | "Close" | nil,
    ScanAccumulator: number,
    LastScanTime: number,
}

local Plots: Instance? = workspace:FindFirstChild("Plots")

local MAX_OPEN_ANGLE = math.rad(88)
local OPEN_BASE_TIME = 0.24
local OPEN_DISTANCE_TIME = 0.08
local CLOSE_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local SCAN_INTERVAL = 0.1
local OPEN_RADIUS = 6.5
local WIDE_OPEN_RADIUS = 13
local WIDE_OPEN_Z_HALF_SIZE = 3

local EntranceCaches: { [Instance]: EntranceCache } = {}

local function Get_Plots(): Instance?
    if Plots and Plots.Parent then
        return Plots
    end

    Plots = workspace:FindFirstChild("Plots")

    return Plots
end

local function Get_All_BaseParts(Container: Instance): { BasePart }
    local Parts = {}

    for _, Descendant in Container:GetDescendants() do
        if Descendant:IsA("BasePart") then
            table.insert(Parts, Descendant)
        end
    end

    return Parts
end

local function Get_Bounds(Container: Instance): Bounds?
    local Parts = Get_All_BaseParts(Container)

    if #Parts == 0 then
        return nil
    end

    local Minimum = Vector3.new(math.huge, math.huge, math.huge)
    local Maximum = Vector3.new(-math.huge, -math.huge, -math.huge)

    for _, Part in Parts do
        local Half = Part.Size * 0.5

        Minimum = Vector3.new(
            math.min(Minimum.X, Part.Position.X - Half.X),
            math.min(Minimum.Y, Part.Position.Y - Half.Y),
            math.min(Minimum.Z, Part.Position.Z - Half.Z)
        )
        Maximum = Vector3.new(
            math.max(Maximum.X, Part.Position.X + Half.X),
            math.max(Maximum.Y, Part.Position.Y + Half.Y),
            math.max(Maximum.Z, Part.Position.Z + Half.Z)
        )
    end

    return {
        Center = (Minimum + Maximum) * 0.5,
        HalfSize = (Maximum - Minimum) * 0.5,
    }
end

local function Flatten_Direction(Direction: Vector3): Vector3
    local Flat = Vector3.new(Direction.X, 0, Direction.Z)

    if Flat.Magnitude < 0.001 then
        return Vector3.zAxis
    end

    return Flat.Unit
end

local function Get_Entrance_Reference_CFrame(Plot: Instance, Bounds: Bounds): CFrame
    local Spawn = Plot:FindFirstChild("Spawn")

    if Spawn and Spawn:IsA("BasePart") then
        local InsideDirection = Flatten_Direction(Spawn.Position - Bounds.Center)

        return CFrame.lookAt(Bounds.Center, Bounds.Center + InsideDirection)
    end

    return CFrame.new(Bounds.Center)
end

local function Find_Gate_Side(Entrance: Instance, SideName: string, FallbackName: string): Model?
    local Side = Entrance:FindFirstChild(SideName) or Entrance:FindFirstChild(FallbackName)

    if Side and Side:IsA("Model") then
        return Side
    end

    return nil
end

local function Find_Hinge(Side: Model): BasePart?
    local DirectHinge = Side:FindFirstChild("Hinge")

    if DirectHinge and DirectHinge:IsA("BasePart") then
        return DirectHinge
    end

    for _, Descendant in Side:GetDescendants() do
        if Descendant:IsA("BasePart") and string.lower(Descendant.Name) == "hinge" then
            return Descendant
        end
    end

    return nil
end

local function Build_Gate_Side(Side: Model): GateSide?
    local Hinge = Find_Hinge(Side)

    if not Hinge then
        return nil
    end

    local ClosedHingeCFrame = Hinge.CFrame
    local ClosedModelPivot = Side:GetPivot()

    return {
        Model = Side,
        Hinge = Hinge,
        ClosedHingeCFrame = ClosedHingeCFrame,
        ModelOffsetFromHinge = ClosedHingeCFrame:ToObjectSpace(ClosedModelPivot),
    }
end

local function Pivot_Gate_Side(Side: GateSide, HingeCFrame: CFrame)
    Side.Model:PivotTo(HingeCFrame * Side.ModelOffsetFromHinge)
end

local function Apply_Open_Amount(Cache: EntranceCache)
    local OpenAmount = Cache.OpenAmount.Value
    local LeftHingeCFrame = Cache.Left.ClosedHingeCFrame * CFrame.Angles(0, MAX_OPEN_ANGLE * OpenAmount, 0)
    local RightHingeCFrame = Cache.Right.ClosedHingeCFrame * CFrame.Angles(0, -MAX_OPEN_ANGLE * OpenAmount, 0)

    Pivot_Gate_Side(Cache.Left, LeftHingeCFrame)
    Pivot_Gate_Side(Cache.Right, RightHingeCFrame)
end

local function Create_Entrance_Cache(Plot: Instance, Entrance: Instance): EntranceCache?
    local LeftModel = Find_Gate_Side(Entrance, "Left", "GateLeft")
    local RightModel = Find_Gate_Side(Entrance, "Right", "GateRight")
    local Bounds = Get_Bounds(Entrance)

    if not LeftModel or not RightModel or not Bounds then
        return nil
    end

    local Left = Build_Gate_Side(LeftModel)
    local Right = Build_Gate_Side(RightModel)

    if not Left or not Right then
        return nil
    end

    local OpenAmount = Instance.new("NumberValue")
    OpenAmount.Name = "ClientOpenAmount"
    OpenAmount.Value = 0

    local Cache: EntranceCache = {
        Entrance = Entrance,
        ReferenceCFrame = Get_Entrance_Reference_CFrame(Plot, Bounds),
        Bounds = Bounds,
        Left = Left,
        Right = Right,
        OpenAmount = OpenAmount,
        CurrentTween = nil,
        TargetOpenAmount = 0,
        State = nil,
        ScanAccumulator = 0,
        LastScanTime = 0,
    }

    OpenAmount.Changed:Connect(function()
        Apply_Open_Amount(Cache)
    end)

    Apply_Open_Amount(Cache)

    return Cache
end

local function Refresh_Entrance_Caches()
    local PlotsFolder = Get_Plots()

    if not PlotsFolder then
        return
    end

    for _, Plot in PlotsFolder:GetChildren() do
        local Entrance = Plot:FindFirstChild("Entrance")

        if not Entrance or EntranceCaches[Entrance] then
            continue
        end

        local Cache = Create_Entrance_Cache(Plot, Entrance)

        if Cache then
            EntranceCaches[Entrance] = Cache
        end
    end

    for Entrance, Cache in EntranceCaches do
        if Entrance.Parent then
            continue
        end

        if Cache.CurrentTween then
            Cache.CurrentTween:Cancel()
        end

        Cache.OpenAmount:Destroy()
        EntranceCaches[Entrance] = nil
    end
end

local function Is_Player_Near_Entrance(LocalPosition: Vector3): boolean
    return LocalPosition.Magnitude < OPEN_RADIUS
        or (LocalPosition.Magnitude < WIDE_OPEN_RADIUS and math.abs(LocalPosition.Z) < WIDE_OPEN_Z_HALF_SIZE)
end

local function Get_Player_Open_Amount(Cache: EntranceCache, Root: BasePart): number?
    local LocalPosition = Cache.ReferenceCFrame:PointToObjectSpace(Root.Position)

    if not Is_Player_Near_Entrance(LocalPosition) then
        return nil
    end

    local OpenAmount = -math.sign(LocalPosition.Z)

    if OpenAmount == 0 then
        return 1
    end

    return OpenAmount
end

local function Get_Nearest_Open_Amount(Cache: EntranceCache): number
    local BestOpenAmount = 0
    local BestDistance = math.huge

    for _, Player in Players:GetPlayers() do
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")

        if not Root or not Root:IsA("BasePart") then
            continue
        end

        local OpenAmount = Get_Player_Open_Amount(Cache, Root)

        if not OpenAmount then
            continue
        end

        local Distance = (Root.Position - Cache.Bounds.Center).Magnitude

        if Distance < BestDistance then
            BestDistance = Distance
            BestOpenAmount = OpenAmount
        end
    end

    return BestOpenAmount
end

local function Play_Open_Tween(Cache: EntranceCache, TargetOpenAmount: number)
    if Cache.State == "Open" then
        return
    end

    if Cache.CurrentTween then
        Cache.CurrentTween:Cancel()
        Cache.CurrentTween = nil
    end

    local OpenDistance = math.max(math.abs(Cache.OpenAmount.Value - TargetOpenAmount), 1)
    local Tween = TweenService:Create(
        Cache.OpenAmount,
        TweenInfo.new(
            OPEN_BASE_TIME + OpenDistance * OPEN_DISTANCE_TIME,
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        ),
        {
            Value = TargetOpenAmount,
        }
    )

    Cache.State = "Open"
    Cache.TargetOpenAmount = TargetOpenAmount
    Cache.CurrentTween = Tween
    Tween:Play()
end

local function Play_Close_Tween(Cache: EntranceCache)
    if Cache.State == "Close" then
        return
    end

    if Cache.CurrentTween then
        Cache.CurrentTween:Cancel()
        Cache.CurrentTween = nil
    end

    local Tween = TweenService:Create(Cache.OpenAmount, CLOSE_TWEEN_INFO, {
        Value = 0,
    })

    Cache.State = "Close"
    Cache.TargetOpenAmount = 0
    Cache.CurrentTween = Tween
    Tween:Play()
end

local function Scan_Entrance(Cache: EntranceCache)
    local TargetOpenAmount = Get_Nearest_Open_Amount(Cache)

    if TargetOpenAmount ~= 0 then
        Play_Open_Tween(Cache, TargetOpenAmount)
        return
    end

    Play_Close_Tween(Cache)
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function(_, DeltaTime: number?)
        Refresh_Entrance_Caches()

        local StepDelta = DeltaTime or 1 / 60

        for _, Cache in EntranceCaches do
            Cache.ScanAccumulator += StepDelta

            if Cache.ScanAccumulator < SCAN_INTERVAL then
                continue
            end

            Cache.ScanAccumulator = 0
            Cache.LastScanTime = os.clock()
            Scan_Entrance(Cache)
        end
    end,
}
