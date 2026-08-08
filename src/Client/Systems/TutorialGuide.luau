local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local peek = Fusion.peek

local Confetti = require(ReplicatedStorage.Shared.Modules.Confetti)
local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local LocalNotifications = require(script.Parent.Parent.Modules.LocalNotifications)
local Network = require(ReplicatedFirst.Network)
local Phases = require(ReplicatedStorage.Shared.Phases)
local ScreenDarkener = require(script.Parent.Parent.Modules.ScreenDarkener)
local TutorialSteps = require(ReplicatedStorage.Shared.Modules.TutorialSteps)

local LocalPlayer = Players.LocalPlayer
local TYPEWRITER_DELAY_SECONDS = 0.025
local TUTORIAL_ACTIVE_ATTRIBUTE = "TutorialActive"
local TUTORIAL_SCREEN_GUI_NAME = "Tutorial"
local ARROW_BEAM_NAME = "TutorialArrowBeam"
local ROOT_ATTACHMENT_NAME = "TutorialRootAttachment"
local TARGET_ATTACHMENT_NAME = "TutorialTargetAttachment"
local PLOT_SQUISHY_FOLDER_NAME = "PlotSquishies"
local CATCH_MINIGAME_ACTIVE_ATTRIBUTE = "CatchMinigameActive"
local CATCH_LASSO_LOCKED_ATTRIBUTE = "CatchLassoLocked"
local UI_DARKENER_PADDING = 55
local EQUIP_DARKENER_PADDING = 32
local PLACE_DARKENER_PADDING = 30
local WORLD_DARKENER_PADDING = 55
local CATCH_TARGET_DARKENER_PADDING = 85
local FEED_DARKENER_PADDING = 100
local PLOT_WALK_STOP_DISTANCE = 6
local PLOT_WALK_RETRY_INTERVAL = 0.5
local PLOT_WALK_TARGET_EPSILON = 1.5
local SUBEVENT_RETRY_INTERVAL = 0.75
local SUBEVENT_REACHED_TARGET_DISTANCE = 24
local SUBEVENT_REACHED_PLOT_DISTANCE = 12
local SUBEVENT_REACHED_FEED_DISTANCE = 18
local CUSTOM_HOTBAR_SLOT_MIN = 3
local CUSTOM_HOTBAR_SLOT_MAX = 7
local ROAMING_TARGET_SWITCH_MIN_DISTANCE_GAIN = 12
local ROAMING_TARGET_SWITCH_RATIO = 0.82
local WORLD_DARKENER_TARGET_NAME = "TutorialWorldDarkenerTarget"
local WORLD_DARKENER_MIN_SIZE = Vector3.new(4, 4, 4)

local MainGui: ScreenGui? = nil
local TutorialScreenGui: ScreenGui? = nil
local TutorialFrame: GuiObject? = nil
local TutorialLabel: TextLabel? = nil
local ActiveBeam: Beam? = nil
local BeamTargetAttachment: Attachment? = nil
local CreatedTargetAttachment: Attachment? = nil
local Darkener: any = nil
local DarkenerTarget: Instance? = nil
local WorldDarkenerTargetPart: Part? = nil
local CurrentTypedText: string? = nil
local TypeToken = 0
local LastStep: number? = nil
local CompletionConfettiPlayed = false
local CompletionNotificationPlayed = false
local HiddenStates: { [GuiObject]: boolean } = {}
local HiddenGuiWasActive = false
local StickyRoamingTargets: { [number]: Instance } = {}
local LastPlotMoveToAt = 0
local PlotMoveCompletedStep: number? = nil
local SubeventLastFiredAt: { [string]: number } = {}

local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local CONFETTI_EFFECT_LIFETIME = 5

local HIDDEN_MAIN_PATHS = table.freeze({
    { "Hud Frame", "2x Money" },
    { "Hud Frame", "ProPack" },
    { "Hud Frame", "TimeSkip" },
    { "Hud Frame", "EventInfo" },
    { "Hud Frame", "Right_Corner" },
    { "Hud Frame", "RightButtons", "StarterPack" },
    { "Hud Frame", "Buttons", "Shop" },
    { "Hud Frame", "Buttons", "Index" },
    { "Hud Frame", "Buttons", "Rewards" },
    { "EdgeLayer", "Plot" },
    { "Frames", "DailyRewards" },
    { "Frames", "Shop" },
    { "Frames", "Index" },
    { "Frames", "PlaytimeRewards" },
})

local FORCE_VISIBLE_AFTER_TUTORIAL_PATHS = table.freeze({
    { "Hud Frame", "Buttons", "Shop" },
    { "Hud Frame", "Buttons", "Index" },
    { "Hud Frame", "Buttons", "Rewards" },
})

local function Find_Path(Root: Instance?, Path: { string }): Instance?
    local Current = Root

    for _, Name in Path do
        Current = Current and Current:FindFirstChild(Name) or nil

        if not Current then
            return nil
        end
    end

    return Current
end

local function Get_Main_Gui(): ScreenGui?
    if MainGui and MainGui.Parent then
        return MainGui
    end

    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Candidate = PlayerGui and PlayerGui:FindFirstChild("Main")

    MainGui = if Candidate and Candidate:IsA("ScreenGui") then Candidate else nil

    return MainGui
end

local function Is_Frame_Open(FrameName: string): boolean
    local Main = Get_Main_Gui()
    local Frames = Main and Main:FindFirstChild("Frames")
    local Frame = Frames and Frames:FindFirstChild(FrameName)

    return Frame ~= nil and Frame:IsA("GuiObject") and Frame.Visible
end

local function Get_Tutorial_Screen_Gui(): ScreenGui?
    if TutorialScreenGui and TutorialScreenGui.Parent then
        return TutorialScreenGui
    end

    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")

    if not PlayerGui then
        return nil
    end

    for _, Name in { TUTORIAL_SCREEN_GUI_NAME, string.lower(TUTORIAL_SCREEN_GUI_NAME) } do
        local Candidate = PlayerGui:FindFirstChild(Name)

        if Candidate and Candidate:IsA("ScreenGui") then
            TutorialScreenGui = Candidate
            return Candidate
        end
    end

    for _, Candidate in PlayerGui:GetChildren() do
        if
            Candidate:IsA("ScreenGui")
            and Candidate.Name ~= "Main"
            and string.find(string.lower(Candidate.Name), "tutorial")
        then
            TutorialScreenGui = Candidate
            return Candidate
        end
    end

    return nil
end

local function Ensure_Tutorial_Gui_Order(Gui: ScreenGui)
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Visuals = PlayerGui and PlayerGui:FindFirstChild("Visuals")

    if Visuals and Visuals:IsA("ScreenGui") and Gui.DisplayOrder <= Visuals.DisplayOrder then
        Gui.DisplayOrder = Visuals.DisplayOrder + 1
    end
end

local function Find_Tutorial_Frame(Root: Instance): GuiObject?
    local Direct = Root:FindFirstChild("Tutorial")

    if Direct and Direct:IsA("GuiObject") then
        return Direct
    end

    local MainLabel = Root:FindFirstChild("Main", true)

    if MainLabel and MainLabel:IsA("TextLabel") and MainLabel.Parent and MainLabel.Parent:IsA("GuiObject") then
        return MainLabel.Parent
    end

    local FirstObject = Root:FindFirstChildWhichIsA("GuiObject", true)

    return if FirstObject and FirstObject:IsA("GuiObject") then FirstObject else nil
end

local function Get_Tutorial_Label(): TextLabel?
    local TutorialGui = Get_Tutorial_Screen_Gui()
    local Frame: GuiObject? = nil

    if TutorialGui then
        Ensure_Tutorial_Gui_Order(TutorialGui)
        Frame = Find_Tutorial_Frame(TutorialGui)
    end

    if not Frame then
        local Main = Get_Main_Gui()
        local Hud = Main and Main:FindFirstChild("Hud Frame")
        local Candidate = Hud and Hud:FindFirstChild("Tutorial")

        Frame = if Candidate and Candidate:IsA("GuiObject") then Candidate else nil
    end

    if not Frame or not Frame:IsA("GuiObject") then
        return nil
    end

    TutorialFrame = Frame

    local Label = Frame:FindFirstChild("Main")

    if Label and Label:IsA("TextLabel") then
        TutorialLabel = Label
        return Label
    end

    Label = Frame:FindFirstChildWhichIsA("TextLabel", true)

    TutorialLabel = if Label and Label:IsA("TextLabel") then Label else nil

    return TutorialLabel
end

local function Play_Ui_Sound(SoundName: string)
    local UiSounds = SoundService:FindFirstChild("UI")
    local Sound = UiSounds and UiSounds:FindFirstChild(SoundName)

    if not Sound or not Sound:IsA("Sound") then
        return
    end

    Sound:Stop()
    Sound.TimePosition = 0
    Sound:Play()
end

local function Type_Text(Text: string)
    if CurrentTypedText == Text then
        return
    end

    CurrentTypedText = Text
    TypeToken += 1

    local Token = TypeToken
    local Label = Get_Tutorial_Label()

    if not Label then
        return
    end

    Label.Text = ""

    task.spawn(function()
        for Index = 1, #Text do
            if Token ~= TypeToken then
                return
            end

            local Character = string.sub(Text, Index, Index)
            Label.Text = string.sub(Text, 1, Index)

            if not string.match(Character, "%s") then
                Play_Ui_Sound("TypeWriter")
            end

            task.wait(TYPEWRITER_DELAY_SECONDS)
        end
    end)
end

local function Set_Gui_Hidden(Object: Instance?, Hidden: boolean)
    if not Object or not Object:IsA("GuiObject") then
        return
    end

    if Hidden then
        if HiddenStates[Object] == nil then
            HiddenStates[Object] = Object.Visible
        end

        Object.Visible = false
        return
    end

    local WasVisible = HiddenStates[Object]

    if WasVisible == nil then
        return
    end

    Object.Visible = WasVisible
    HiddenStates[Object] = nil
end

local function Apply_Hidden_Gui(Active: boolean)
    local Main = Get_Main_Gui()

    if Active then
        HiddenGuiWasActive = true

        for _, Path in HIDDEN_MAIN_PATHS do
            Set_Gui_Hidden(Find_Path(Main, Path), true)
        end

        return
    end

    if not HiddenGuiWasActive and next(HiddenStates) == nil then
        return
    end

    local Objects = {}

    for Object in HiddenStates do
        table.insert(Objects, Object)
    end

    for _, Object in Objects do
        Set_Gui_Hidden(Object, false)
    end

    for _, Path in FORCE_VISIBLE_AFTER_TUTORIAL_PATHS do
        local Object = Find_Path(Main, Path)

        if Object and Object:IsA("GuiObject") then
            Object.Visible = true
        end
    end

    HiddenGuiWasActive = false
end

local function Get_Catch_Prompt_Text(): string
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        return "Tap for squishy"
    end

    return "Click for squishy"
end

local function Get_Owned_Tutorial_Squishy_Id(Role: string): string?
    local OwnedSquishies = peek(FusionValues.OwnedSquishies)

    if type(OwnedSquishies) ~= "table" then
        return nil
    end

    for _, Item in OwnedSquishies do
        if type(Item) == "table" and Item.TutorialRole == Role and type(Item.Id) == "string" then
            return Item.Id
        end
    end

    return nil
end

local function Has_Owned_Tutorial_Squishy(Role: string): boolean
    return Get_Owned_Tutorial_Squishy_Id(Role) ~= nil
end

local function Owns_Tutorial_Food(): boolean
    local OwnedFood = peek(FusionValues.OwnedFood)

    if type(OwnedFood) ~= "table" then
        return false
    end

    for _, Item in OwnedFood do
        if
            type(Item) == "table"
            and Item.Id == TutorialSteps.FeedName
            and type(Item.Amount) == "number"
            and Item.Amount > 0
        then
            return true
        end
    end

    return false
end

local function Get_Tutorial_Display_Text(Step: number): string
    if
        (Step == TutorialSteps.CatchFirst or Step == TutorialSteps.CatchStrong)
        and LocalPlayer:GetAttribute(CATCH_MINIGAME_ACTIVE_ATTRIBUTE) == true
    then
        return Get_Catch_Prompt_Text()
    end

    if Step == TutorialSteps.CatchStrong then
        if Has_Owned_Tutorial_Squishy(TutorialSteps.StrongRole) then
            return "Go to your pen and place the stronger Squishy."
        end

        return "Catch a stronger Squishy."
    end

    if Step == TutorialSteps.FeedStrong then
        return if Owns_Tutorial_Food() then "Feed your stronger Squishy." else "Buy Farmers Feed."
    end

    if Step == TutorialSteps.SellOld then
        return if Has_Owned_Tutorial_Squishy(TutorialSteps.FirstRole)
            then "Sell your old Squishy."
            else "Equip your hammer, then pick up your old Squishy."
    end

    return TutorialSteps.Get_Text(Step) or ""
end

local function Get_Arrow_Beam_Template(): Beam?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")

    if not Assets then
        return nil
    end

    for _, FolderName in { "Effects", "VFX" } do
        local Folder = Assets:FindFirstChild(FolderName)
        local Beam = Folder and Folder:FindFirstChild("ArrowBeam")

        if Beam and Beam:IsA("Beam") then
            return Beam
        end
    end

    local Beam = Assets:FindFirstChild("ArrowBeam")

    return if Beam and Beam:IsA("Beam") then Beam else nil
end

local function Get_Base_Target(InstanceToCheck: Instance?): Instance?
    if not InstanceToCheck then
        return nil
    end

    if InstanceToCheck:IsA("BasePart") or InstanceToCheck:IsA("Attachment") then
        return InstanceToCheck
    end

    if InstanceToCheck:IsA("Model") and InstanceToCheck.PrimaryPart then
        return InstanceToCheck.PrimaryPart
    end

    for _, Descendant in InstanceToCheck:GetDescendants() do
        if Descendant:IsA("BasePart") or Descendant:IsA("Attachment") then
            return Descendant
        end
    end

    return nil
end

local function Find_First_Base_Part(InstanceToCheck: Instance?): BasePart?
    if not InstanceToCheck then
        return nil
    end

    if InstanceToCheck:IsA("BasePart") then
        return InstanceToCheck
    end

    if InstanceToCheck:IsA("Attachment") then
        local Parent = InstanceToCheck.Parent

        return if Parent and Parent:IsA("BasePart") then Parent else nil
    end

    if InstanceToCheck:IsA("Model") then
        if InstanceToCheck.PrimaryPart then
            return InstanceToCheck.PrimaryPart
        end

        for _, Name in { "HumanoidRootPart", "RootPart", "Root", "Handle" } do
            local Root = InstanceToCheck:FindFirstChild(Name, true)

            if Root and Root:IsA("BasePart") then
                return Root
            end
        end
    end

    return InstanceToCheck:FindFirstChildWhichIsA("BasePart", true)
end

local function Get_Instance_Position(InstanceToCheck: Instance?): Vector3?
    if not InstanceToCheck then
        return nil
    end

    if InstanceToCheck:IsA("BasePart") then
        return InstanceToCheck.Position
    end

    if InstanceToCheck:IsA("Attachment") then
        return InstanceToCheck.WorldPosition
    end

    if InstanceToCheck:IsA("Model") then
        return InstanceToCheck:GetPivot().Position
    end

    local Part = Find_First_Base_Part(InstanceToCheck)

    return if Part then Part.Position else nil
end

local function Get_Root_Part(): BasePart?
    local Character = LocalPlayer.Character
    local Root = Character and (Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart)

    return if Root and Root:IsA("BasePart") then Root else nil
end

local function Get_Root_Attachment(): Attachment?
    local Root = Get_Root_Part()

    if not Root then
        return nil
    end

    local Attachment = Root:FindFirstChild(ROOT_ATTACHMENT_NAME)

    if Attachment and Attachment:IsA("Attachment") then
        return Attachment
    end

    local NewAttachment = Instance.new("Attachment")

    NewAttachment.Name = ROOT_ATTACHMENT_NAME
    NewAttachment.Parent = Root

    return NewAttachment
end

local function Clear_Created_Target_Attachment(KeepAttachment: Attachment?)
    if CreatedTargetAttachment and CreatedTargetAttachment ~= KeepAttachment and CreatedTargetAttachment.Parent then
        CreatedTargetAttachment:Destroy()
    end

    if CreatedTargetAttachment ~= KeepAttachment then
        CreatedTargetAttachment = nil
    end
end

local function Get_Target_Attachment(Target: Instance?): Attachment?
    Target = Get_Base_Target(Target)

    if not Target then
        Clear_Created_Target_Attachment(nil)
        return nil
    end

    if Target:IsA("Attachment") then
        Clear_Created_Target_Attachment(Target)
        return Target
    end

    if not Target:IsA("BasePart") then
        Clear_Created_Target_Attachment(nil)
        return nil
    end

    local Attachment = Target:FindFirstChild(TARGET_ATTACHMENT_NAME)

    if Attachment and Attachment:IsA("Attachment") then
        Clear_Created_Target_Attachment(Attachment)
        return Attachment
    end

    Clear_Created_Target_Attachment(nil)

    local NewAttachment = Instance.new("Attachment")

    NewAttachment.Name = TARGET_ATTACHMENT_NAME
    NewAttachment.Parent = Target
    CreatedTargetAttachment = NewAttachment

    return NewAttachment
end

local function Clear_Arrow()
    if ActiveBeam then
        ActiveBeam:Destroy()
        ActiveBeam = nil
    end

    BeamTargetAttachment = nil
    Clear_Created_Target_Attachment(nil)
end

local function Set_Arrow_Target(Target: Instance?)
    local RootAttachment = Get_Root_Attachment()
    local TargetAttachment = Get_Target_Attachment(Target)
    local Template = Get_Arrow_Beam_Template()

    if not RootAttachment or not TargetAttachment or not Template then
        Clear_Arrow()
        return
    end

    if not ActiveBeam or not ActiveBeam.Parent then
        ActiveBeam = Template:Clone()
        ActiveBeam.Name = ARROW_BEAM_NAME
        ActiveBeam.Parent = RootAttachment.Parent
    elseif ActiveBeam.Parent ~= RootAttachment.Parent then
        ActiveBeam.Parent = RootAttachment.Parent
    end

    if
        BeamTargetAttachment == TargetAttachment
        and ActiveBeam.Attachment0 == RootAttachment
        and ActiveBeam.Attachment1 == TargetAttachment
    then
        return
    end

    ActiveBeam.Attachment0 = RootAttachment
    ActiveBeam.Attachment1 = TargetAttachment
    ActiveBeam.Enabled = true
    BeamTargetAttachment = TargetAttachment
end

local function Get_Root_Position(): Vector3?
    local Root = Get_Root_Part()

    return Root and Root.Position or nil
end

local function Get_Flat_Distance(Left: Vector3, Right: Vector3): number
    return Vector3.new(Left.X - Right.X, 0, Left.Z - Right.Z).Magnitude
end

local function Is_Player_Near_Instance(Target: Instance?, MaxDistance: number): boolean
    local RootPosition = Get_Root_Position()
    local TargetPosition = Get_Instance_Position(Target)

    return RootPosition ~= nil
        and TargetPosition ~= nil
        and Get_Flat_Distance(RootPosition, TargetPosition) <= MaxDistance
end

local function Is_Tutorial_Roaming_Target(Model: Model, Step: number): boolean
    local TargetUserId = Model:GetAttribute(TutorialSteps.TargetUserIdAttribute)
    local TargetStep = Model:GetAttribute(TutorialSteps.TargetStepAttribute)
    local Rarity = Model:GetAttribute("Rarity")

    if TargetUserId ~= LocalPlayer.UserId then
        return false
    end

    if TargetStep ~= Step then
        return false
    end

    return TutorialSteps.Is_Catch_Rarity_Allowed(Step, Rarity)
end

local function Get_Model_From_Target(Target: Instance?): Model?
    local Current = Target

    while Current and Current ~= workspace do
        if Current:IsA("Model") then
            return Current
        end

        Current = Current.Parent
    end

    return nil
end

local function Is_Sticky_Roaming_Target_Valid(Step: number, Target: Instance?): boolean
    if not Target or not Target.Parent then
        return false
    end

    local Model = Get_Model_From_Target(Target)

    return Model ~= nil and Is_Tutorial_Roaming_Target(Model, Step)
end

local function Get_Nearest_Roaming_Target(Step: number): Instance?
    local Folder = workspace:FindFirstChild("RoamingSquishies")
    local RootPosition = Get_Root_Position()
    local BestTarget = nil
    local BestDistance = math.huge

    if not Folder then
        return nil
    end

    for _, Child in Folder:GetChildren() do
        if not Child:IsA("Model") then
            continue
        end

        if not Is_Tutorial_Roaming_Target(Child, Step) then
            continue
        end

        local Target = Find_First_Base_Part(Child)

        if not Target or not Target:IsA("BasePart") then
            continue
        end

        local Distance = if RootPosition then (Target.Position - RootPosition).Magnitude else 0

        if Distance < BestDistance then
            BestDistance = Distance
            BestTarget = Target
        end
    end

    return BestTarget
end

local function Get_Target_Distance(Target: Instance?, RootPosition: Vector3?): number?
    if not Target or not Target:IsA("BasePart") or not RootPosition then
        return nil
    end

    return (Target.Position - RootPosition).Magnitude
end

local function Should_Switch_Roaming_Target(CurrentTarget: Instance?, NewTarget: Instance?): boolean
    if CurrentTarget == NewTarget or not NewTarget then
        return false
    end

    local RootPosition = Get_Root_Position()
    local CurrentDistance = Get_Target_Distance(CurrentTarget, RootPosition)
    local NewDistance = Get_Target_Distance(NewTarget, RootPosition)

    if not CurrentDistance or not NewDistance then
        return false
    end

    local DistanceGain = CurrentDistance - NewDistance

    return DistanceGain >= ROAMING_TARGET_SWITCH_MIN_DISTANCE_GAIN
        and NewDistance <= CurrentDistance * ROAMING_TARGET_SWITCH_RATIO
end

local function Get_Stable_Roaming_Target(Step: number): Instance?
    local ExistingTarget = StickyRoamingTargets[Step]

    if Is_Sticky_Roaming_Target_Valid(Step, ExistingTarget) then
        local NewTarget = Get_Nearest_Roaming_Target(Step)

        if Should_Switch_Roaming_Target(ExistingTarget, NewTarget) then
            StickyRoamingTargets[Step] = NewTarget :: Instance
            return NewTarget
        end

        return ExistingTarget
    end

    local NewTarget = Get_Nearest_Roaming_Target(Step)

    if NewTarget then
        StickyRoamingTargets[Step] = NewTarget
    else
        StickyRoamingTargets[Step] = nil
    end

    return NewTarget
end

local function Get_Local_Player_Plot(): Instance?
    local Plots = workspace:FindFirstChild("Plots")

    if not Plots then
        return nil
    end

    for _, Plot in Plots:GetChildren() do
        if Plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return Plot
        end
    end

    local ExpectedTitle = `{LocalPlayer.Name}'s Plot`

    for _, Plot in Plots:GetChildren() do
        local OwnerSign = Plot:FindFirstChild("OwnerSign")
        local Title = OwnerSign and OwnerSign:FindFirstChild("Title", true)

        if Title and Title:IsA("TextLabel") and Title.Text == ExpectedTitle then
            return Plot
        end
    end

    return nil
end

local function Get_Plot_Spawn_Part(Plot: Instance): BasePart?
    for _, Name in { "Spawn", "SpawnPart", "Spawn Part" } do
        local Candidate = Plot:FindFirstChild(Name, true)

        if Candidate and Candidate:IsA("BasePart") then
            return Candidate
        end
    end

    return nil
end

local function Get_Plot_Spawn_Target(): Attachment?
    local Plot = Get_Local_Player_Plot()
    local Spawn = if Plot then Get_Plot_Spawn_Part(Plot) else nil

    if not Spawn then
        return nil
    end

    for _, Name in { TARGET_ATTACHMENT_NAME, "TutorialAttachment", "Attachment" } do
        local Attachment = Spawn:FindFirstChild(Name)

        if Attachment and Attachment:IsA("Attachment") then
            return Attachment
        end
    end

    local Attachment = Instance.new("Attachment")

    Attachment.Name = TARGET_ATTACHMENT_NAME
    Attachment.Parent = Spawn

    return Attachment
end

local function Stop_Plot_Move()
    if LastPlotMoveToAt == 0 then
        return
    end

    LastPlotMoveToAt = 0

    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if Humanoid and Root and Root:IsA("BasePart") then
        Humanoid:MoveTo(Root.Position)
    end
end

local function Move_Character_To_Plot(Step: number)
    if PlotMoveCompletedStep == Step then
        return
    end

    local TargetAttachment = Get_Plot_Spawn_Target()
    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if not TargetAttachment or not Humanoid or not Root or not Root:IsA("BasePart") then
        return
    end

    local TargetPosition = TargetAttachment.WorldPosition
    local RootPosition = Root.Position
    local HorizontalDistance = (Vector3.new(RootPosition.X, 0, RootPosition.Z) - Vector3.new(
        TargetPosition.X,
        0,
        TargetPosition.Z
    )).Magnitude

    if HorizontalDistance <= PLOT_WALK_STOP_DISTANCE then
        PlotMoveCompletedStep = Step
        Stop_Plot_Move()
        return
    end

    local MovePosition = Vector3.new(TargetPosition.X, RootPosition.Y, TargetPosition.Z)

    if
        (Vector3.new(RootPosition.X, 0, RootPosition.Z) - Vector3.new(MovePosition.X, 0, MovePosition.Z)).Magnitude
        <= PLOT_WALK_TARGET_EPSILON
    then
        return
    end

    local Now = os.clock()

    if Now - LastPlotMoveToAt < PLOT_WALK_RETRY_INTERVAL then
        return
    end

    LastPlotMoveToAt = Now
    Humanoid:MoveTo(MovePosition)
end

local function Get_Plot_Target(Name: string): Instance?
    local Plot = Get_Local_Player_Plot()

    if not Plot then
        return nil
    end

    local Target = Plot:FindFirstChild(Name, true)

    if not Target then
        return nil
    end

    local Rig = Target:FindFirstChild("Rig", true)

    if Rig and Rig:IsA("Model") then
        for _, RootName in { "HumanoidRootPart", "RootPart", "Root" } do
            local Root = Rig:FindFirstChild(RootName, true)

            if Root and Root:IsA("BasePart") then
                return Root
            end
        end

        if Rig.PrimaryPart then
            return Rig.PrimaryPart
        end

        local Part = Rig:FindFirstChildWhichIsA("BasePart", true)

        if Part then
            return Part
        end
    end

    for _, RootName in { "HumanoidRootPart", "RootPart", "Root" } do
        local Root = Target:FindFirstChild(RootName, true)

        if Root and Root:IsA("BasePart") then
            return Root
        end
    end

    return Target
end

local function Get_Tutorial_Plot_Squishy(Role: string): Instance?
    local Folder = workspace:FindFirstChild(PLOT_SQUISHY_FOLDER_NAME)
    local Fallback: Model? = nil

    if not Folder then
        return nil
    end

    for _, Child in Folder:GetChildren() do
        if
            Child:IsA("Model")
            and Child:GetAttribute("PlotSquishyOwnerUserId") == LocalPlayer.UserId
            and Child:GetAttribute("TutorialRole") == Role
        then
            return Child
        end

        if
            Child:IsA("Model")
            and Child:GetAttribute("PlotSquishyOwnerUserId") == LocalPlayer.UserId
            and not Fallback
        then
            Fallback = Child
        end
    end

    return Fallback
end

local function Has_Placed_Tutorial_Squishy(Role: string): boolean
    local Folder = workspace:FindFirstChild(PLOT_SQUISHY_FOLDER_NAME)

    if not Folder then
        return false
    end

    for _, Child in Folder:GetChildren() do
        if
            Child:IsA("Model")
            and Child:GetAttribute("PlotSquishyOwnerUserId") == LocalPlayer.UserId
            and Child:GetAttribute("TutorialRole") == Role
        then
            return true
        end
    end

    return false
end

local function Get_World_Target(Step: number): Instance?
    if Step == TutorialSteps.CatchFirst then
        if LocalPlayer:GetAttribute(CATCH_LASSO_LOCKED_ATTRIBUTE) == true then
            return nil
        end

        return Get_Stable_Roaming_Target(Step)
    end

    if Step == TutorialSteps.CatchStrong then
        if Has_Owned_Tutorial_Squishy(TutorialSteps.StrongRole) then
            return Get_Plot_Spawn_Target()
        end

        if Has_Placed_Tutorial_Squishy(TutorialSteps.StrongRole) then
            return nil
        end

        if LocalPlayer:GetAttribute(CATCH_LASSO_LOCKED_ATTRIBUTE) == true then
            return nil
        end

        return Get_Stable_Roaming_Target(Step)
    end

    if Step == TutorialSteps.PlaceFirst or Step == TutorialSteps.PlaceStrong then
        return Get_Plot_Spawn_Target()
    end

    if Step == TutorialSteps.CollectCash then
        return Get_Tutorial_Plot_Squishy(TutorialSteps.FirstRole)
    end

    if Step == TutorialSteps.FeedStrong then
        if not Owns_Tutorial_Food() then
            if Is_Frame_Open("FoodShop") then
                return nil
            end

            return Get_Plot_Target("FoodShop")
        end

        return Get_Tutorial_Plot_Squishy(TutorialSteps.StrongRole)
    end

    if Step == TutorialSteps.BuyNextLasso then
        if Is_Frame_Open("LassoShop") then
            return nil
        end

        return Get_Plot_Target("LassoShop")
    end

    if Step == TutorialSteps.BuyFood then
        if Is_Frame_Open("FoodShop") then
            return nil
        end

        return Get_Plot_Target("FoodShop")
    end

    if Step == TutorialSteps.SellOld then
        if Has_Placed_Tutorial_Squishy(TutorialSteps.FirstRole) then
            return Get_Tutorial_Plot_Squishy(TutorialSteps.FirstRole)
        end

        return Get_Plot_Target("SellShop")
    end

    return nil
end

local function Get_Inventory_Item_Buttons(): Instance?
    local Main = Get_Main_Gui()

    for _, Path in
        {
            { "Frames", "Inventory", "Item Buttons" },
            { "Hud Frame", "Item Buttons" },
            { "Hud Frame", "Inventory", "Item Buttons" },
        }
    do
        local Candidate = Find_Path(Main, Path)

        if Candidate then
            return Candidate
        end
    end

    return nil
end

local function Get_Inventory_Button(ButtonName: string): GuiObject?
    local ItemButtons = Get_Inventory_Item_Buttons()
    local Candidate = ItemButtons and ItemButtons:FindFirstChild(ButtonName)

    return if Candidate and Candidate:IsA("GuiObject") then Candidate else nil
end

local function Get_Lasso_Button(): GuiObject?
    return Get_Inventory_Button("Lasso")
end

local function Get_Hammer_Button(): GuiObject?
    return Get_Inventory_Button("Hammer")
end

local function Is_Gui_Object_Visible(Object: GuiObject): boolean
    local Current: Instance? = Object

    while Current do
        if Current:IsA("GuiObject") and not Current.Visible then
            return false
        end

        if Current:IsA("ScreenGui") and not Current.Enabled then
            return false
        end

        Current = Current.Parent
    end

    return true
end

local function Get_Place_Button(): GuiObject?
    local Main = Get_Main_Gui()

    if not Main then
        return nil
    end

    for _, Path in
        {
            { "Hud Frame", "Place" },
            { "Hud Frame", "PlaceButton" },
            { "Hud Frame", "Place Button" },
            { "EdgeLayer", "Place" },
            { "EdgeLayer", "PlaceButton" },
            { "EdgeLayer", "Place Button" },
        }
    do
        local Candidate = Find_Path(Main, Path)

        if Candidate and Candidate:IsA("GuiObject") and Is_Gui_Object_Visible(Candidate) then
            return Candidate
        end
    end

    for _, Name in { "Place", "PlaceButton", "Place Button", "PlaceSquishy", "Place Squishy" } do
        local Candidate = Main:FindFirstChild(Name, true)

        if Candidate and Candidate:IsA("GuiObject") and Is_Gui_Object_Visible(Candidate) then
            return Candidate
        end
    end

    return nil
end

local function Get_Selected_Inventory_Slot(): string?
    local Slot = peek(FusionValues.EquippedInventorySlot)

    return if type(Slot) == "string" then Slot else nil
end

local function Get_Slot_Number_From_Name(SlotName: any): number?
    if type(SlotName) ~= "string" then
        return nil
    end

    if SlotName == "Lasso" then
        return 1
    elseif SlotName == "Hammer" then
        return 2
    end

    local Slot = tonumber(SlotName) or tonumber(string.match(SlotName, "^Item%s+(%d+)$"))

    if Slot and Slot >= CUSTOM_HOTBAR_SLOT_MIN and Slot <= CUSTOM_HOTBAR_SLOT_MAX then
        return Slot
    end

    return nil
end

local function Get_Hotbar_Assignment_For_Slot(Slot: number): any?
    local HotbarSlots = peek(FusionValues.HotbarSlots)

    if type(HotbarSlots) ~= "table" then
        return nil
    end

    for Key, Assignment in HotbarSlots do
        if type(Assignment) ~= "table" then
            continue
        end

        local AssignmentSlot = if type(Assignment.Slot) == "number" then Assignment.Slot else tonumber(Key)

        if AssignmentSlot == Slot then
            return Assignment
        end
    end

    return nil
end

local function Get_Equipped_Food_Item_Id(): string?
    local Slot = Get_Slot_Number_From_Name(peek(FusionValues.EquippedInventorySlot))

    if not Slot or Slot < CUSTOM_HOTBAR_SLOT_MIN then
        return nil
    end

    local Assignment = Get_Hotbar_Assignment_For_Slot(Slot)

    if type(Assignment) == "table" and Assignment.ItemType == "Food" and type(Assignment.ItemId) == "string" then
        return Assignment.ItemId
    end

    return nil
end

local function Fire_Tutorial_Subevent(SubeventName: string)
    if not TutorialSteps.Get_Subevent_Data(SubeventName) then
        return
    end

    local Now = os.clock()
    local LastFiredAt = SubeventLastFiredAt[SubeventName]

    if LastFiredAt and Now - LastFiredAt < SUBEVENT_RETRY_INTERVAL then
        return
    end

    SubeventLastFiredAt[SubeventName] = Now
    Network.TutorialSubevent.Fire(SubeventName)
end

local function Update_Tutorial_Subevents(Step: number, Active: boolean)
    if not Active then
        return
    end

    if
        Step == TutorialSteps.CatchFirst
        and Is_Player_Near_Instance(
            Get_Stable_Roaming_Target(TutorialSteps.CatchFirst),
            SUBEVENT_REACHED_TARGET_DISTANCE
        )
    then
        Fire_Tutorial_Subevent("ReachedFirstTutorialSquishy")
    end

    if
        (Step == TutorialSteps.PlaceFirst or Step == TutorialSteps.CollectCash)
        and Is_Player_Near_Instance(Get_Plot_Spawn_Target(), SUBEVENT_REACHED_PLOT_DISTANCE)
    then
        Fire_Tutorial_Subevent("ReachedPlotFirst")
    end

    if (Step == TutorialSteps.BuyNextLasso or Step == TutorialSteps.CatchStrong) and Is_Frame_Open("LassoShop") then
        Fire_Tutorial_Subevent("OpenedLassoShop")
    end

    if
        Step == TutorialSteps.CatchStrong
        and not Has_Owned_Tutorial_Squishy(TutorialSteps.StrongRole)
        and not Has_Placed_Tutorial_Squishy(TutorialSteps.StrongRole)
        and Is_Player_Near_Instance(
            Get_Stable_Roaming_Target(TutorialSteps.CatchStrong),
            SUBEVENT_REACHED_TARGET_DISTANCE
        )
    then
        Fire_Tutorial_Subevent("ReachedStrongTutorialSquishy")
    end

    if
        Step == TutorialSteps.CatchStrong
        and Has_Owned_Tutorial_Squishy(TutorialSteps.StrongRole)
        and Is_Player_Near_Instance(Get_Plot_Spawn_Target(), SUBEVENT_REACHED_PLOT_DISTANCE)
    then
        Fire_Tutorial_Subevent("ReachedPlotStrong")
    end

    if Step == TutorialSteps.FeedStrong and Is_Frame_Open("FoodShop") then
        Fire_Tutorial_Subevent("OpenedFoodShop")
    end

    if Step == TutorialSteps.FeedStrong and Get_Equipped_Food_Item_Id() == TutorialSteps.FeedName then
        Fire_Tutorial_Subevent("EquippedFarmersFeed")
    end

    if
        Step == TutorialSteps.FeedStrong
        and Is_Player_Near_Instance(Get_Tutorial_Plot_Squishy(TutorialSteps.StrongRole), SUBEVENT_REACHED_FEED_DISTANCE)
    then
        Fire_Tutorial_Subevent("ReachedFeedTarget")
    end
end

local function Can_Create_Darkener(): boolean
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Visuals = PlayerGui and PlayerGui:FindFirstChild("Visuals")

    return Visuals ~= nil and Visuals:FindFirstChild("CanvasGroup") ~= nil
end

local function Get_Or_Create_World_Darkener_Target(): Part
    if WorldDarkenerTargetPart and WorldDarkenerTargetPart.Parent then
        return WorldDarkenerTargetPart
    end

    local Part = Instance.new("Part")

    Part.Name = WORLD_DARKENER_TARGET_NAME
    Part.Anchored = true
    Part.CanCollide = false
    Part.CanQuery = false
    Part.CanTouch = false
    Part.CastShadow = false
    Part.Transparency = 1
    Part.Parent = workspace

    WorldDarkenerTargetPart = Part

    return Part
end

local function Get_Model_Darkener_Target(Model: Model): BasePart?
    if not Model.Parent then
        return nil
    end

    local BoundsCFrame, BoundsSize = Model:GetBoundingBox()
    local Target = Get_Or_Create_World_Darkener_Target()

    Target.CFrame = BoundsCFrame
    Target.Size = Vector3.new(
        math.max(BoundsSize.X, WORLD_DARKENER_MIN_SIZE.X),
        math.max(BoundsSize.Y, WORLD_DARKENER_MIN_SIZE.Y),
        math.max(BoundsSize.Z, WORLD_DARKENER_MIN_SIZE.Z)
    )

    return Target
end

local function Get_World_Darkener_Target(Target: Instance?): Instance?
    if Target and Target:IsA("Model") then
        return Get_Model_Darkener_Target(Target)
    end

    local Model = Get_Model_From_Target(Target)

    if Model then
        return Get_Model_Darkener_Target(Model)
    end

    return Find_First_Base_Part(Target)
end

local function Get_Catch_Darkener_Target(Step: number): Instance?
    return Get_World_Darkener_Target(Get_Stable_Roaming_Target(Step))
end

local function Get_Darkener_Target(Step: number, Active: boolean): (Instance?, number)
    if not Active then
        return nil, UI_DARKENER_PADDING
    end

    if Step == TutorialSteps.EquipLasso then
        if Get_Selected_Inventory_Slot() == "Lasso" then
            return nil, EQUIP_DARKENER_PADDING
        end

        return Get_Lasso_Button(), EQUIP_DARKENER_PADDING
    end

    if Step == TutorialSteps.PlaceFirst then
        local PlaceButton = Get_Place_Button()

        if PlaceButton then
            return PlaceButton, PLACE_DARKENER_PADDING
        end
    end

    if Step == TutorialSteps.CatchFirst then
        if Get_Selected_Inventory_Slot() ~= "Lasso" then
            local LassoButton = Get_Lasso_Button()

            if LassoButton then
                return LassoButton, EQUIP_DARKENER_PADDING
            end
        end

        if
            LocalPlayer:GetAttribute(CATCH_LASSO_LOCKED_ATTRIBUTE) == true
            or LocalPlayer:GetAttribute(CATCH_MINIGAME_ACTIVE_ATTRIBUTE) == true
        then
            return nil, CATCH_TARGET_DARKENER_PADDING
        end

        return Get_Catch_Darkener_Target(TutorialSteps.CatchFirst), CATCH_TARGET_DARKENER_PADDING
    end

    if Step == TutorialSteps.CatchStrong then
        if Has_Owned_Tutorial_Squishy(TutorialSteps.StrongRole) then
            local PlaceButton = Get_Place_Button()

            if PlaceButton then
                return PlaceButton, PLACE_DARKENER_PADDING
            end

            return nil, PLACE_DARKENER_PADDING
        end

        if Get_Selected_Inventory_Slot() ~= "Lasso" then
            local LassoButton = Get_Lasso_Button()

            if LassoButton then
                return LassoButton, EQUIP_DARKENER_PADDING
            end
        end

        if
            LocalPlayer:GetAttribute(CATCH_LASSO_LOCKED_ATTRIBUTE) == true
            or LocalPlayer:GetAttribute(CATCH_MINIGAME_ACTIVE_ATTRIBUTE) == true
        then
            return nil, CATCH_TARGET_DARKENER_PADDING
        end

        return Get_Catch_Darkener_Target(TutorialSteps.CatchStrong), CATCH_TARGET_DARKENER_PADDING
    end

    if Step == TutorialSteps.CollectCash then
        return Get_World_Darkener_Target(Get_Tutorial_Plot_Squishy(TutorialSteps.FirstRole)), WORLD_DARKENER_PADDING
    end

    if Step == TutorialSteps.FeedStrong then
        if not Owns_Tutorial_Food() then
            return nil, UI_DARKENER_PADDING
        end

        return Get_World_Darkener_Target(Get_Tutorial_Plot_Squishy(TutorialSteps.StrongRole)), FEED_DARKENER_PADDING
    end

    if Step == TutorialSteps.SellOld then
        if Has_Owned_Tutorial_Squishy(TutorialSteps.FirstRole) then
            return nil, UI_DARKENER_PADDING
        end

        if Get_Selected_Inventory_Slot() ~= "Hammer" then
            local HammerButton = Get_Hammer_Button()

            if HammerButton then
                return HammerButton, EQUIP_DARKENER_PADDING
            end
        end

        return Get_World_Darkener_Target(Get_Tutorial_Plot_Squishy(TutorialSteps.FirstRole)), WORLD_DARKENER_PADDING
    end

    return nil, UI_DARKENER_PADDING
end

local function Update_Darkener(Step: number, Active: boolean)
    local Target, Padding = Get_Darkener_Target(Step, Active)

    if not Target then
        if Darkener and DarkenerTarget then
            Darkener:Deactivate()
            DarkenerTarget = nil
        end

        return
    end

    if not Can_Create_Darkener() then
        if Darkener and DarkenerTarget then
            Darkener:Deactivate()
            DarkenerTarget = nil
        end

        return
    end

    if not Darkener then
        Darkener = ScreenDarkener.New(Padding, 0.18)
    end

    if Darkener then
        if DarkenerTarget == Target then
            Darkener:Switch(Target, Padding)
        else
            DarkenerTarget = Target
            Darkener:Activate(Target, Padding)
        end
    end
end

local function Play_Screen_Confetti()
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Main = Get_Main_Gui()
    local Hud = Main and Main:FindFirstChild("Hud Frame")
    local Gui = if Hud and Hud:IsA("GuiObject")
        then Hud
        else PlayerGui and (PlayerGui:FindFirstChild("Visuals") or Main)

    if Gui and (Gui:IsA("ScreenGui") or Gui:IsA("GuiObject")) then
        Confetti({
            GUI = Gui,
            Count = 200,
        } :: any)
    end
end

local function Notify_Tutorial_Complete()
    if CompletionNotificationPlayed then
        return
    end

    CompletionNotificationPlayed = true
    LocalNotifications.Push("Tutorial complete!", "Success", 4)
end

local function Get_Confetti_Template(): Attachment?
    local EffectsFolder = AssetsFolder:FindFirstChild("Effects")
    local VFXFolder = AssetsFolder:FindFirstChild("VFX")
    local Template = (EffectsFolder and EffectsFolder:FindFirstChild("Confetti"))
        or (VFXFolder and VFXFolder:FindFirstChild("Confetti"))

    return if Template and Template:IsA("Attachment") then Template else nil
end

local function Get_Confetti_Sound_Template(): Sound?
    local WorldSounds = SoundService:FindFirstChild("World")
    local AssetSounds = AssetsFolder:FindFirstChild("Sounds")
    local AssetWorldSounds = AssetSounds and AssetSounds:FindFirstChild("World")
    local Template = (WorldSounds and WorldSounds:FindFirstChild("Confetti"))
        or (AssetWorldSounds and AssetWorldSounds:FindFirstChild("Confetti"))

    return if Template and Template:IsA("Sound") then Template else nil
end

local function Play_Character_Confetti(Character: Model?)
    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")

    if not RootPart or not RootPart:IsA("BasePart") then
        return
    end

    local SoundTemplate = Get_Confetti_Sound_Template()

    if SoundTemplate then
        local Sound = SoundTemplate:Clone()

        Sound.Parent = RootPart
        Sound.PlayOnRemove = true
        Sound:Destroy()
    end

    local EffectTemplate = Get_Confetti_Template()

    if not EffectTemplate then
        return
    end

    local Effect = EffectTemplate:Clone()

    Effect.Parent = RootPart

    for _, Inst in Effect:GetDescendants() do
        if Inst:IsA("ParticleEmitter") then
            local EmitCount = Inst:GetAttribute("EmitCount")

            Inst:Emit(if type(EmitCount) == "number" then EmitCount else 1)
        end
    end

    Debris:AddItem(Effect, CONFETTI_EFFECT_LIFETIME)
end

local function Handle_Tutorial_Complete_Effect()
    for _, Data in Network.TutorialCompleteEffect.Iter() do
        local Player = Players:GetPlayerByUserId(Data.PlayerUserId)

        if Player then
            Play_Character_Confetti(Player.Character)
        end

        if Data.PlayerUserId == LocalPlayer.UserId and not CompletionConfettiPlayed then
            Notify_Tutorial_Complete()
            CompletionConfettiPlayed = true
            Play_Screen_Confetti()
        elseif Data.PlayerUserId == LocalPlayer.UserId then
            Notify_Tutorial_Complete()
        end
    end
end

local function Update_Confetti(Step: number)
    if
        LastStep
        and not TutorialSteps.Is_Complete(LastStep)
        and TutorialSteps.Is_Complete(Step)
        and not CompletionConfettiPlayed
    then
        Notify_Tutorial_Complete()
        CompletionConfettiPlayed = true
        Play_Screen_Confetti()
    elseif LastStep and not TutorialSteps.Is_Complete(LastStep) and TutorialSteps.Is_Complete(Step) then
        Notify_Tutorial_Complete()
    end
end

local function Update_Tutorial_Text(Step: number, Active: boolean)
    local TutorialGui = Get_Tutorial_Screen_Gui()

    if TutorialGui then
        Ensure_Tutorial_Gui_Order(TutorialGui)
        TutorialGui.Enabled = Active
    end

    local Label = Get_Tutorial_Label()

    if TutorialFrame then
        TutorialFrame.Visible = Active
    end

    if not Active or not Label then
        return
    end

    Type_Text(Get_Tutorial_Display_Text(Step))
end

local function Step_Tutorial()
    if not peek(FusionValues.TutorialStepReceived) then
        return
    end

    local Step = TutorialSteps.Normalize_Step(peek(FusionValues.TutorialStep))
    local Active = not TutorialSteps.Is_Complete(Step)

    if LastStep ~= Step then
        PlotMoveCompletedStep = nil
    end

    LocalPlayer:SetAttribute(TUTORIAL_ACTIVE_ATTRIBUTE, Active)
    Apply_Hidden_Gui(Active)
    Update_Tutorial_Text(Step, Active)
    Update_Darkener(Step, Active)
    Update_Tutorial_Subevents(Step, Active)

    if
        Active
        and (
            Step == TutorialSteps.PlaceFirst
            or (Step == TutorialSteps.PlaceStrong and Has_Owned_Tutorial_Squishy(TutorialSteps.StrongRole))
        )
    then
        Move_Character_To_Plot(Step)
    else
        Stop_Plot_Move()
    end

    if Active then
        Set_Arrow_Target(Get_World_Target(Step))
    else
        table.clear(StickyRoamingTargets)
        Clear_Arrow()
    end

    Handle_Tutorial_Complete_Effect()
    Update_Confetti(Step)
    LastStep = Step
end

return {
    name = script.Name,
    phase = Phases.Runservice.Last,
    system = function()
        Step_Tutorial()
    end,
    runConditions = {},
}
