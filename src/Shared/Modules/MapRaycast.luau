local MapRaycast = {}

local DEFAULT_UP_DISTANCE = 120
local DEFAULT_DOWN_DISTANCE = 400
local CachedGround: Instance? = nil
local CachedRaycastParams: RaycastParams? = nil

local function Get_Ground_Instance(): Instance?
    return workspace:FindFirstChild("Ground")
end

function MapRaycast.GetRaycastParams(): RaycastParams
    local Ground = Get_Ground_Instance()

    if CachedRaycastParams and CachedGround == Ground then
        return CachedRaycastParams
    end

    local RaycastParams = RaycastParams.new()

    RaycastParams.FilterType = Enum.RaycastFilterType.Include
    RaycastParams.FilterDescendantsInstances = if Ground then { Ground } else {}
    RaycastParams.IgnoreWater = true
    CachedGround = Ground
    CachedRaycastParams = RaycastParams

    return RaycastParams
end

function MapRaycast.RaycastDown(Position: Vector3, UpDistance: number?, DownDistance: number?): RaycastResult?
    local Up = UpDistance or DEFAULT_UP_DISTANCE
    local Down = DownDistance or DEFAULT_DOWN_DISTANCE

    return workspace:Raycast(Position + Vector3.yAxis * Up, Vector3.yAxis * -(Up + Down), MapRaycast.GetRaycastParams())
end

function MapRaycast.GetGroundedPosition(
    Position: Vector3,
    FallbackY: number,
    UpDistance: number?,
    DownDistance: number?
): Vector3
    local Result = MapRaycast.RaycastDown(Position, UpDistance, DownDistance)

    if Result then
        return Result.Position
    end

    return Vector3.new(Position.X, FallbackY, Position.Z)
end

return MapRaycast
