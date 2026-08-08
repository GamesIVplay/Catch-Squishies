local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Phases = require(ReplicatedStorage.Shared.Phases)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)

local peek = Fusion.peek
local FusionValues = require(script.Parent.Parent.Modules.FusionValues)

type OriginalState = {
    Transparency: number?,
    Enabled: boolean?,
    Visible: boolean?,
    CanCollide: boolean?,
    CanTouch: boolean?,
    CanQuery: boolean?,
}

local LocalPlayer = Players.LocalPlayer
local Plots: Instance? = workspace:FindFirstChild("Plots")

local SCAN_INTERVAL = 0.5
local HIDDEN_BASE_PART_LOCAL_TRANSPARENCY = 1
local HOME_BILLBOARD_NAME = "Home"
local HIDDEN_PLOT_SIGNS_FOLDER_NAME = "ClientHiddenPlotSigns"
local SIGN_PARENT_MARKER_NAME = "OriginalParent"
local SIGN_MARKER_SIGN_REF_NAME = "Sign"
local EXACT_HIDDEN_ROOT_NAMES = table.freeze({
    FoodShop = true,
    LassoShop = true,
    SellShop = true,
    LuckyBlockSign = true,
    SkipTimeSign = true,
})
local PLOT_SIGN_ROOT_NAMES = table.freeze({
    LuckyBlockSign = true,
    SkipTimeSign = true,
})
local TUTORIAL_HIDDEN_ROOT_NAMES = table.freeze({
    LuckyBlockSign = true,
    SkipTimeSign = true,
})

local OriginalStates: { [Instance]: OriginalState } = setmetatable({}, { __mode = "k" }) :: any
local OriginalParents: { [Instance]: Instance } = {}
local FullyHiddenPlots: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local LastScanAt = -math.huge
local HomeBillboard: BillboardGui? = nil
local HomeBillboardParent: Instance? = nil

local function Get_Plots(): Instance?
    if Plots and Plots.Parent then
        return Plots
    end

    Plots = workspace:FindFirstChild("Plots")

    return Plots
end

local function Normalize_Name(Name: string): string
    return string.lower((string.gsub(Name, "[%s_%-%p]+", "")))
end

local function Is_Collect_All_Cash_Root(InstanceToCheck: Instance): boolean
    local NormalizedName = Normalize_Name(InstanceToCheck.Name)

    return string.find(NormalizedName, "collect", 1, true) ~= nil
        and string.find(NormalizedName, "cash", 1, true) ~= nil
end

local function Get_Target_Roots(Plot: Instance): { Instance }
    local Roots = {}
    local Seen: { [Instance]: boolean } = {}

    for RootName in EXACT_HIDDEN_ROOT_NAMES do
        local Root = Plot:FindFirstChild(RootName)

        if Root and not Seen[Root] then
            Seen[Root] = true
            table.insert(Roots, Root)
        end
    end

    for _, Child in Plot:GetChildren() do
        if Seen[Child] or not Is_Collect_All_Cash_Root(Child) then
            continue
        end

        Seen[Child] = true
        table.insert(Roots, Child)
    end

    return Roots
end

local function Is_Tutorial_Hidden_Root(Root: Instance): boolean
    return TUTORIAL_HIDDEN_ROOT_NAMES[Root.Name] == true or Is_Collect_All_Cash_Root(Root)
end

local function Is_Tutorial_Active(): boolean
    if peek(FusionValues.TutorialStepReceived) == true then
        return not TutorialSteps.Is_Complete(TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep)))
    end

    return LocalPlayer:GetAttribute("TutorialActive") == true
end

local function Is_Plot_Sign_Root(Root: Instance): boolean
    return PLOT_SIGN_ROOT_NAMES[Root.Name] == true
end

local function Is_Reparent_Only_Root(Root: Instance): boolean
    return Is_Plot_Sign_Root(Root) or Is_Collect_All_Cash_Root(Root)
end

local function Has_Plot_Sign_Ancestor(InstanceToCheck: Instance, StopAt: Instance): boolean
    local Ancestor = InstanceToCheck.Parent

    while Ancestor and Ancestor ~= StopAt.Parent do
        if Is_Plot_Sign_Root(Ancestor) then
            return true
        end

        if Ancestor == StopAt then
            return false
        end

        Ancestor = Ancestor.Parent
    end

    return false
end

local function Get_Instance_Position(InstanceToCheck: Instance): Vector3?
    if InstanceToCheck:IsA("Model") then
        return InstanceToCheck:GetPivot().Position
    end

    if InstanceToCheck:IsA("BasePart") then
        return InstanceToCheck.Position
    end

    if InstanceToCheck:IsA("Attachment") then
        return InstanceToCheck.WorldPosition
    end

    local Part = InstanceToCheck:FindFirstChildWhichIsA("BasePart", true)

    return if Part then Part.Position else nil
end

local function Infer_Reparented_Sign_Parent(SignRoot: Instance): Instance?
    local SignPosition = Get_Instance_Position(SignRoot)
    local PlotsFolder = Get_Plots()

    if not SignPosition or not PlotsFolder then
        return nil
    end

    local BestPlot: Instance? = nil
    local BestDistance = math.huge

    for _, Plot in PlotsFolder:GetChildren() do
        if Plot:FindFirstChild(SignRoot.Name) then
            continue
        end

        local PlotPosition = Get_Instance_Position(Plot)

        if not PlotPosition then
            continue
        end

        local Distance = (PlotPosition - SignPosition).Magnitude

        if Distance < BestDistance then
            BestDistance = Distance
            BestPlot = Plot
        end
    end

    return BestPlot
end

local function Get_Hidden_Plot_Signs_Folder(): Folder
    local Existing = ReplicatedStorage:FindFirstChild(HIDDEN_PLOT_SIGNS_FOLDER_NAME)

    if Existing and Existing:IsA("Folder") then
        return Existing
    end

    local Folder = Instance.new("Folder")
    Folder.Name = HIDDEN_PLOT_SIGNS_FOLDER_NAME
    Folder.Parent = ReplicatedStorage

    return Folder
end

local function Get_Plot_Sign_Marker(SignRoot: Instance): ObjectValue?
    local Folder = ReplicatedStorage:FindFirstChild(HIDDEN_PLOT_SIGNS_FOLDER_NAME)

    if not Folder then
        return nil
    end

    for _, Marker in Folder:GetChildren() do
        if not Marker:IsA("ObjectValue") or Marker.Name ~= SIGN_PARENT_MARKER_NAME then
            continue
        end

        local SignRef = Marker:FindFirstChild(SIGN_MARKER_SIGN_REF_NAME)

        if SignRef and SignRef:IsA("ObjectValue") and SignRef.Value == SignRoot then
            return Marker
        end
    end

    return nil
end

local function Create_Plot_Sign_Marker(SignRoot: Instance, OriginalParent: Instance, Folder: Folder)
    local ExistingMarker = Get_Plot_Sign_Marker(SignRoot)

    if ExistingMarker then
        ExistingMarker.Value = OriginalParent
        return
    end

    local Marker = Instance.new("ObjectValue")
    Marker.Name = SIGN_PARENT_MARKER_NAME
    Marker.Value = OriginalParent

    local SignRef = Instance.new("ObjectValue")
    SignRef.Name = SIGN_MARKER_SIGN_REF_NAME
    SignRef.Value = SignRoot
    SignRef.Parent = Marker

    Marker.Parent = Folder
end

local function Get_Marker_Sign(Marker: Instance): Instance?
    if not Marker:IsA("ObjectValue") or Marker.Name ~= SIGN_PARENT_MARKER_NAME then
        return nil
    end

    local SignRef = Marker:FindFirstChild(SIGN_MARKER_SIGN_REF_NAME)

    if SignRef and SignRef:IsA("ObjectValue") then
        return SignRef.Value
    end

    return nil
end

local function Reparent_Plot_Sign(Root: Instance, Hidden: boolean)
    local Folder = Get_Hidden_Plot_Signs_Folder()

    if Hidden then
        if Root.Parent == Folder then
            return
        end

        if not OriginalParents[Root] and Root.Parent then
            OriginalParents[Root] = Root.Parent
        end

        local OriginalParent = OriginalParents[Root]

        if OriginalParent then
            Create_Plot_Sign_Marker(Root, OriginalParent, Folder)
        end

        Root.Parent = Folder
        return
    end

    local Marker = Get_Plot_Sign_Marker(Root)
    local OriginalParent = OriginalParents[Root] or (if Marker and Marker:IsA("ObjectValue") then Marker.Value else nil)

    if OriginalParent and OriginalParent.Parent then
        Root.Parent = OriginalParent
    end

    OriginalParents[Root] = nil

    if Marker then
        Marker:Destroy()
    end
end

local function Restore_Reparented_Plot_Signs(Root: Instance)
    local SignsToRestore = {}
    local QueuedSigns = {}

    local function Queue_Sign(SignRoot: Instance?)
        if not SignRoot or QueuedSigns[SignRoot] then
            return
        end

        QueuedSigns[SignRoot] = true
        table.insert(SignsToRestore, SignRoot)
    end

    for SignRoot, OriginalParent in OriginalParents do
        if OriginalParent == Root or OriginalParent:IsDescendantOf(Root) then
            Queue_Sign(SignRoot)
        end
    end

    local Folder = ReplicatedStorage:FindFirstChild(HIDDEN_PLOT_SIGNS_FOLDER_NAME)

    if Folder then
        for _, Marker in Folder:GetChildren() do
            if not Marker:IsA("ObjectValue") or Marker.Name ~= SIGN_PARENT_MARKER_NAME then
                continue
            end

            local OriginalParent = Marker.Value

            if OriginalParent and (OriginalParent == Root or OriginalParent:IsDescendantOf(Root)) then
                Queue_Sign(Get_Marker_Sign(Marker))
            end
        end

        for _, SignRoot in Folder:GetChildren() do
            if not Is_Reparent_Only_Root(SignRoot) or Get_Plot_Sign_Marker(SignRoot) then
                continue
            end

            local OriginalParent = Infer_Reparented_Sign_Parent(SignRoot)

            if OriginalParent then
                OriginalParents[SignRoot] = OriginalParent
            end

            if OriginalParent and (OriginalParent == Root or OriginalParent:IsDescendantOf(Root)) then
                Queue_Sign(SignRoot)
            end
        end
    end

    for _, SignRoot in SignsToRestore do
        Reparent_Plot_Sign(SignRoot, false)
    end
end

local function Get_Home_Billboard_Template(): BillboardGui?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Billboards = Assets and Assets:FindFirstChild("Billboards")
    local Home = Billboards and Billboards:FindFirstChild(HOME_BILLBOARD_NAME)

    return if Home and Home:IsA("BillboardGui") then Home else nil
end

local function Get_Spawn_Billboard_Holder(Candidate: Instance?): Instance?
    if not Candidate then
        return nil
    end

    if Candidate:IsA("BasePart") or Candidate:IsA("Attachment") then
        return Candidate
    end

    if Candidate:IsA("Model") and Candidate.PrimaryPart then
        return Candidate.PrimaryPart
    end

    for _, Descendant in Candidate:GetDescendants() do
        if Descendant:IsA("BasePart") or Descendant:IsA("Attachment") then
            return Descendant
        end
    end

    return nil
end

local function Get_Home_Billboard_Holder(Plot: Instance?): Instance?
    if not Plot then
        return nil
    end

    local DirectSpawn = Plot:FindFirstChild("Spawn")
    local Holder = Get_Spawn_Billboard_Holder(DirectSpawn)

    if Holder then
        return Holder
    end

    for _, Descendant in Plot:GetDescendants() do
        if Descendant.Name ~= "Spawn" then
            continue
        end

        Holder = Get_Spawn_Billboard_Holder(Descendant)

        if Holder then
            return Holder
        end
    end

    return nil
end

local function Sync_Home_Billboard(LocalPlot: Instance?)
    local Holder = Get_Home_Billboard_Holder(LocalPlot)

    if not Holder then
        if HomeBillboard then
            HomeBillboard:Destroy()
            HomeBillboard = nil
            HomeBillboardParent = nil
        end

        return
    end

    if HomeBillboard and HomeBillboard.Parent == Holder and HomeBillboardParent == Holder then
        HomeBillboard.Enabled = true
        return
    end

    if HomeBillboard then
        HomeBillboard:Destroy()
        HomeBillboard = nil
        HomeBillboardParent = nil
    end

    local Template = Get_Home_Billboard_Template()

    if not Template then
        return
    end

    local Billboard = Template:Clone()

    Billboard.Name = HOME_BILLBOARD_NAME
    Billboard.Enabled = true
    Billboard.Parent = Holder

    HomeBillboard = Billboard
    HomeBillboardParent = Holder
end

local function Get_Local_Player_Plot(): Instance?
    local PlotsFolder = Get_Plots()

    if not PlotsFolder then
        return nil
    end

    for _, Plot in PlotsFolder:GetChildren() do
        if Plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return Plot
        end
    end

    local ExpectedTitle = `{LocalPlayer.Name}'s Plot`

    for _, Plot in PlotsFolder:GetChildren() do
        local OwnerSign = Plot:FindFirstChild("OwnerSign")
        local Title = OwnerSign and OwnerSign:FindFirstChild("Title", true)

        if Title and Title:IsA("TextLabel") and Title.Text == ExpectedTitle then
            return Plot
        end
    end

    return nil
end

local function Save_State(InstanceToSave: Instance, State: OriginalState)
    if OriginalStates[InstanceToSave] then
        return
    end

    OriginalStates[InstanceToSave] = State
end

local function Has_Enabled_Property(InstanceToCheck: Instance): boolean
    return InstanceToCheck:IsA("LayerCollector")
        or InstanceToCheck:IsA("ProximityPrompt")
        or InstanceToCheck:IsA("ParticleEmitter")
        or InstanceToCheck:IsA("Trail")
        or InstanceToCheck:IsA("Beam")
        or InstanceToCheck:IsA("Light")
        or InstanceToCheck:IsA("Highlight")
end

local function Hide_Instance(InstanceToHide: Instance)
    if InstanceToHide:IsA("BasePart") then
        Save_State(InstanceToHide, {
            CanCollide = InstanceToHide.CanCollide,
            CanTouch = InstanceToHide.CanTouch,
            CanQuery = InstanceToHide.CanQuery,
        })
        InstanceToHide.LocalTransparencyModifier = HIDDEN_BASE_PART_LOCAL_TRANSPARENCY
        InstanceToHide.CanCollide = false
        InstanceToHide.CanTouch = false
        InstanceToHide.CanQuery = false
    elseif InstanceToHide:IsA("Decal") or InstanceToHide:IsA("Texture") then
        Save_State(InstanceToHide, {
            Transparency = InstanceToHide.Transparency,
        })
        InstanceToHide.Transparency = 1
    elseif InstanceToHide:IsA("LayerCollector") then
        Save_State(InstanceToHide, {
            Enabled = InstanceToHide.Enabled,
        })
        InstanceToHide.Enabled = false
    elseif InstanceToHide:IsA("GuiObject") then
        Save_State(InstanceToHide, {
            Visible = InstanceToHide.Visible,
        })
        InstanceToHide.Visible = false
    elseif Has_Enabled_Property(InstanceToHide) then
        local EnabledInstance = InstanceToHide :: any

        Save_State(InstanceToHide, {
            Enabled = EnabledInstance.Enabled,
        })
        EnabledInstance.Enabled = false
    end
end

local function Restore_Instance(InstanceToRestore: Instance)
    if InstanceToRestore:IsA("BasePart") then
        local State = OriginalStates[InstanceToRestore]

        InstanceToRestore.LocalTransparencyModifier = 0

        if State then
            if State.CanCollide ~= nil then
                InstanceToRestore.CanCollide = State.CanCollide
            end

            if State.CanTouch ~= nil then
                InstanceToRestore.CanTouch = State.CanTouch
            end

            if State.CanQuery ~= nil then
                InstanceToRestore.CanQuery = State.CanQuery
            end

            OriginalStates[InstanceToRestore] = nil
        end

        return
    end

    local State = OriginalStates[InstanceToRestore]

    if not State then
        return
    end

    if (InstanceToRestore:IsA("Decal") or InstanceToRestore:IsA("Texture")) and State.Transparency ~= nil then
        InstanceToRestore.Transparency = State.Transparency
    elseif InstanceToRestore:IsA("GuiObject") and State.Visible ~= nil then
        InstanceToRestore.Visible = State.Visible
    elseif Has_Enabled_Property(InstanceToRestore) and State.Enabled ~= nil then
        (InstanceToRestore :: any).Enabled = State.Enabled
    end

    OriginalStates[InstanceToRestore] = nil
end

local function Restore_Hidden_State_Tree(Root: Instance)
    Restore_Instance(Root)

    for _, Descendant in Root:GetDescendants() do
        Restore_Instance(Descendant)
    end
end

local function Set_Root_Hidden(Root: Instance, Hidden: boolean)
    if Is_Reparent_Only_Root(Root) then
        Reparent_Plot_Sign(Root, Hidden)

        if not Hidden then
            Restore_Hidden_State_Tree(Root)
        end

        return
    end

    if not Hidden then
        Restore_Reparented_Plot_Signs(Root)
    end

    if Hidden then
        Hide_Instance(Root)
    else
        Restore_Instance(Root)
    end

    for _, Descendant in Root:GetDescendants() do
        if Is_Plot_Sign_Root(Descendant) then
            Reparent_Plot_Sign(Descendant, Hidden)
            continue
        end

        if Has_Plot_Sign_Ancestor(Descendant, Root) then
            continue
        end

        if Hidden then
            Hide_Instance(Descendant)
        else
            Restore_Instance(Descendant)
        end
    end
end

local function Sync_Plot_Visibility(Plot: Instance, LocalPlot: Instance?)
    local TutorialActive = Is_Tutorial_Active()

    if FullyHiddenPlots[Plot] then
        FullyHiddenPlots[Plot] = nil
        Set_Root_Hidden(Plot, false)
    end

    Restore_Reparented_Plot_Signs(Plot)

    for _, Root in Get_Target_Roots(Plot) do
        local ShouldHide = if TutorialActive
            then Plot == LocalPlot and Is_Tutorial_Hidden_Root(Root)
            else Plot ~= LocalPlot

        Set_Root_Hidden(Root, ShouldHide)
    end
end

local function Sync_All_Plots()
    local PlotsFolder = Get_Plots()

    if not PlotsFolder then
        return
    end

    local LocalPlot = Get_Local_Player_Plot()

    Sync_Home_Billboard(LocalPlot)

    for _, Plot in PlotsFolder:GetChildren() do
        Sync_Plot_Visibility(Plot, LocalPlot)
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        local Now = os.clock()

        if Now - LastScanAt < SCAN_INTERVAL then
            return
        end

        LastScanAt = Now
        Sync_All_Plots()
    end,
    runConditions = {},
}
