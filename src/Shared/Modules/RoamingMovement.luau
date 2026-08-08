local RoamingMovement = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapRaycast = require(ReplicatedStorage.Shared.Modules.MapRaycast)

export type SquishyKind = "Slime" | "Dumpling"

export type MovementState = {
    CFrame: CFrame,
    IsWalking: boolean,
    JourneyIndex: number,
    Alpha: number,
}

export type JourneySegment = {
    From: Vector3,
    To: Vector3,
    IdleDuration: number,
    WalkDuration: number,
}

local TAU = math.pi * 2
local MIN_IDLE_SECONDS = 1
local MAX_IDLE_SECONDS = 5
local MIN_WALK_DISTANCE = 5
local MAX_WALK_DISTANCE = 20
local MIN_WALK_SPEED = 5
local MAX_WALK_SPEED = 11
local MAX_JOURNEYS_PER_STEP = 256
local RAYCAST_HEIGHT = 250
local RAYCAST_DISTANCE = 1_000
local MAX_RANDOM_SEED = 2_147_483_647

local function Normalize_Seed(Seed: number): number
    local Normalized = math.floor(math.abs(Seed)) % MAX_RANDOM_SEED

    if Normalized <= 0 then
        return 1
    end

    return Normalized
end

local function Create_Random(Seed: number, ServerEntity: number, SpawnTime: number, JourneyIndex: number): Random
    local SpawnTimeSeed = math.floor(SpawnTime * 1_000)
    local RawSeed = Seed + (ServerEntity * 9_973) + (SpawnTimeSeed * 37) + (JourneyIndex * 104_729)

    return Random.new(Normalize_Seed(RawSeed))
end

local function Raycast_To_Ground(Position: Vector3, _SpawnBox: BasePart, BaseY: number): Vector3
    return MapRaycast.GetGroundedPosition(Position, BaseY, RAYCAST_HEIGHT, RAYCAST_DISTANCE - RAYCAST_HEIGHT)
end

local function Get_Random_Point_In_Box(RNG: Random, SpawnBox: BasePart, BaseY: number): Vector3
    local Half_Size = SpawnBox.Size * 0.5
    local Local_X = RNG:NextNumber(-Half_Size.X, Half_Size.X)
    local Local_Z = RNG:NextNumber(-Half_Size.Z, Half_Size.Z)
    local World_Position = SpawnBox.CFrame:PointToWorldSpace(Vector3.new(Local_X, 0, Local_Z))

    return Raycast_To_Ground(World_Position, SpawnBox, BaseY)
end

local function Get_Target_Position(Current_Position: Vector3, RNG: Random, SpawnBox: BasePart, BaseY: number): Vector3
    local Distance = RNG:NextNumber(MIN_WALK_DISTANCE, MAX_WALK_DISTANCE)
    local Angle = RNG:NextNumber(0, TAU)
    local Half_Size = SpawnBox.Size * 0.5
    local Current_Local_Position = SpawnBox.CFrame:PointToObjectSpace(Current_Position)
    local Target_Local_Position = Vector3.new(
        math.clamp(Current_Local_Position.X + math.cos(Angle) * Distance, -Half_Size.X, Half_Size.X),
        0,
        math.clamp(Current_Local_Position.Z + math.sin(Angle) * Distance, -Half_Size.Z, Half_Size.Z)
    )
    local Target_World_Position = SpawnBox.CFrame:PointToWorldSpace(Target_Local_Position)

    return Raycast_To_Ground(Target_World_Position, SpawnBox, BaseY)
end

local function Get_Movement_CFrame(Position: Vector3, Target_Position: Vector3): CFrame
    local Direction = Vector3.new(Target_Position.X - Position.X, 0, Target_Position.Z - Position.Z)

    if Direction.Magnitude <= 0.01 then
        return CFrame.new(Position)
    end

    return CFrame.lookAt(Position, Position + Direction.Unit)
end

function RoamingMovement.GetInitialPosition(
    Seed: number,
    ServerEntity: number,
    SpawnTime: number,
    SpawnBox: BasePart,
    BaseY: number
): Vector3
    return Get_Random_Point_In_Box(Create_Random(Seed, ServerEntity, SpawnTime, 0), SpawnBox, BaseY)
end

function RoamingMovement.GetJourneySegment(
    Seed: number,
    ServerEntity: number,
    SpawnTime: number,
    JourneyIndex: number,
    CurrentPosition: Vector3,
    SpawnBox: BasePart,
    BaseY: number
): JourneySegment
    local RNG = Create_Random(Seed, ServerEntity, SpawnTime, JourneyIndex)
    local Idle_Duration = RNG:NextNumber(MIN_IDLE_SECONDS, MAX_IDLE_SECONDS)
    local Target_Position = Get_Target_Position(CurrentPosition, RNG, SpawnBox, BaseY)
    local Walk_Distance = (Target_Position - CurrentPosition).Magnitude
    local Walk_Speed = RNG:NextNumber(MIN_WALK_SPEED, MAX_WALK_SPEED)

    return {
        From = CurrentPosition,
        To = Target_Position,
        IdleDuration = Idle_Duration,
        WalkDuration = math.max(Walk_Distance / Walk_Speed, 0.05),
    }
end

function RoamingMovement.GetStateFromSegment(
    Segment: JourneySegment,
    JourneyIndex: number,
    ElapsedInSegment: number
): MovementState
    if ElapsedInSegment <= Segment.IdleDuration then
        return {
            CFrame = Get_Movement_CFrame(Segment.From, Segment.To),
            IsWalking = false,
            JourneyIndex = JourneyIndex,
            Alpha = 0,
        }
    end

    local Walk_Elapsed = ElapsedInSegment - Segment.IdleDuration
    local Alpha = math.clamp(Walk_Elapsed / Segment.WalkDuration, 0, 1)
    local Position = Segment.From:Lerp(Segment.To, Alpha)

    return {
        CFrame = Get_Movement_CFrame(Position, Segment.To),
        IsWalking = Alpha < 1,
        JourneyIndex = JourneyIndex,
        Alpha = Alpha,
    }
end

function RoamingMovement.GetState(
    Seed: number,
    ServerEntity: number,
    SpawnTime: number,
    Lifetime: number,
    Now: number,
    SpawnBox: BasePart,
    BaseY: number,
    InitialPosition: Vector3?
): MovementState?
    local Elapsed = Now - SpawnTime

    if Elapsed < 0 or Elapsed > Lifetime then
        return nil
    end

    local Current_Position = InitialPosition
        or RoamingMovement.GetInitialPosition(Seed, ServerEntity, SpawnTime, SpawnBox, BaseY)
    local Remaining_Time = Elapsed

    for JourneyIndex = 1, MAX_JOURNEYS_PER_STEP do
        local Segment = RoamingMovement.GetJourneySegment(
            Seed,
            ServerEntity,
            SpawnTime,
            JourneyIndex,
            Current_Position,
            SpawnBox,
            BaseY
        )
        local Segment_Duration = Segment.IdleDuration + Segment.WalkDuration

        if Remaining_Time <= Segment_Duration then
            return RoamingMovement.GetStateFromSegment(Segment, JourneyIndex, Remaining_Time)
        end

        Remaining_Time -= Segment_Duration
        Current_Position = Segment.To
    end

    return {
        CFrame = CFrame.new(Current_Position),
        IsWalking = false,
        JourneyIndex = MAX_JOURNEYS_PER_STEP,
        Alpha = 0,
    }
end

function RoamingMovement.GetCurrentCFrame(
    Seed: number,
    ServerEntity: number,
    SpawnTime: number,
    Lifetime: number,
    Now: number,
    SpawnBox: BasePart,
    BaseY: number,
    InitialPosition: Vector3?
): CFrame?
    local State =
        RoamingMovement.GetState(Seed, ServerEntity, SpawnTime, Lifetime, Now, SpawnBox, BaseY, InitialPosition)

    if not State then
        return nil
    end

    return State.CFrame
end

function RoamingMovement.GetCurrentPosition(
    Seed: number,
    ServerEntity: number,
    SpawnTime: number,
    Lifetime: number,
    Now: number,
    SpawnBox: BasePart,
    BaseY: number,
    InitialPosition: Vector3?
): Vector3?
    local Current_CFrame =
        RoamingMovement.GetCurrentCFrame(Seed, ServerEntity, SpawnTime, Lifetime, Now, SpawnBox, BaseY, InitialPosition)

    if not Current_CFrame then
        return nil
    end

    return Current_CFrame.Position
end

return table.freeze(RoamingMovement)
