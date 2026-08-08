local PlotAreaMath = {}

local BASE_MAX_SQUISHIES = 6
local MAX_SQUISHIES_PER_UNLOCKED_AREA = 3
local AREA_TOLERANCE = 0.5

export type AreaRect = {
    Center: Vector3,
    RightDirection: Vector3,
    FrontDirection: Vector3,
    HalfWidth: number,
    HalfDepth: number,
}

local AREA_ATTRIBUTES = table.freeze({
    "LeftFrontUnlocked",
    "RightFrontUnlocked",
    "CenterBackUnlocked",
    "LeftBackUnlocked",
    "RightBackUnlocked",
})

local function Get_Zone_Bounds(Zone: Instance): (CFrame?, Vector3?)
    if Zone:IsA("Model") then
        local Success, BoundsCFrame, BoundsSize = pcall(function()
            return Zone:GetBoundingBox()
        end)

        if Success then
            return BoundsCFrame, BoundsSize
        end
    elseif Zone:IsA("BasePart") then
        return Zone.CFrame, Zone.Size
    end

    return nil, nil
end

local function Get_Zone(Zones: Instance, ZoneName: string): Instance?
    local Zone = Zones:FindFirstChild(ZoneName)

    if Zone then
        return Zone
    end

    return Zones:FindFirstChild(string.gsub(ZoneName, "_", ""))
end

local function Get_Zone_Center_2D(Zone: Instance): Vector3?
    local BoundsCFrame, _BoundsSize = Get_Zone_Bounds(Zone)

    if not BoundsCFrame then
        return nil
    end

    return Vector3.new(BoundsCFrame.Position.X, 0, BoundsCFrame.Position.Z)
end

local CLEARANCE_DIRECTIONS = table.freeze({
    Vector3.new(1, 0, 0),
    Vector3.new(-1, 0, 0),
    Vector3.new(0, 0, 1),
    Vector3.new(0, 0, -1),
    Vector3.new(1, 0, 1).Unit,
    Vector3.new(1, 0, -1).Unit,
    Vector3.new(-1, 0, 1).Unit,
    Vector3.new(-1, 0, -1).Unit,
})

local function Is_Position_In_Rect(Position: Vector3, Rect: AreaRect, Tolerance: number?): boolean
    local AppliedTolerance = if type(Tolerance) == "number" then Tolerance else AREA_TOLERANCE
    local Offset = Vector3.new(Position.X - Rect.Center.X, 0, Position.Z - Rect.Center.Z)
    local LocalX = Offset:Dot(Rect.RightDirection)
    local LocalZ = Offset:Dot(Rect.FrontDirection)

    return math.abs(LocalX) <= Rect.HalfWidth + AppliedTolerance
        and math.abs(LocalZ) <= Rect.HalfDepth + AppliedTolerance
end

local function Is_Position_In_Rects(Position: Vector3, Rects: { AreaRect }, Tolerance: number?): boolean
    for _, Rect in Rects do
        if Is_Position_In_Rect(Position, Rect, Tolerance) then
            return true
        end
    end

    return false
end

local function Has_Clearance_In_Rects(Position: Vector3, Rects: { AreaRect }, Clearance: number): boolean
    if not Is_Position_In_Rects(Position, Rects, 0) then
        return false
    end

    if Clearance <= 0 then
        return true
    end

    for _, Direction in CLEARANCE_DIRECTIONS do
        if not Is_Position_In_Rects(Position + Direction * Clearance, Rects, 0) then
            return false
        end
    end

    return true
end

local function Get_Rect_Center(Rect: AreaRect): Vector3
    return Rect.Center
end

local function Flatten_Direction(Direction: Vector3): Vector3?
    local Flat = Vector3.new(Direction.X, 0, Direction.Z)

    if Flat.Magnitude <= 0.001 then
        return nil
    end

    return Flat.Unit
end

local function Orthogonalize_Direction(Direction: Vector3, Reference: Vector3): Vector3?
    return Flatten_Direction(Direction - Reference * Direction:Dot(Reference))
end

local function Add_Oriented_Rect(
    Rects: { AreaRect },
    Center: Vector3,
    RightDirection: Vector3,
    FrontDirection: Vector3,
    HalfWidth: number,
    HalfDepth: number
)
    table.insert(Rects, {
        Center = Center,
        RightDirection = RightDirection,
        FrontDirection = FrontDirection,
        HalfWidth = HalfWidth,
        HalfDepth = HalfDepth,
    })
end

local function Get_Inset_Rect_Extents(Rect: AreaRect, Padding: number): (number, number)
    local Inset = math.max(0, Padding)

    return math.max(0, Rect.HalfWidth - Inset), math.max(0, Rect.HalfDepth - Inset)
end

local function Clamp_To_Rect(Rect: AreaRect, Position: Vector3, Padding: number): Vector3
    local HalfWidth, HalfDepth = Get_Inset_Rect_Extents(Rect, Padding)
    local Offset = Vector3.new(Position.X - Rect.Center.X, 0, Position.Z - Rect.Center.Z)
    local LocalX = math.clamp(Offset:Dot(Rect.RightDirection), -HalfWidth, HalfWidth)
    local LocalZ = math.clamp(Offset:Dot(Rect.FrontDirection), -HalfDepth, HalfDepth)
    local FlatPosition = Rect.Center + Rect.RightDirection * LocalX + Rect.FrontDirection * LocalZ

    return Vector3.new(FlatPosition.X, Position.Y, FlatPosition.Z)
end

function PlotAreaMath.GetUnlockedAreaCount(Plot: Instance?): number
    if not Plot then
        return 0
    end

    local Count = 0

    for _, AttributeName in AREA_ATTRIBUTES do
        if Plot:GetAttribute(AttributeName) == true then
            Count += 1
        end
    end

    return Count
end

function PlotAreaMath.GetMaxSquishies(Plot: Instance?): number
    return BASE_MAX_SQUISHIES + PlotAreaMath.GetUnlockedAreaCount(Plot) * MAX_SQUISHIES_PER_UNLOCKED_AREA
end

function PlotAreaMath.GetUnlockedAreaRects(Plot: Instance?): { AreaRect }
    local Zones = Plot and Plot:FindFirstChild("Zones")

    if not Plot or not Zones then
        return {}
    end

    local FrontZone = Get_Zone(Zones, "Zone_01")
    local RightZone = Get_Zone(Zones, "Zone_02")
    local BackZone = Get_Zone(Zones, "Zone_04")
    local LeftZone = Get_Zone(Zones, "Zone_12")

    if not FrontZone or not RightZone or not BackZone or not LeftZone then
        return {}
    end

    local FrontCenter = Get_Zone_Center_2D(FrontZone)
    local RightCenter = Get_Zone_Center_2D(RightZone)
    local BackCenter = Get_Zone_Center_2D(BackZone)
    local LeftCenter = Get_Zone_Center_2D(LeftZone)

    if not FrontCenter or not RightCenter or not BackCenter or not LeftCenter then
        return {}
    end

    local RightDirection = Flatten_Direction(RightCenter - LeftCenter)
    local FrontDirection = Flatten_Direction(FrontCenter - BackCenter)

    if not RightDirection or not FrontDirection then
        return {}
    end

    FrontDirection = Orthogonalize_Direction(FrontDirection, RightDirection) or FrontDirection

    local CellWidth = (RightCenter - LeftCenter).Magnitude
    local CellDepth = (FrontCenter - BackCenter).Magnitude

    if CellWidth <= 1 or CellDepth <= 1 then
        return {}
    end

    local Rects = {}
    local HalfWidth = CellWidth * 0.5
    local HalfDepth = CellDepth * 0.5
    local StartCenter = ((LeftCenter + RightCenter) * 0.5 + (BackCenter + FrontCenter) * 0.5) * 0.5

    local function Add_Cell(ColumnOffset: number, RowOffset: number)
        Add_Oriented_Rect(
            Rects,
            StartCenter + RightDirection * CellWidth * ColumnOffset + FrontDirection * CellDepth * RowOffset,
            RightDirection,
            FrontDirection,
            HalfWidth,
            HalfDepth
        )
    end

    Add_Cell(0, 0)

    if Plot:GetAttribute("LeftFrontUnlocked") == true then
        Add_Cell(-1, 0)
    end

    if Plot:GetAttribute("RightFrontUnlocked") == true then
        Add_Cell(1, 0)
    end

    if Plot:GetAttribute("CenterBackUnlocked") == true then
        Add_Cell(0, -1)
    end

    if Plot:GetAttribute("LeftBackUnlocked") == true then
        Add_Cell(-1, -1)
    end

    if Plot:GetAttribute("RightBackUnlocked") == true then
        Add_Cell(1, -1)
    end

    return Rects
end

function PlotAreaMath.IsPositionInRect(Position: Vector3, Rect: AreaRect, Tolerance: number?): boolean
    return Is_Position_In_Rect(Position, Rect, Tolerance)
end

function PlotAreaMath.IsPositionInUnlockedArea(Plot: Instance?, Position: Vector3, Tolerance: number?): boolean
    return Is_Position_In_Rects(Position, PlotAreaMath.GetUnlockedAreaRects(Plot), Tolerance)
end

function PlotAreaMath.IsPositionInUnlockedAreaInset(Plot: Instance?, Position: Vector3, Padding: number?): boolean
    local Inset = math.max(0, Padding or 0)

    for _, Rect in PlotAreaMath.GetUnlockedAreaRects(Plot) do
        if
            Is_Position_In_Rect(Position, {
                Center = Rect.Center,
                RightDirection = Rect.RightDirection,
                FrontDirection = Rect.FrontDirection,
                HalfWidth = math.max(0, Rect.HalfWidth - Inset),
                HalfDepth = math.max(0, Rect.HalfDepth - Inset),
            }, 0)
        then
            return true
        end
    end

    return false
end

function PlotAreaMath.IsPositionInUnlockedAreaWithClearance(
    Plot: Instance?,
    Position: Vector3,
    Clearance: number?
): boolean
    return Has_Clearance_In_Rects(Position, PlotAreaMath.GetUnlockedAreaRects(Plot), math.max(0, Clearance or 0))
end

function PlotAreaMath.GetNearestPositionInUnlockedArea(Plot: Instance?, Position: Vector3, Padding: number?): Vector3?
    local BestPosition = nil
    local BestDistance = math.huge
    local Inset = math.max(0, Padding or 0)

    for _, Rect in PlotAreaMath.GetUnlockedAreaRects(Plot) do
        local Candidate = Clamp_To_Rect(Rect, Position, Inset)
        local Distance = (Vector3.new(Candidate.X, 0, Candidate.Z) - Vector3.new(Position.X, 0, Position.Z)).Magnitude

        if Distance < BestDistance then
            BestDistance = Distance
            BestPosition = Candidate
        end
    end

    return BestPosition
end

function PlotAreaMath.GetNearestPositionInUnlockedAreaWithClearance(
    Plot: Instance?,
    Position: Vector3,
    Clearance: number?
): Vector3?
    local Rects = PlotAreaMath.GetUnlockedAreaRects(Plot)
    local AppliedClearance = math.max(0, Clearance or 0)

    if Has_Clearance_In_Rects(Position, Rects, AppliedClearance) then
        return Position
    end

    local BestPosition = nil
    local BestDistance = math.huge

    for _, Rect in Rects do
        local Candidate = Clamp_To_Rect(Rect, Position, AppliedClearance)

        if not Has_Clearance_In_Rects(Candidate, Rects, AppliedClearance) then
            local Center = Get_Rect_Center(Rect)
            Candidate = Clamp_To_Rect(Rect, Vector3.new(Center.X, Position.Y, Center.Z), AppliedClearance)
        end

        if not Has_Clearance_In_Rects(Candidate, Rects, AppliedClearance) then
            continue
        end

        local Distance = (Vector3.new(Candidate.X, 0, Candidate.Z) - Vector3.new(Position.X, 0, Position.Z)).Magnitude

        if Distance < BestDistance then
            BestDistance = Distance
            BestPosition = Candidate
        end
    end

    return BestPosition or PlotAreaMath.GetNearestPositionInUnlockedArea(Plot, Position, AppliedClearance)
end

function PlotAreaMath.GetRandomPositionInUnlockedArea(Plot: Instance?, RNG: Random?, Padding: number?): Vector3?
    local Rects = PlotAreaMath.GetUnlockedAreaRects(Plot)

    if #Rects <= 0 then
        return nil
    end

    local RandomGenerator = RNG or Random.new()
    local Rect = Rects[RandomGenerator:NextInteger(1, #Rects)]
    local HalfWidth, HalfDepth = Get_Inset_Rect_Extents(Rect, Padding or 3)
    local LocalX = RandomGenerator:NextNumber(-HalfWidth, HalfWidth)
    local LocalZ = RandomGenerator:NextNumber(-HalfDepth, HalfDepth)
    local Position = Rect.Center + Rect.RightDirection * LocalX + Rect.FrontDirection * LocalZ

    return Vector3.new(Position.X, 0, Position.Z)
end

return table.freeze(PlotAreaMath)
