local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local TutorialProgress = require(ServerScriptService.Server.Modules.TutorialProgress)

local CatchConfig = require(ReplicatedStorage.Shared.Modules.CatchConfig)
local Components = require(ReplicatedStorage.Shared.Components)
local EventMutations = require(ReplicatedStorage.Shared.Modules.EventMutations)
local InventoryCapacity = require(ReplicatedStorage.Shared.Modules.InventoryCapacity)
local InventoryMath = require(ReplicatedStorage.Shared.Modules.InventoryMath)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local MapRaycast = require(ReplicatedStorage.Shared.Modules.MapRaycast)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local RoamingSquishies = require(script.Parent.RoamingSquishies)
local Squishies = require(ReplicatedStorage.Shared.Modules.Squishies)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)
local World = require(ReplicatedStorage.Shared.World)

type Attempt = {
    Player: Player,
    PlayerEntity: number,
    TargetEntity: number,
    CatchId: string,
    Progress: number,
    LastUpdateTime: number,
    LastClickTime: number,
    LastClickAcceptedTime: number,
    LastProgressSentTime: number,
    LastProgressSent: number,
    LassoStrength: number,
    Difficulty: number,
    ClicksNeeded: number,
    ProgressPerClick: number,
    DrainChunk: number,
    DrainInterval: number,
    AutoFailThreshold: number,
    AutoFailDuration: number,
    TimeSinceLastDrain: number,
    TimeBelowThreshold: number,
    TargetStrength: number,
    TargetWeight: number,
    TargetBaseIncomePerSec: number,
    TargetIncomePerSec: number,
    Rarity: string,
    Kind: string,
    TargetName: string,
    TargetMutation: string,
    TargetEventMutations: { string },
    TargetImage: string,
    LassoName: string,
    Locked: boolean,
    Completed: boolean,
}

local AttemptsById: { [string]: Attempt } = {}
local AttemptsByPlayer: { [Player]: Attempt } = {}
local AttemptsByTarget: { [number]: { [Player]: Attempt } } = {}
local TargetLocks: { [number]: Attempt } = {}
local CompletedTargets: { [number]: boolean } = {}
local WildSquishies = World:query(Components.Renderable):with(Components.Tags.WildSquishy):cached()

local PROGRESS_SEND_INTERVAL = 0.08
local PROGRESS_SEND_EPSILON = 0.004
local PULL_TARGET_USER_ID_ATTRIBUTE = "PullTargetUserId"
local PULL_PROGRESS_ATTRIBUTE = "PullProgress"
local PULL_ANCHOR_X_ATTRIBUTE = "PullAnchorX"
local PULL_ANCHOR_Y_ATTRIBUTE = "PullAnchorY"
local PULL_ANCHOR_Z_ATTRIBUTE = "PullAnchorZ"
local PULL_LASSO_NAME_ATTRIBUTE = "PullLassoName"
local CATCH_COMPLETE_ID_ATTRIBUTE = "CatchCompleteId"
local ROAM_START_X_ATTRIBUTE = "RoamStartX"
local ROAM_START_Y_ATTRIBUTE = "RoamStartY"
local ROAM_START_Z_ATTRIBUTE = "RoamStartZ"
local CUSTOM_HOTBAR_SLOTS = { 3, 4, 5, 6, 7 }
local Clear_Target_Catch_State: ((number, string?) -> ())? = nil

local function Notify(
    Player: Player,
    Text: string,
    Type: "Success" | "Info" | "Warning" | "Error" | "Reward" | "Announcement",
    Duration: number?
)
    if Text == "" then
        return
    end

    Network.Notification.Fire(Player, {
        Text = Text,
        Duration = Duration or 3,
        Type = Type,
    })
end

local function Reject(Player: Player, Reason: "Invalid" | "Locked" | "Lost" | "Cancelled", Message: string)
    if Message ~= "" and (Reason == "Locked" or Reason == "Lost") then
        Notify(Player, Message, "Error", 3)
    end

    Network.CatchCancelled.Fire(Player, {
        CatchId = "",
        Reason = Reason,
        Message = Message,
    })
end

local function Is_Finite_Number(Value: number?): boolean
    return type(Value) == "number" and Value == Value and Value > -math.huge and Value < math.huge
end

local function Get_Player_Entity(Player: Player): number?
    local Entity = Registry.Get("Players", Player)

    if not Entity or not World:contains(Entity) then
        return nil
    end

    return Entity
end

local function Get_Character(Player: Player): Model?
    local Character = Player.Character

    if Character and Character.Parent then
        return Character
    end

    return nil
end

local function Get_Character_Root(Player: Player): BasePart?
    local Character = Get_Character(Player)

    if not Character then
        return nil
    end

    local Root = Character:FindFirstChild("HumanoidRootPart")
        or Character:FindFirstChild("Root")
        or Character.PrimaryPart

    if Root and Root:IsA("BasePart") then
        return Root
    end

    return nil
end

local function Get_Target_Model(TargetEntity: number): Model?
    local Model = World:get(TargetEntity, Components.Renderable)

    if Model and Model:IsA("Model") and Model.Parent then
        return Model
    end

    return nil
end

local function Get_Target_Rarity(TargetEntity: number): string?
    local Kind = World:get(TargetEntity, Components.Kind)
    local TargetName = World:get(TargetEntity, Components.Name)

    if type(Kind) ~= "string" or type(TargetName) ~= "string" then
        return nil
    end

    local SquishyData = Squishies.GetData(Kind :: any, TargetName)

    return if SquishyData then SquishyData.Rarity else nil
end

local function Has_Tutorial_Role(PlayerEntity: number, Role: string): boolean
    for _, Items in
        {
            World:get(PlayerEntity, Components.OwnedSquishies),
            World:get(PlayerEntity, Components.PlotSquishies),
        }
    do
        if type(Items) ~= "table" then
            continue
        end

        for _, Item in Items do
            if type(Item) == "table" and Item.TutorialRole == Role then
                return true
            end
        end
    end

    return false
end

local function Get_Tutorial_Target_Block_Message(Player: Player, TargetEntity: number): string?
    local Model = Get_Target_Model(TargetEntity)
    local TargetTutorialUserId = Model and Model:GetAttribute(TutorialSteps.TargetUserIdAttribute)

    if type(TargetTutorialUserId) == "number" and TargetTutorialUserId ~= Player.UserId then
        return "That's a tutorial Squishy."
    end

    return nil
end

local function Can_Select_Target_For_Player(Player: Player, PlayerEntity: number, TargetEntity: number): boolean
    local Model = Get_Target_Model(TargetEntity)
    local TargetTutorialUserId = Model and Model:GetAttribute(TutorialSteps.TargetUserIdAttribute)
    local TargetTutorialStep = Model and Model:GetAttribute(TutorialSteps.TargetStepAttribute)

    if TutorialProgress.Is_Complete(PlayerEntity) then
        return type(TargetTutorialUserId) ~= "number" or TargetTutorialUserId == Player.UserId
    end

    local TutorialStep = TutorialProgress.Get(PlayerEntity)

    if not TutorialSteps.Is_Catch_Step(TutorialStep) then
        return false
    end

    if
        (TutorialStep == TutorialSteps.CatchFirst and Has_Tutorial_Role(PlayerEntity, TutorialSteps.FirstRole))
        or (TutorialStep == TutorialSteps.CatchStrong and Has_Tutorial_Role(PlayerEntity, TutorialSteps.StrongRole))
    then
        return false
    end

    if type(TargetTutorialUserId) == "number" and TargetTutorialUserId ~= Player.UserId then
        return false
    end

    if type(TargetTutorialStep) == "number" and TargetTutorialStep ~= TutorialStep then
        return false
    end

    return TutorialSteps.Is_Catch_Rarity_Allowed(TutorialStep, Get_Target_Rarity(TargetEntity))
end

local function Get_Target_Position(TargetEntity: number): Vector3?
    local RoamingPosition = RoamingSquishies.GetCurrentPosition(TargetEntity)

    if RoamingPosition then
        return RoamingPosition
    end

    local Model = Get_Target_Model(TargetEntity)

    if Model then
        return Model:GetPivot().Position
    end

    return nil
end

local function Get_Grounded_Position(Position: Vector3, FallbackY: number): Vector3
    return MapRaycast.GetGroundedPosition(Position, FallbackY, 120, 400)
end

local function Get_Aim_Ray(Data: {
    AimOriginX: number,
    AimOriginY: number,
    AimOriginZ: number,
    AimDirectionX: number,
    AimDirectionY: number,
    AimDirectionZ: number,
}): (Vector3?, Vector3?)
    if
        not Is_Finite_Number(Data.AimOriginX)
        or not Is_Finite_Number(Data.AimOriginY)
        or not Is_Finite_Number(Data.AimOriginZ)
        or not Is_Finite_Number(Data.AimDirectionX)
        or not Is_Finite_Number(Data.AimDirectionY)
        or not Is_Finite_Number(Data.AimDirectionZ)
    then
        return nil, nil
    end

    local Origin = Vector3.new(Data.AimOriginX, Data.AimOriginY, Data.AimOriginZ)
    local Direction = Vector3.new(Data.AimDirectionX, Data.AimDirectionY, Data.AimDirectionZ)
    local FlatDirection = Vector3.new(Direction.X, 0, Direction.Z)

    if FlatDirection.Magnitude < 0.001 then
        return nil, nil
    end

    return Origin, FlatDirection.Unit
end

local function Get_Target_Hit_Box(TargetEntity: number): (CFrame?, Vector3?)
    local Model = Get_Target_Model(TargetEntity)

    if not Model then
        return nil, nil
    end

    local CurrentCFrame = RoamingSquishies.GetCurrentCFrame(TargetEntity)
    local ModelPivot = Model:GetPivot()
    local ModelBoxCFrame, ModelSize = Model:GetBoundingBox()
    local BoxOffset = ModelPivot:ToObjectSpace(ModelBoxCFrame)
    local BoxCFrame = (CurrentCFrame or ModelPivot) * BoxOffset
    local Padding = CatchConfig.ThrowHitPadding
    local HitSize = ModelSize + Vector3.new(Padding * 2, Padding * 2, Padding * 2)

    return BoxCFrame, HitSize
end

local function Get_Target_Aim_Radius(TargetEntity: number): number?
    local Model = Get_Target_Model(TargetEntity)

    if not Model then
        return nil
    end

    local _, BoxSize = Model:GetBoundingBox()

    return math.max(BoxSize.X, BoxSize.Y, BoxSize.Z) * 0.5 + CatchConfig.ThrowAutoAimRadius
end

local function Get_Path_Sphere_Hit_Distance(
    Origin: Vector3,
    Direction: Vector3,
    Center: Vector3,
    Radius: number
): number?
    local FlatCenter = Vector3.new(Center.X, Origin.Y, Center.Z)
    local Offset = FlatCenter - Origin
    local DistanceAlongPath = Offset:Dot(Direction)

    if DistanceAlongPath < 0 or DistanceAlongPath > CatchConfig.ThrowDistance then
        return nil
    end

    local ClosestPoint = Origin + Direction * DistanceAlongPath

    if (FlatCenter - ClosestPoint).Magnitude > Radius then
        return nil
    end

    return math.max(0, DistanceAlongPath - Radius)
end

local function Get_Path_Box_Hit_Distance(
    Origin: Vector3,
    Direction: Vector3,
    BoxCFrame: CFrame,
    BoxSize: Vector3
): number?
    local LocalOrigin = BoxCFrame:PointToObjectSpace(Origin)
    local LocalDirection = BoxCFrame:VectorToObjectSpace(Direction)
    local HalfSize = BoxSize * 0.5
    local EntryDistance = 0
    local ExitDistance = CatchConfig.ThrowDistance

    local function Check_Axis(OriginAxis: number, DirectionAxis: number, HalfAxis: number): boolean
        if math.abs(DirectionAxis) < 0.0001 then
            return math.abs(OriginAxis) <= HalfAxis
        end

        local NearDistance = (-HalfAxis - OriginAxis) / DirectionAxis
        local FarDistance = (HalfAxis - OriginAxis) / DirectionAxis

        if NearDistance > FarDistance then
            NearDistance, FarDistance = FarDistance, NearDistance
        end

        EntryDistance = math.max(EntryDistance, NearDistance)
        ExitDistance = math.min(ExitDistance, FarDistance)

        return EntryDistance <= ExitDistance
    end

    if not Check_Axis(LocalOrigin.X, LocalDirection.X, HalfSize.X) then
        return nil
    end

    if not Check_Axis(LocalOrigin.Z, LocalDirection.Z, HalfSize.Z) then
        return nil
    end

    if EntryDistance < 0 or EntryDistance > CatchConfig.ThrowDistance then
        return nil
    end

    return EntryDistance
end

local function Find_Target_On_Aim_Path(
    Player: Player,
    PlayerEntity: number,
    Origin: Vector3,
    Direction: Vector3
): (number?, string?)
    local Root = Get_Character_Root(Player)

    if not Root then
        return nil
    end

    if (Root.Position - Origin).Magnitude > CatchConfig.MaxAimOriginDistance then
        return nil
    end

    local BestTargetEntity: number? = nil
    local BestDistanceAlongPath = math.huge
    local BestBlockedMessage: string? = nil
    local BestBlockedDistance = math.huge

    for TargetEntity in WildSquishies:iter() do
        if CompletedTargets[TargetEntity] or not World:contains(TargetEntity) then
            continue
        end

        if not World:has(TargetEntity, Components.Tags.WildSquishy) or not Get_Target_Model(TargetEntity) then
            continue
        end

        local TargetPosition = Get_Target_Position(TargetEntity)

        if not TargetPosition then
            continue
        end

        if (Root.Position - TargetPosition).Magnitude > CatchConfig.MaxStartDistance then
            continue
        end

        local AimRadius = Get_Target_Aim_Radius(TargetEntity)
        local DistanceAlongPath = if AimRadius
            then Get_Path_Sphere_Hit_Distance(Origin, Direction, TargetPosition, AimRadius)
            else nil

        if not DistanceAlongPath then
            local BoxCFrame, BoxSize = Get_Target_Hit_Box(TargetEntity)

            if BoxCFrame and BoxSize then
                DistanceAlongPath = Get_Path_Box_Hit_Distance(Origin, Direction, BoxCFrame, BoxSize)
            end
        end

        if not DistanceAlongPath then
            continue
        end

        local BlockedMessage = Get_Tutorial_Target_Block_Message(Player, TargetEntity)

        if BlockedMessage and DistanceAlongPath < BestBlockedDistance then
            BestBlockedMessage = BlockedMessage
            BestBlockedDistance = DistanceAlongPath
        end

        if not Can_Select_Target_For_Player(Player, PlayerEntity, TargetEntity) then
            continue
        end

        if DistanceAlongPath and DistanceAlongPath < BestDistanceAlongPath then
            BestTargetEntity = TargetEntity
            BestDistanceAlongPath = DistanceAlongPath
        end
    end

    return BestTargetEntity, BestBlockedMessage
end

local function Is_Target_Valid(TargetEntity: number): boolean
    if CompletedTargets[TargetEntity] then
        return false
    end

    if not World:contains(TargetEntity) then
        return false
    end

    if not World:has(TargetEntity, Components.Tags.WildSquishy) then
        return false
    end

    return Get_Target_Model(TargetEntity) ~= nil
end

local function Is_In_Range(Player: Player, TargetEntity: number, MaxDistance: number): boolean
    local Root = Get_Character_Root(Player)
    local TargetPosition = Get_Target_Position(TargetEntity)

    if not Root or not TargetPosition then
        return false
    end

    return (Root.Position - TargetPosition).Magnitude <= MaxDistance
end

local function Get_Selected_Lasso_Data(PlayerEntity: number): Lassos.LassoData
    local OwnedLassos = Lassos.Normalize_Owned(World:get(PlayerEntity, Components.OwnedLassos))
    local LassoName = Lassos.Normalize_Selected(World:get(PlayerEntity, Components.Lasso), OwnedLassos)
    local LassoData = Lassos.Get(LassoName) or Lassos.Get(Lassos.Default)

    World:set(PlayerEntity, Components.OwnedLassos, OwnedLassos)
    World:set(PlayerEntity, Components.Lasso, if LassoData then LassoData.Name else Lassos.Default)

    return (LassoData :: any) :: Lassos.LassoData
end

local function Broadcast_Lasso_Throw(
    Player: Player,
    Data: {
        AimOriginX: number,
        AimOriginY: number,
        AimOriginZ: number,
        AimDirectionX: number,
        AimDirectionY: number,
        AimDirectionZ: number,
    }
)
    local AimOrigin, AimDirection = Get_Aim_Ray(Data)

    if not AimOrigin or not AimDirection then
        return
    end

    local Root = Get_Character_Root(Player)

    if not Root or (Root.Position - AimOrigin).Magnitude > CatchConfig.MaxAimOriginDistance then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return
    end

    local LassoData = Get_Selected_Lasso_Data(PlayerEntity)

    Network.LassoThrowVisual.FireAll({
        PlayerUserId = Player.UserId,
        LassoName = LassoData.Name,
        AimOriginX = AimOrigin.X,
        AimOriginY = AimOrigin.Y,
        AimOriginZ = AimOrigin.Z,
        AimDirectionX = AimDirection.X,
        AimDirectionY = AimDirection.Y,
        AimDirectionZ = AimDirection.Z,
    })
end

local function Set_Attempt_Progress(Attempt: Attempt, Progress: number)
    Attempt.Progress = math.clamp(Progress, 0, 1)
end

local function Get_Best_Target_Attempt(TargetEntity: number): Attempt?
    local TargetAttempts = AttemptsByTarget[TargetEntity]
    local BestAttempt: Attempt? = nil
    local BestProgress = -math.huge

    if not TargetAttempts then
        return nil
    end

    for _, Attempt in TargetAttempts do
        if Attempt.Completed or not AttemptsById[Attempt.CatchId] then
            continue
        end

        if Attempt.Progress > BestProgress then
            BestAttempt = Attempt
            BestProgress = Attempt.Progress
        end
    end

    return BestAttempt
end

local function Clear_Target_Pull_Attributes(Model: Model)
    Model:SetAttribute(PULL_TARGET_USER_ID_ATTRIBUTE, nil)
    Model:SetAttribute(PULL_PROGRESS_ATTRIBUTE, nil)
    Model:SetAttribute(PULL_ANCHOR_X_ATTRIBUTE, nil)
    Model:SetAttribute(PULL_ANCHOR_Y_ATTRIBUTE, nil)
    Model:SetAttribute(PULL_ANCHOR_Z_ATTRIBUTE, nil)
    Model:SetAttribute(PULL_LASSO_NAME_ATTRIBUTE, nil)
end

local function Get_Model_Pull_Anchor_Position(Model: Model): Vector3?
    local AnchorX = Model:GetAttribute(PULL_ANCHOR_X_ATTRIBUTE)
    local AnchorY = Model:GetAttribute(PULL_ANCHOR_Y_ATTRIBUTE)
    local AnchorZ = Model:GetAttribute(PULL_ANCHOR_Z_ATTRIBUTE)

    if type(AnchorX) ~= "number" or type(AnchorY) ~= "number" or type(AnchorZ) ~= "number" then
        return nil
    end

    return Vector3.new(AnchorX, AnchorY, AnchorZ)
end

local function Reset_Target_Roaming_From_Position(TargetEntity: number, Position: Vector3)
    if not World:contains(TargetEntity) then
        return
    end

    local SpawnTime = World:get(TargetEntity, Components.SpawnTime)
    local Lifetime = World:get(TargetEntity, Components.Lifetime)

    if type(SpawnTime) ~= "number" or type(Lifetime) ~= "number" then
        return
    end

    local Model = Get_Target_Model(TargetEntity)
    local Now = workspace:GetServerTimeNow()
    local DespawnTime = SpawnTime + Lifetime
    local RemainingLifetime = math.max(DespawnTime - Now, 0.05)
    local GroundedPosition = Get_Grounded_Position(Position, Position.Y)

    World:set(TargetEntity, Components.SpawnTime, Now)
    World:set(TargetEntity, Components.Lifetime, RemainingLifetime)
    World:set(TargetEntity, Components.BaseY, GroundedPosition.Y)

    if Model then
        Model:SetAttribute("SpawnTime", Now)
        Model:SetAttribute("Lifetime", RemainingLifetime)
        Model:SetAttribute("BaseY", GroundedPosition.Y)
        Model:SetAttribute("DespawnTime", Now + RemainingLifetime)
        Model:SetAttribute(ROAM_START_X_ATTRIBUTE, GroundedPosition.X)
        Model:SetAttribute(ROAM_START_Y_ATTRIBUTE, GroundedPosition.Y)
        Model:SetAttribute(ROAM_START_Z_ATTRIBUTE, GroundedPosition.Z)
        Model:PivotTo(CFrame.new(GroundedPosition) * Model:GetPivot().Rotation)
    end
end

local function Update_Target_Pull_State(TargetEntity: number)
    if not World:contains(TargetEntity) then
        return
    end

    local BestAttempt = Get_Best_Target_Attempt(TargetEntity)
    local Model = Get_Target_Model(TargetEntity)

    if not BestAttempt then
        if Model then
            local ReleaseCFrame = RoamingSquishies.GetCurrentCFrame(TargetEntity)
            local ReleasePosition = if ReleaseCFrame
                then ReleaseCFrame.Position
                else Get_Model_Pull_Anchor_Position(Model) or Model:GetPivot().Position

            Reset_Target_Roaming_From_Position(TargetEntity, ReleasePosition)
            Clear_Target_Pull_Attributes(Model)
        end

        if not TargetLocks[TargetEntity] and Clear_Target_Catch_State then
            Clear_Target_Catch_State(TargetEntity, nil)
        end

        return
    end

    if Model then
        if type(Model:GetAttribute(PULL_ANCHOR_X_ATTRIBUTE)) ~= "number" then
            local AnchorPosition = Get_Target_Position(TargetEntity) or Model:GetPivot().Position
            AnchorPosition = Get_Grounded_Position(AnchorPosition, AnchorPosition.Y)

            Model:SetAttribute(PULL_ANCHOR_X_ATTRIBUTE, AnchorPosition.X)
            Model:SetAttribute(PULL_ANCHOR_Y_ATTRIBUTE, AnchorPosition.Y)
            Model:SetAttribute(PULL_ANCHOR_Z_ATTRIBUTE, AnchorPosition.Z)
        end

        Model:SetAttribute(PULL_TARGET_USER_ID_ATTRIBUTE, BestAttempt.Player.UserId)
        Model:SetAttribute(PULL_PROGRESS_ATTRIBUTE, BestAttempt.Progress)
        Model:SetAttribute(PULL_LASSO_NAME_ATTRIBUTE, BestAttempt.LassoName)
    end

    World:set(TargetEntity, Components.CatchProgress, BestAttempt.Progress)
    World:set(TargetEntity, Components.CatchId, BestAttempt.CatchId)
end

local function Remove_Attempt_From_Target(Attempt: Attempt)
    local TargetAttempts = AttemptsByTarget[Attempt.TargetEntity]

    if not TargetAttempts then
        return
    end

    TargetAttempts[Attempt.Player] = nil

    if next(TargetAttempts) == nil then
        AttemptsByTarget[Attempt.TargetEntity] = nil
    end
end

Clear_Target_Catch_State = function(TargetEntity: number, CatchId: string?)
    local LockedAttempt = TargetLocks[TargetEntity]

    if LockedAttempt and CatchId and LockedAttempt.CatchId ~= CatchId then
        return
    end

    TargetLocks[TargetEntity] = nil

    if World:contains(TargetEntity) then
        if World:has(TargetEntity, Components.LockedBy) then
            World:remove(TargetEntity, Components.LockedBy)
        end

        if World:has(TargetEntity, Components.CatchProgress) then
            World:remove(TargetEntity, Components.CatchProgress)
        end

        if World:has(TargetEntity, Components.CatchId) then
            World:remove(TargetEntity, Components.CatchId)
        end
    end
end

local function Remove_Attempt(Attempt: Attempt, ReleaseLock: boolean)
    AttemptsById[Attempt.CatchId] = nil

    if AttemptsByPlayer[Attempt.Player] == Attempt then
        AttemptsByPlayer[Attempt.Player] = nil
    end

    local TargetEntity = Attempt.TargetEntity

    Remove_Attempt_From_Target(Attempt)
    Update_Target_Pull_State(TargetEntity)

    local ClearTargetCatchState = Clear_Target_Catch_State

    if ReleaseLock and TargetLocks[Attempt.TargetEntity] == Attempt and ClearTargetCatchState then
        ClearTargetCatchState(Attempt.TargetEntity, Attempt.CatchId)
    end
end

local function Unlock_Attempt(Attempt: Attempt)
    if not Attempt.Locked then
        return
    end

    Attempt.Locked = false

    if TargetLocks[Attempt.TargetEntity] == Attempt then
        TargetLocks[Attempt.TargetEntity] = nil
    end

    if World:contains(Attempt.TargetEntity) then
        if World:has(Attempt.TargetEntity, Components.LockedBy) then
            World:remove(Attempt.TargetEntity, Components.LockedBy)
        end

        World:set(Attempt.TargetEntity, Components.CatchProgress, Attempt.Progress)
        World:set(Attempt.TargetEntity, Components.CatchId, Attempt.CatchId)
    end

    Update_Target_Pull_State(Attempt.TargetEntity)
end

local function Send_Progress(Attempt: Attempt, Force: boolean, TweenTime: number?)
    local Now = workspace:GetServerTimeNow()

    if
        not Force
        and Now - Attempt.LastProgressSentTime < PROGRESS_SEND_INTERVAL
        and math.abs(Attempt.Progress - Attempt.LastProgressSent) < PROGRESS_SEND_EPSILON
    then
        return
    end

    Attempt.LastProgressSentTime = Now
    Attempt.LastProgressSent = Attempt.Progress

    Network.CatchProgress.Fire(Attempt.Player, {
        CatchId = Attempt.CatchId,
        Progress = Attempt.Progress,
        TweenTime = TweenTime,
    })
end

local function Cancel_Attempt(
    Attempt: Attempt,
    Reason: "Invalid" | "Locked" | "Lost" | "Cancelled",
    Message: string,
    ShouldNotify: boolean
)
    if Attempt.Completed then
        return
    end

    Remove_Attempt(Attempt, true)

    if ShouldNotify then
        Notify(Attempt.Player, Message, "Error", 3)
    end

    Network.CatchCancelled.Fire(Attempt.Player, {
        CatchId = Attempt.CatchId,
        Reason = Reason,
        Message = Message,
    })
end

local function Cancel_Player_Attempt(Player: Player)
    local PreviousAttempt = AttemptsByPlayer[Player]

    if PreviousAttempt then
        Cancel_Attempt(PreviousAttempt, "Cancelled", "", false)
    end
end

local function Lock_Attempt(Attempt: Attempt)
    if Attempt.Locked then
        return
    end

    local ExistingLock = TargetLocks[Attempt.TargetEntity]

    if ExistingLock and ExistingLock ~= Attempt then
        Cancel_Attempt(Attempt, "Locked", "That target was locked by another player.", true)
        return
    end

    Attempt.Locked = true
    TargetLocks[Attempt.TargetEntity] = Attempt

    if World:contains(Attempt.TargetEntity) then
        World:set(Attempt.TargetEntity, Components.LockedBy, Attempt.Player.UserId)
        World:set(Attempt.TargetEntity, Components.CatchId, Attempt.CatchId)
        World:set(Attempt.TargetEntity, Components.CatchProgress, Attempt.Progress)
    end

    Update_Target_Pull_State(Attempt.TargetEntity)

    Network.CatchLocked.Fire(Attempt.Player, {
        CatchId = Attempt.CatchId,
    })

    local TargetAttempts = AttemptsByTarget[Attempt.TargetEntity]

    if not TargetAttempts then
        return
    end

    for _, OtherAttempt in TargetAttempts do
        if OtherAttempt == Attempt then
            continue
        end

        Cancel_Attempt(OtherAttempt, "Locked", `{Attempt.Player.DisplayName} locked this target first.`, true)
    end
end

local function Stop_Target_Roaming(TargetEntity: number)
    if not World:contains(TargetEntity) then
        return
    end

    if World:has(TargetEntity, Components.Tags.Roaming) then
        World:remove(TargetEntity, Components.Tags.Roaming)
    end

    if World:has(TargetEntity, Components.SpawnTime) then
        World:remove(TargetEntity, Components.SpawnTime)
    end

    if World:has(TargetEntity, Components.Lifetime) then
        World:remove(TargetEntity, Components.Lifetime)
    end

    if World:has(TargetEntity, Components.BaseY) then
        World:remove(TargetEntity, Components.BaseY)
    end
end

local function Get_First_Open_Custom_Hotbar_Slot(PlayerEntity: number): (number?, { [string]: any })
    local HotbarSlots = {}
    local OccupiedSlots = {}
    local ExistingHotbarSlots = World:get(PlayerEntity, Components.HotbarSlots)

    if type(ExistingHotbarSlots) == "table" then
        for Key, Assignment in ExistingHotbarSlots do
            if
                type(Assignment) == "table"
                and type(Assignment.Slot) == "number"
                and type(Assignment.ItemId) == "string"
                and type(Assignment.ItemType) == "string"
            then
                local Slot = Assignment.Slot

                if Slot >= 3 and Slot <= 7 and math.floor(Slot) == Slot then
                    HotbarSlots[tostring(Slot)] = {
                        Slot = Slot,
                        ItemId = Assignment.ItemId,
                        ItemType = Assignment.ItemType,
                    }
                    OccupiedSlots[Slot] = true
                else
                    HotbarSlots[tostring(Key)] = table.clone(Assignment)
                end
            end
        end
    end

    for _, Slot in CUSTOM_HOTBAR_SLOTS do
        if not OccupiedSlots[Slot] then
            return Slot, HotbarSlots
        end
    end

    return nil, HotbarSlots
end

local function Add_Caught_Squishy(Attempt: Attempt): (string?, number?)
    local OwnedSquishies = World:get(Attempt.PlayerEntity, Components.OwnedSquishies)
    local Result = {}
    local NewId = HttpService:GenerateGUID(false)
    local NewHotbarSlot, HotbarSlots = Get_First_Open_Custom_Hotbar_Slot(Attempt.PlayerEntity)
    local IndexKey = Squishies.GetKey(Attempt.Kind :: any, Attempt.TargetName)

    if type(OwnedSquishies) == "table" then
        for _, Entry in OwnedSquishies do
            table.insert(Result, Entry)
        end
    end

    if not InventoryCapacity.CanAddSquishies(Result, 1) then
        Notify(Attempt.Player, InventoryCapacity.SquishyInventoryFullMessage, "Error", 3)
        return nil, nil
    end

    local NewItem = {
        Id = NewId,
        Type = "Squishy",
        Kind = Attempt.Kind,
        Name = Attempt.TargetName,
        Rarity = Attempt.Rarity,
        Image = Attempt.TargetImage,
        BaseIncomePerSec = Attempt.TargetBaseIncomePerSec,
        FinalIncomePerSec = 0,
        Weight = Attempt.TargetWeight,
        IncomePerSec = 0,
        Mutation = InventoryMath.NormalizeMutation(Attempt.TargetMutation, Attempt.Kind),
        EventMutations = EventMutations.NormalizeList(Attempt.TargetEventMutations),
        Level = 0,
        XP = 0,
        Equipped = false,
        Favorite = false,
        HotbarSlot = NewHotbarSlot,
        CaughtAt = os.time(),
    }

    local TutorialStep = TutorialProgress.Get(Attempt.PlayerEntity)

    if TutorialStep == TutorialSteps.CatchFirst then
        NewItem.TutorialRole = TutorialSteps.FirstRole
    elseif TutorialStep == TutorialSteps.CatchStrong then
        NewItem.TutorialRole = TutorialSteps.StrongRole
    end

    NewItem.FinalIncomePerSec = InventoryMath.GetFinalIncomePerSec(NewItem)
    NewItem.IncomePerSec = NewItem.FinalIncomePerSec

    table.insert(Result, NewItem)

    if NewHotbarSlot then
        HotbarSlots[tostring(NewHotbarSlot)] = {
            Slot = NewHotbarSlot,
            ItemId = NewId,
            ItemType = "Squishy",
        }
        World:set(Attempt.PlayerEntity, Components.HotbarSlots, HotbarSlots)
    end

    World:set(Attempt.PlayerEntity, Components.OwnedSquishies, Result)

    if Squishies.GetDataFromKey(IndexKey) then
        local CurrentIndex = World:get(Attempt.PlayerEntity, Components.Index)
        local NewIndex = {}
        local Seen = {}

        if type(CurrentIndex) == "table" then
            for _, Key in CurrentIndex do
                if type(Key) == "string" and Key ~= "" and not Seen[Key] then
                    Seen[Key] = true
                    table.insert(NewIndex, Key)
                end
            end
        end

        if not Seen[IndexKey] then
            table.insert(NewIndex, IndexKey)
            table.sort(NewIndex)
            World:set(Attempt.PlayerEntity, Components.Index, NewIndex)
            Notify(Attempt.Player, "New index reward to claim!", "Info", 3)
        end
    end

    return NewId, NewHotbarSlot
end

local function Pull_Target_Then_Delete(Attempt: Attempt, InitialCFrame: CFrame?)
    local Model = Get_Target_Model(Attempt.TargetEntity)

    if not Model then
        if World:contains(Attempt.TargetEntity) then
            World:delete(Attempt.TargetEntity)
        end

        return
    end

    local StartCFrame = InitialCFrame or RoamingSquishies.GetCurrentCFrame(Attempt.TargetEntity) or Model:GetPivot()
    Model:PivotTo(StartCFrame)

    if Model.Parent then
        task.wait(CatchConfig.PullDurationSeconds + 0.15)
    end

    if World:contains(Attempt.TargetEntity) then
        World:delete(Attempt.TargetEntity)
    end
end

local function Complete_Attempt(Attempt: Attempt)
    if Attempt.Completed then
        return
    end

    if not InventoryCapacity.CanAddSquishies(World:get(Attempt.PlayerEntity, Components.OwnedSquishies), 1) then
        Cancel_Attempt(Attempt, "Cancelled", InventoryCapacity.SquishyInventoryFullMessage, true)
        return
    end

    Attempt.Completed = true
    CompletedTargets[Attempt.TargetEntity] = true
    local FinalRoamingCFrame = RoamingSquishies.GetCurrentCFrame(Attempt.TargetEntity)
    local Model = Get_Target_Model(Attempt.TargetEntity)
    local CompletionCFrame = FinalRoamingCFrame or (if Model then Model:GetPivot() else nil)

    if Model and CompletionCFrame then
        Model:PivotTo(CompletionCFrame)
    end

    Lock_Attempt(Attempt)
    local CaughtItemId, CaughtHotbarSlot = Add_Caught_Squishy(Attempt)

    if not CaughtItemId then
        CompletedTargets[Attempt.TargetEntity] = nil
        Remove_Attempt(Attempt, true)
        return
    end

    Stop_Target_Roaming(Attempt.TargetEntity)
    Remove_Attempt(Attempt, false)

    if Model then
        Model:SetAttribute(PULL_TARGET_USER_ID_ATTRIBUTE, Attempt.Player.UserId)
        Model:SetAttribute(PULL_PROGRESS_ATTRIBUTE, 1)
        Model:SetAttribute(PULL_LASSO_NAME_ATTRIBUTE, Attempt.LassoName)
        Model:SetAttribute(CATCH_COMPLETE_ID_ATTRIBUTE, Attempt.CatchId)
        Model:SetAttribute("CatchCompleteCFrame", CompletionCFrame)
    end

    Network.CatchCompleted.Fire(Attempt.Player, {
        CatchId = Attempt.CatchId,
        ItemId = CaughtItemId,
        HotbarSlot = CaughtHotbarSlot,
    })
    Network.CatchPullEffect.FireAll({
        CatchId = Attempt.CatchId,
        PlayerUserId = Attempt.Player.UserId,
    })

    TutorialProgress.Complete_Step(Attempt.PlayerEntity, TutorialSteps.CatchFirst, TutorialSteps.PlaceFirst)
    TutorialProgress.Complete_Step(Attempt.PlayerEntity, TutorialSteps.CatchStrong, TutorialSteps.PlaceStrong)

    task.spawn(Pull_Target_Then_Delete, Attempt, FinalRoamingCFrame)
end

local function Get_Target_Attempts(TargetEntity: number): { [Player]: Attempt }
    local TargetAttempts = AttemptsByTarget[TargetEntity]

    if not TargetAttempts then
        TargetAttempts = {}
        AttemptsByTarget[TargetEntity] = TargetAttempts
    end

    return TargetAttempts
end

local function Start_Attempt(
    Player: Player,
    Data: {
        AimOriginX: number,
        AimOriginY: number,
        AimOriginZ: number,
        AimDirectionX: number,
        AimDirectionY: number,
        AimDirectionZ: number,
    }
)
    local AimOrigin, AimDirection = Get_Aim_Ray(Data)

    if not AimOrigin or not AimDirection then
        Reject(Player, "Invalid", "")
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        Reject(Player, "Invalid", "Player data is not loaded yet.")
        return
    end

    if not InventoryCapacity.CanAddSquishies(World:get(PlayerEntity, Components.OwnedSquishies), 1) then
        Notify(Player, InventoryCapacity.SquishyInventoryFullMessage, "Error", 3)
        Reject(Player, "Cancelled", InventoryCapacity.SquishyInventoryFullMessage)
        return
    end

    local TargetEntity, BlockedMessage = Find_Target_On_Aim_Path(Player, PlayerEntity, AimOrigin, AimDirection)

    if not TargetEntity then
        if BlockedMessage then
            Notify(Player, BlockedMessage, "Error", 3)
            Reject(Player, "Cancelled", BlockedMessage)
            return
        end

        Reject(Player, "Invalid", "")
        return
    end

    if not Is_Target_Valid(TargetEntity) then
        Reject(Player, "Invalid", "That target is no longer available.")
        return
    end

    local ExistingLock = TargetLocks[TargetEntity]

    if ExistingLock and ExistingLock.Player ~= Player then
        Reject(Player, "Locked", "That target is already locked by another player.")
        return
    end

    if not Is_In_Range(Player, TargetEntity, CatchConfig.MaxStartDistance) then
        Reject(Player, "Invalid", "Move closer to catch that target.")
        return
    end

    Cancel_Player_Attempt(Player)

    local Kind = World:get(TargetEntity, Components.Kind)
    local TargetName = World:get(TargetEntity, Components.Name)

    if type(Kind) ~= "string" or type(TargetName) ~= "string" then
        Reject(Player, "Invalid", "That target is missing data.")
        return
    end

    local SquishyData = Squishies.GetData(Kind :: any, TargetName)

    if not SquishyData then
        Reject(Player, "Invalid", "That target is missing data.")
        return
    end

    local TargetModel = Get_Target_Model(TargetEntity)
    local TutorialStep = TutorialProgress.Get(PlayerEntity)
    local TargetTutorialUserId = TargetModel and TargetModel:GetAttribute(TutorialSteps.TargetUserIdAttribute)
    local TargetTutorialStep = TargetModel and TargetModel:GetAttribute(TutorialSteps.TargetStepAttribute)

    if not TutorialProgress.Is_Complete(PlayerEntity) then
        if type(TargetTutorialUserId) == "number" and TargetTutorialUserId ~= Player.UserId then
            Notify(Player, "That's a tutorial Squishy.", "Error", 3)
            Reject(Player, "Cancelled", "That's a tutorial Squishy.")
            return
        end

        if
            not TutorialSteps.Is_Catch_Step(TutorialStep)
            or (type(TargetTutorialStep) == "number" and TargetTutorialStep ~= TutorialStep)
            or not TutorialSteps.Is_Catch_Rarity_Allowed(TutorialStep, SquishyData.Rarity)
        then
            Notify(Player, TutorialSteps.BlockedMessage, "Error", 3)
            Reject(Player, "Cancelled", TutorialSteps.BlockedMessage)
            return
        end
    elseif type(TargetTutorialUserId) == "number" and TargetTutorialUserId ~= Player.UserId then
        Notify(Player, "That's a tutorial Squishy.", "Error", 3)
        Reject(Player, "Cancelled", "That's a tutorial Squishy.")
        return
    end

    local LassoData = Get_Selected_Lasso_Data(PlayerEntity)
    local TargetWeight = World:get(TargetEntity, Components.Weight) or 0
    local TargetMutation = InventoryMath.NormalizeMutation(World:get(TargetEntity, Components.Mutation), Kind)
    local TargetEventMutations = EventMutations.NormalizeList(World:get(TargetEntity, Components.EventMutations))
    local TargetStrength = CatchConfig.Get_Catch_Strength(SquishyData, TargetWeight)
    local TargetBaseIncomePerSec = if type(SquishyData.IncomePerSec) == "number" then SquishyData.IncomePerSec else 0
    local TargetIncomePerSec = InventoryMath.GetFinalIncomePerSec({
        Kind = Kind,
        BaseIncomePerSec = TargetBaseIncomePerSec,
        Weight = TargetWeight,
        Mutation = TargetMutation,
        EventMutations = TargetEventMutations,
        Level = 0,
    })
    local LassoStrength = math.max(1, LassoData.Strength)
    local Difficulty = CatchConfig.Get_Difficulty(TargetStrength, LassoStrength, SquishyData.Rarity)
    local ClicksNeeded = CatchConfig.Get_Clicks_Needed(Difficulty)
    local EffectiveTargetStrength = math.max(1, TargetStrength)
    local CatchId = HttpService:GenerateGUID(false)
    local Now = workspace:GetServerTimeNow()
    local Attempt: Attempt = {
        Player = Player,
        PlayerEntity = PlayerEntity,
        TargetEntity = TargetEntity,
        CatchId = CatchId,
        Progress = 0,
        LastUpdateTime = Now,
        LastClickTime = Now,
        LastClickAcceptedTime = 0,
        LastProgressSentTime = 0,
        LastProgressSent = 0,
        LassoStrength = LassoStrength,
        Difficulty = Difficulty,
        ClicksNeeded = ClicksNeeded,
        ProgressPerClick = CatchConfig.Get_Click_Gain(ClicksNeeded),
        DrainChunk = CatchConfig.Get_Drain_Chunk(Difficulty),
        DrainInterval = CatchConfig.Get_Drain_Interval(Difficulty),
        AutoFailThreshold = CatchConfig.Get_Auto_Fail_Threshold(Difficulty),
        AutoFailDuration = CatchConfig.Get_Auto_Fail_Duration(Difficulty),
        TimeSinceLastDrain = 0,
        TimeBelowThreshold = 0,
        TargetStrength = EffectiveTargetStrength,
        TargetWeight = TargetWeight,
        TargetBaseIncomePerSec = TargetBaseIncomePerSec,
        TargetIncomePerSec = TargetIncomePerSec,
        Rarity = SquishyData.Rarity,
        Kind = Kind,
        TargetName = TargetName,
        TargetMutation = TargetMutation,
        TargetEventMutations = TargetEventMutations,
        TargetImage = SquishyData.Image,
        LassoName = LassoData.Name,
        Locked = false,
        Completed = false,
    }

    AttemptsById[CatchId] = Attempt
    AttemptsByPlayer[Player] = Attempt
    Get_Target_Attempts(TargetEntity)[Player] = Attempt

    World:set(TargetEntity, Components.CatchProgress, Attempt.Progress)
    World:set(TargetEntity, Components.CatchId, CatchId)
    Update_Target_Pull_State(TargetEntity)

    Network.CatchStarted.Fire(Player, {
        CatchId = CatchId,
        TargetEntity = TargetEntity,
        TargetName = TargetName,
        TargetKind = Kind,
        TargetImage = SquishyData.Image,
        TargetRarity = SquishyData.Rarity,
        Strength = TargetStrength,
        ClicksNeeded = ClicksNeeded,
        Difficulty = Difficulty,
        DepletionTweenTime = CatchConfig.Get_Depletion_Tween_Time(Difficulty),
        LockProgress = CatchConfig.LockProgress,
        Progress = Attempt.Progress,
    })

    if TutorialStep == TutorialSteps.CatchFirst or TutorialStep == TutorialSteps.CatchStrong then
        Lock_Attempt(Attempt)
    end
end

local function Handle_Click(Player: Player, Data: { CatchId: string })
    local Attempt = AttemptsById[Data.CatchId]

    if not Attempt or Attempt.Player ~= Player then
        return
    end

    local Now = workspace:GetServerTimeNow()
    local MinClickInterval = 1 / CatchConfig.MaxClicksPerSecond

    if Now - Attempt.LastClickAcceptedTime < MinClickInterval then
        return
    end

    if not Is_Target_Valid(Attempt.TargetEntity) then
        Cancel_Attempt(Attempt, "Lost", "That target disappeared.", true)
        return
    end

    local ExistingLock = TargetLocks[Attempt.TargetEntity]

    if ExistingLock and ExistingLock ~= Attempt then
        Cancel_Attempt(Attempt, "Locked", "That target was locked by another player.", true)
        return
    end

    if not Is_In_Range(Player, Attempt.TargetEntity, CatchConfig.MaxMaintainDistance) then
        Cancel_Attempt(Attempt, "Lost", "You moved too far away.", true)
        return
    end

    Attempt.LastClickAcceptedTime = Now
    Attempt.LastClickTime = Now
    Attempt.TimeBelowThreshold = 0
    Set_Attempt_Progress(Attempt, Attempt.Progress + Attempt.ProgressPerClick)

    if World:contains(Attempt.TargetEntity) then
        World:set(Attempt.TargetEntity, Components.CatchProgress, Attempt.Progress)
    end

    Update_Target_Pull_State(Attempt.TargetEntity)
    Send_Progress(Attempt, true)

    if Attempt.Progress >= CatchConfig.LockProgress then
        Lock_Attempt(Attempt)
    end

    if Attempt.Progress >= 1 then
        Complete_Attempt(Attempt)
    end
end

local function Handle_Cancel(Player: Player, Data: { CatchId: string })
    local Attempt = AttemptsById[Data.CatchId]

    if not Attempt or Attempt.Player ~= Player then
        return
    end

    Cancel_Attempt(Attempt, "Cancelled", "", false)
end

local function Update_Attempt(Attempt: Attempt, Now: number)
    if Attempt.Completed then
        return
    end

    if not Attempt.Player.Parent or not World:contains(Attempt.PlayerEntity) then
        Cancel_Attempt(Attempt, "Lost", "", false)
        return
    end

    if not Is_Target_Valid(Attempt.TargetEntity) then
        Cancel_Attempt(Attempt, "Lost", "That target disappeared.", true)
        return
    end

    if not Is_In_Range(Attempt.Player, Attempt.TargetEntity, CatchConfig.MaxMaintainDistance) then
        Cancel_Attempt(Attempt, "Lost", "You moved too far away.", true)
        return
    end

    local DeltaTime = math.clamp(Now - Attempt.LastUpdateTime, 0, 0.2)
    Attempt.LastUpdateTime = Now

    Attempt.TimeSinceLastDrain += DeltaTime

    if Attempt.TimeSinceLastDrain >= Attempt.DrainInterval then
        Attempt.TimeSinceLastDrain = 0
        Set_Attempt_Progress(Attempt, Attempt.Progress - Attempt.DrainChunk)

        if Attempt.Locked and Attempt.Progress < CatchConfig.LockProgress then
            Unlock_Attempt(Attempt)
        end

        if World:contains(Attempt.TargetEntity) then
            World:set(Attempt.TargetEntity, Components.CatchProgress, Attempt.Progress)
        end

        Update_Target_Pull_State(Attempt.TargetEntity)
        Send_Progress(Attempt, false, CatchConfig.Get_Depletion_Tween_Time(Attempt.Difficulty))
    end

    if Attempt.Progress < Attempt.AutoFailThreshold then
        Attempt.TimeBelowThreshold += DeltaTime
    else
        Attempt.TimeBelowThreshold = 0
    end

    if Attempt.TimeBelowThreshold >= Attempt.AutoFailDuration then
        Cancel_Attempt(Attempt, "Lost", "Your lasso broke.", true)
        return
    end

    if Now - Attempt.LastClickTime >= CatchConfig.IdleTimeoutSeconds then
        Cancel_Attempt(Attempt, "Lost", "Your lasso broke.", true)
    end
end

local function Update_Attempts()
    local Now = workspace:GetServerTimeNow()
    local Snapshot = {}

    for _, Attempt in AttemptsById do
        table.insert(Snapshot, Attempt)
    end

    for _, Attempt in Snapshot do
        if AttemptsById[Attempt.CatchId] == Attempt then
            Update_Attempt(Attempt, Now)
        end
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.PreUpdate,
    system = function()
        for _, Player, Data in Network.LassoThrowStarted.Iter() do
            if not RemoteCooldowns.Allow(Player, "LassoThrowStarted", 0.05) then
                continue
            end

            Broadcast_Lasso_Throw(Player, Data)
        end

        for _, Player, Data in Network.StartCatch.Iter() do
            if not RemoteCooldowns.Allow(Player, "StartCatch") then
                continue
            end

            Start_Attempt(Player, Data)
        end

        for _, Player, Data in Network.CatchClick.Iter() do
            if not RemoteCooldowns.Allow(Player, "CatchClick") then
                continue
            end

            Handle_Click(Player, Data)
        end

        for _, Player, Data in Network.CancelCatch.Iter() do
            if not RemoteCooldowns.Allow(Player, "CancelCatch") then
                continue
            end

            Handle_Cancel(Player, Data)
        end

        Update_Attempts()
    end,
    runConditions = {},
}
