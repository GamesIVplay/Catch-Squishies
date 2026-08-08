local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Network = require(ReplicatedFirst.Network)
local peek = Fusion.peek

local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local Phases = require(ReplicatedStorage.Shared.Phases)
local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local PlayCollectEffect = require(script.Parent.Parent.Modules.CollectEffect)

local LocalPlayer = Players.LocalPlayer
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local BillboardsFolder = AssetsFolder:WaitForChild("Billboards")
local CollectAllTemplate = BillboardsFolder:WaitForChild("CollectAll") :: BillboardGui
local Plots = workspace:WaitForChild("Plots")

local COLLECT_ALL_MODEL_NAME = "CollectAllCash"
local BILLBOARD_HOLDER_NAME = "BillboardHolder"
local ACTIVATE_PART_NAME = "Activate"
local BILLBOARD_NAME = "CollectAll"
local UPDATE_INTERVAL = 0.25
local COLLECT_REQUEST_COOLDOWN = 0.15
local ACTIVATE_PADDING_XZ = 2
local ACTIVATE_PADDING_Y = 5
local EFFECT_LIFETIME = 3

local LastUpdateAt = -math.huge
local LastCollectRequestAt = -math.huge
local CachedPlot: Instance? = nil
local BoundActivate: BasePart? = nil
local ActivateTouchedConnection: RBXScriptConnection? = nil
local ActivateTouchEndedConnection: RBXScriptConnection? = nil
local IsInsideActivate = false
local LastActivatePollAt = -math.huge
local MissingPartCollectWarned = false

local function Normalize_Name(Name: string): string
    return string.lower((string.gsub(Name, "[%s_%-%p]+", "")))
end

local function Is_Collect_All_Model(InstanceToCheck: Instance): boolean
    local NormalizedName = Normalize_Name(InstanceToCheck.Name)

    return string.find(NormalizedName, "collect", 1, true) ~= nil
        and string.find(NormalizedName, "cash", 1, true) ~= nil
end

local function Find_Player_Plot(UserId: number, PlayerName: string?): Instance?
    for _, Plot in Plots:GetChildren() do
        if Plot:GetAttribute("OwnerUserId") == UserId then
            return Plot
        end
    end

    if type(PlayerName) ~= "string" or PlayerName == "" then
        return nil
    end

    local ExpectedTitle = `{PlayerName}'s Plot`

    for _, Plot in Plots:GetChildren() do
        local OwnerSign = Plot:FindFirstChild("OwnerSign")
        local Title = OwnerSign and OwnerSign:FindFirstChild("Title", true)

        if Title and Title:IsA("TextLabel") and Title.Text == ExpectedTitle then
            return Plot
        end
    end

    return nil
end

local function Get_Local_Player_Plot(): Instance?
    if CachedPlot and CachedPlot.Parent and CachedPlot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
        return CachedPlot
    end

    CachedPlot = Find_Player_Plot(LocalPlayer.UserId, LocalPlayer.Name)
    return CachedPlot
end

local function Get_Collect_All_Model(Plot: Instance?): Instance?
    if not Plot then
        return nil
    end

    local Direct = Plot:FindFirstChild(COLLECT_ALL_MODEL_NAME)

    if Direct then
        return Direct
    end

    for _, Child in Plot:GetChildren() do
        if Is_Collect_All_Model(Child) then
            return Child
        end
    end

    return nil
end

local function Get_Billboard_Holder(Model: Instance?): Instance?
    local Holder = Model and Model:FindFirstChild(BILLBOARD_HOLDER_NAME, true)

    if Holder and (Holder:IsA("BasePart") or Holder:IsA("Attachment")) then
        return Holder
    end

    return nil
end

local function Is_Tutorial_Active(): boolean
    return LocalPlayer:GetAttribute("TutorialActive") == true
end

local function Set_Billboard_Enabled(Enabled: boolean)
    local Plot = Get_Local_Player_Plot()
    local Model = Get_Collect_All_Model(Plot)
    local Holder = Get_Billboard_Holder(Model)
    local Billboard = Holder and Holder:FindFirstChild(BILLBOARD_NAME)

    if Billboard and Billboard:IsA("BillboardGui") then
        Billboard.Enabled = Enabled
    end
end

local function Get_Activate_Part(Model: Instance?): BasePart?
    local Activate = Model and Model:FindFirstChild(ACTIVATE_PART_NAME, true)

    if Activate and Activate:IsA("BasePart") then
        return Activate
    end

    return nil
end

local function Get_Or_Create_Billboard(Holder: Instance): BillboardGui
    local Existing = Holder:FindFirstChild(BILLBOARD_NAME)

    if Existing and Existing:IsA("BillboardGui") then
        return Existing
    end

    if Existing then
        Existing:Destroy()
    end

    local Billboard = CollectAllTemplate:Clone()
    Billboard.Name = BILLBOARD_NAME
    Billboard.Enabled = true
    Billboard.Parent = Holder

    return Billboard
end

local function Find_Cash_Label(Billboard: BillboardGui): TextLabel?
    local CashObject = Billboard:FindFirstChild("Cash", true)

    if CashObject then
        if CashObject:IsA("TextLabel") then
            return CashObject
        end

        for _, Name in { "Strength", "Amount", "Value", "Cash" } do
            local Label = CashObject:FindFirstChild(Name, true)

            if Label and Label:IsA("TextLabel") then
                return Label
            end
        end

        local Label = CashObject:FindFirstChildWhichIsA("TextLabel", true)

        return if Label and Label:IsA("TextLabel") then Label else nil
    end

    for _, Label in Billboard:GetDescendants() do
        if Label:IsA("TextLabel") and Label.Name ~= "Title" then
            return Label
        end
    end

    return nil
end

local function Get_Part_Collect_Effect(): Attachment?
    local Effects = AssetsFolder:FindFirstChild("Effects")
    local VFX = AssetsFolder:FindFirstChild("VFX")
    local Effect = (Effects and Effects:FindFirstChild("PartCollect")) or (VFX and VFX:FindFirstChild("PartCollect"))

    return if Effect and Effect:IsA("Attachment") then Effect else nil
end

local function Emit_Instance(InstanceObject: Instance)
    if InstanceObject:IsA("ParticleEmitter") then
        local EmitCount = InstanceObject:GetAttribute("EmitCount")

        InstanceObject:Emit(if type(EmitCount) == "number" then EmitCount else 1)
    end

    for _, Descendant in InstanceObject:GetDescendants() do
        if not Descendant:IsA("ParticleEmitter") then
            continue
        end

        local EmitCount = Descendant:GetAttribute("EmitCount")

        Descendant:Emit(if type(EmitCount) == "number" then EmitCount else 1)
    end
end

local function Play_Part_Collect_Effect(Holder: Instance)
    local Template = Get_Part_Collect_Effect()

    if not Template then
        if not MissingPartCollectWarned then
            MissingPartCollectWarned = true
            warn("[PlotCollectAllCash] ReplicatedStorage.Assets.Effects.PartCollect is missing.")
        end

        return
    end

    if Holder:IsA("BasePart") then
        local Effect = Template:Clone()
        Effect.Parent = Holder
        Emit_Instance(Effect)
        Debris:AddItem(Effect, EFFECT_LIFETIME)
        return
    end

    if Holder:IsA("Attachment") then
        for _, Child in Template:GetChildren() do
            local Clone = Child:Clone()
            Clone.Parent = Holder
            Emit_Instance(Clone)
            Debris:AddItem(Clone, EFFECT_LIFETIME)
        end
    end
end

local function Play_Collect_All_Effect(UserId: number)
    local Player = Players:GetPlayerByUserId(UserId)

    if Player then
        PlayCollectEffect(Player.Character, {
            PlaySound = UserId == LocalPlayer.UserId,
            PlayVFX = false,
        })
    end

    local Plot = Find_Player_Plot(UserId, if Player then Player.Name else nil)
    local Model = Get_Collect_All_Model(Plot)
    local Holder = Get_Billboard_Holder(Model)

    if Holder then
        Play_Part_Collect_Effect(Holder)
    end
end

local function Normalize_Number(Value: any, Fallback: number?): number
    if type(Value) ~= "number" or Value ~= Value then
        return Fallback or 0
    end

    return Value
end

local function Get_Item_Base_Collectable_Cash(Item: any, Now: number, MoneyMultiplier: number): number
    if type(Item) ~= "table" then
        return 0
    end

    local StoredCash = math.max(0, Normalize_Number(Item.StoredCash, 0))
    local BaseStoredCash = if MoneyMultiplier > 0 then StoredCash / MoneyMultiplier else StoredCash
    local LastCashUpdate = Normalize_Number(Item.LastCashUpdate, Now)
    local IncomePerSec = math.max(0, math.floor(Normalize_Number(Item.FinalIncomePerSec, 0) + 0.5))
    local Delta = math.floor(math.max(0, Now - LastCashUpdate))

    return BaseStoredCash + IncomePerSec * Delta
end

local function Get_Total_Collectable_Cash(): number
    local PlotSquishies = peek(FusionValues.PlotSquishies)
    local MoneyMultiplier = RobuxProducts.NormalizeMoneyMultiplier(peek(FusionValues.MoneyMultiplier))
    local Now = workspace:GetServerTimeNow()
    local Total = 0

    if type(PlotSquishies) ~= "table" then
        return 0
    end

    for _, Item in PlotSquishies do
        Total += math.floor(Get_Item_Base_Collectable_Cash(Item, Now, MoneyMultiplier))
    end

    return math.max(0, math.floor(Total + 0.5))
end

local function Format_Cash(Value: number): string
    return "$" .. Util.Abbreviate_Number(Value, 1)
end

local function Update_Billboard()
    if Is_Tutorial_Active() then
        Set_Billboard_Enabled(false)
        return
    end

    local Plot = Get_Local_Player_Plot()
    local Model = Get_Collect_All_Model(Plot)
    local Holder = Get_Billboard_Holder(Model)

    if not Holder then
        return
    end

    local Billboard = Get_Or_Create_Billboard(Holder)
    local Label = Find_Cash_Label(Billboard)

    Billboard.Enabled = true

    if Label then
        Label.Text = Format_Cash(Get_Total_Collectable_Cash())
    end
end

local function Is_Root_In_Activate(Activate: BasePart, Root: BasePart): boolean
    local LocalPosition = Activate.CFrame:PointToObjectSpace(Root.Position)
    local HalfSize = Activate.Size * 0.5

    return math.abs(LocalPosition.X) <= HalfSize.X + ACTIVATE_PADDING_XZ
        and math.abs(LocalPosition.Z) <= HalfSize.Z + ACTIVATE_PADDING_XZ
        and math.abs(LocalPosition.Y) <= HalfSize.Y + ACTIVATE_PADDING_Y
end

local function Is_Character_Touching_Activate(Activate: BasePart): boolean
    local Character = LocalPlayer.Character

    if not Character then
        return false
    end

    local OverlapParamsObject = OverlapParams.new()
    OverlapParamsObject.FilterType = Enum.RaycastFilterType.Include
    OverlapParamsObject.FilterDescendantsInstances = { Character }

    local Parts = workspace:GetPartBoundsInBox(
        Activate.CFrame,
        Activate.Size + Vector3.new(ACTIVATE_PADDING_XZ * 2, ACTIVATE_PADDING_Y * 2, ACTIVATE_PADDING_XZ * 2),
        OverlapParamsObject
    )

    if #Parts > 0 then
        return true
    end

    for _, Descendant in Character:GetDescendants() do
        if Descendant:IsA("BasePart") and Is_Root_In_Activate(Activate, Descendant) then
            return true
        end
    end

    return false
end

local function Is_Local_Character_Part(Part: BasePart): boolean
    local Character = LocalPlayer.Character

    if not Character then
        return false
    end

    return Part:IsDescendantOf(Character)
end

local function Request_Collect_All()
    if Is_Tutorial_Active() then
        return
    end

    local Now = os.clock()

    if Now - LastCollectRequestAt < COLLECT_REQUEST_COOLDOWN then
        return
    end

    LastCollectRequestAt = Now

    Network.CollectAllPlotSquishyCash.Fire()
end

local function Process_Collect_All_Effects()
    for _, Data in Network.CollectAllEffect.Iter() do
        if type(Data.PlayerUserId) ~= "number" then
            continue
        end

        Play_Collect_All_Effect(Data.PlayerUserId)
    end
end

local function Refresh_Activate_Inside_State()
    if not BoundActivate or not BoundActivate.Parent then
        IsInsideActivate = false
        return
    end

    local IsTouching = Is_Character_Touching_Activate(BoundActivate)

    if not IsTouching then
        IsInsideActivate = false
        return
    end

    if IsInsideActivate then
        return
    end

    IsInsideActivate = true
    Request_Collect_All()
end

local function Bind_Activate_Touched()
    if Is_Tutorial_Active() then
        IsInsideActivate = false
        Set_Billboard_Enabled(false)
        return
    end

    local Plot = Get_Local_Player_Plot()
    local Model = Get_Collect_All_Model(Plot)
    local Activate = Get_Activate_Part(Model)

    if BoundActivate == Activate and ActivateTouchedConnection and ActivateTouchEndedConnection then
        return
    end

    if ActivateTouchedConnection then
        ActivateTouchedConnection:Disconnect()
        ActivateTouchedConnection = nil
    end

    if ActivateTouchEndedConnection then
        ActivateTouchEndedConnection:Disconnect()
        ActivateTouchEndedConnection = nil
    end

    BoundActivate = Activate
    IsInsideActivate = false
    LastActivatePollAt = -math.huge

    if not Activate then
        return
    end

    Activate.CanTouch = true

    ActivateTouchedConnection = Activate.Touched:Connect(function(Part)
        if not Is_Local_Character_Part(Part) then
            return
        end

        if IsInsideActivate and Is_Character_Touching_Activate(Activate) then
            return
        end

        IsInsideActivate = true
        Request_Collect_All()
    end)

    ActivateTouchEndedConnection = Activate.TouchEnded:Connect(function(Part)
        if not Is_Local_Character_Part(Part) then
            return
        end

        task.delay(0.05, function()
            if BoundActivate ~= Activate then
                return
            end

            Refresh_Activate_Inside_State()
        end)
    end)
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        local Now = os.clock()

        if Now - LastUpdateAt >= UPDATE_INTERVAL then
            LastUpdateAt = Now
            Update_Billboard()
            Bind_Activate_Touched()
        end

        if Now - LastActivatePollAt >= 0.05 then
            LastActivatePollAt = Now
            Refresh_Activate_Inside_State()
        end

        Process_Collect_All_Effects()
    end,
    runConditions = {},
}
