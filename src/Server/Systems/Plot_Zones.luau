local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Components = require(ReplicatedStorage.Shared.Components)
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local Network = require(ServerScriptService.Network)
local Phases = require(ReplicatedStorage.Shared.Phases)
local ProgressionFunnels = require(ServerScriptService.Server.Modules.ProgressionFunnels)
local Registry = require(ReplicatedStorage.Shared.Registry)
local RemoteCooldowns = require(ServerScriptService.Server.Modules.RemoteCooldowns)
local SkipTimeRewards = require(ServerScriptService.Server.Modules.SkipTimeRewards)
local Util = require(ReplicatedStorage.Shared.Modules.Util)
local World = require(ReplicatedStorage.Shared.World)

local Pair = Jecs.pair
local Plots = workspace:WaitForChild("Plots")

local PROMPT_FOLDER_NAME = "ZoneUpgradePrompts"
local PROMPT_ATTACHMENT_NAME = "PromptAttachment"
local PROMPT_PART_SIZE = Vector3.new(4, 5, 4)
local PROMPT_MAX_DISTANCE = 5
local PROMPT_ACTION_TEXT = "Unlock Area"
local SKIP_TIME_PREVIEW_UPDATE_INTERVAL = 1
local AREA_PRICES = table.freeze({
    5_000,
    100_000,
    1_000_000,
    50_000_000,
    200_000_000,
})

local UPGRADES = table.freeze({
    Zone12 = {
        PromptName = "UpgradeZone12",
        BlockingZone = "Zone_12",
        TargetArea = "LeftFront",
    },
    Zone02 = {
        PromptName = "UpgradeZone02",
        BlockingZone = "Zone_02",
        TargetArea = "RightFront",
    },
    Zone04 = {
        PromptName = "UpgradeZone04",
        BlockingZone = "Zone_04",
        TargetArea = "CenterBack",
    },
    Zone20 = {
        PromptName = "UpgradeZone20",
        BlockingZone = "Zone_20",
        TargetArea = "RightBack",
    },
    Zone19 = {
        PromptName = "UpgradeZone19",
        BlockingZone = "Zone_19",
        TargetArea = "RightFront",
    },
    Zone08 = {
        PromptName = "UpgradeZone08",
        BlockingZone = "Zone_08",
        TargetArea = "LeftBack",
    },
    Zone18 = {
        PromptName = "UpgradeZone18",
        BlockingZone = "Zone_18",
        TargetArea = "LeftFront",
    },
    Zone10 = {
        PromptName = "UpgradeZone10",
        BlockingZone = "Zone_10",
        TargetArea = "CenterBack",
    },
    Zone11 = {
        PromptName = "UpgradeZone11",
        BlockingZone = "Zone_11",
        TargetArea = "CenterBack",
    },
    Zone14 = {
        PromptName = "UpgradeZone14",
        BlockingZone = "Zone_14",
        TargetArea = "LeftBack",
    },
    Zone15 = {
        PromptName = "UpgradeZone15",
        BlockingZone = "Zone_15",
        TargetArea = "RightBack",
    },
})

local AREA_KEYS = table.freeze({
    "LeftFront",
    "RightFront",
    "CenterBack",
    "LeftBack",
    "RightBack",
})

local ConfiguredPlots: { [Instance]: boolean } = {}
local LastAreaSignatures: { [Instance]: string } = setmetatable({}, { __mode = "k" })
local LastSkipTimePreviewUpdateAt: { [Instance]: number } = setmetatable({}, { __mode = "k" })
local OriginalPartCFrames: { [BasePart]: CFrame } = setmetatable({}, { __mode = "k" })

local function Get_Zone(Plot: Instance, ZoneName: string): Model?
    local Zones = Plot:FindFirstChild("Zones")

    if not Zones then
        return nil
    end

    local Zone = Zones:FindFirstChild(ZoneName)

    if Zone and Zone:IsA("Model") then
        return Zone
    end

    return nil
end

local function Store_Original_Part_State(Part: BasePart)
    if not OriginalPartCFrames[Part] then
        OriginalPartCFrames[Part] = Part.CFrame
    end

    if Part:GetAttribute("PlotZoneOriginalTransparency") == nil then
        Part:SetAttribute("PlotZoneOriginalTransparency", Part.Transparency)
    end

    if Part:GetAttribute("PlotZoneOriginalCanCollide") == nil then
        Part:SetAttribute("PlotZoneOriginalCanCollide", Part.CanCollide)
    end

    if Part:GetAttribute("PlotZoneOriginalCanTouch") == nil then
        Part:SetAttribute("PlotZoneOriginalCanTouch", Part.CanTouch)
    end

    if Part:GetAttribute("PlotZoneOriginalCanQuery") == nil then
        Part:SetAttribute("PlotZoneOriginalCanQuery", Part.CanQuery)
    end
end

local function Restore_Part_Interaction(Part: BasePart)
    Part.CanCollide = Part:GetAttribute("PlotZoneOriginalCanCollide") :: boolean
    Part.CanTouch = Part:GetAttribute("PlotZoneOriginalCanTouch") :: boolean
    Part.CanQuery = Part:GetAttribute("PlotZoneOriginalCanQuery") :: boolean
end

local function Set_Zone_Visible(Zone: Model?, IsVisible: boolean, Animate: boolean?)
    if not Zone then
        return
    end

    local WasVisible = Zone:GetAttribute("Unlocked") == true

    Zone:SetAttribute("Unlocked", IsVisible)

    for _, Descendant in Zone:GetDescendants() do
        if not Descendant:IsA("BasePart") then
            continue
        end

        Store_Original_Part_State(Descendant)

        if IsVisible then
            local TargetTransparency = Descendant:GetAttribute("PlotZoneOriginalTransparency") :: number
            local TargetCFrame = OriginalPartCFrames[Descendant] or Descendant.CFrame

            Descendant.CFrame = TargetCFrame
            Descendant.Transparency = TargetTransparency
            Restore_Part_Interaction(Descendant)
        else
            Descendant.CFrame = OriginalPartCFrames[Descendant] or Descendant.CFrame
            Descendant.Transparency = 1
            Descendant.CanCollide = false
            Descendant.CanTouch = false
            Descendant.CanQuery = false
        end
    end

    if IsVisible and Animate and not WasVisible then
        Zone:SetAttribute("RevealSerial", (Zone:GetAttribute("RevealSerial") :: number? or 0) + 1)
    end
end

local function Normalize_Plot_Areas(PlotAreas: any): { [string]: boolean }
    local Normalized = {}

    if type(PlotAreas) ~= "table" then
        return Normalized
    end

    for _, AreaName in AREA_KEYS do
        if PlotAreas[AreaName] == true then
            Normalized[AreaName] = true
        end
    end

    return Normalized
end

local function Get_Area_Signature(PlotAreas: { [string]: boolean }): string
    local Parts = {}

    for _, AreaName in AREA_KEYS do
        table.insert(Parts, if PlotAreas[AreaName] == true then "1" else "0")
    end

    return table.concat(Parts, "")
end

local function Count_Unlocked_Areas(PlotAreas: { [string]: boolean }): number
    local Count = 0

    for _, AreaName in AREA_KEYS do
        if PlotAreas[AreaName] == true then
            Count += 1
        end
    end

    return Count
end

local function Get_Next_Area_Price(PlotAreas: { [string]: boolean }): number
    local UnlockedCount = Count_Unlocked_Areas(PlotAreas)

    return AREA_PRICES[math.clamp(UnlockedCount + 1, 1, #AREA_PRICES)]
end

local function Format_Price(Price: number): string
    return `\${Util.Abbreviate_Number(math.max(0, math.floor(Price + 0.5)), 1)}`
end

local function Format_Skip_Time_Value(Value: number): string
    return Format_Price(Value)
end

local function Find_Card_Title_Label(Card: Instance): TextLabel?
    local Title = Card:FindFirstChild("Title", true)

    return if Title and Title:IsA("TextLabel") then Title else nil
end

local function Find_Skip_Time_Title_Label(Plot: Instance, OfferLabel: string): TextLabel?
    local Sign = Plot:FindFirstChild("SkipTimeSign")
    local SurfaceGui = Sign and Sign:FindFirstChildWhichIsA("SurfaceGui", true)

    if not SurfaceGui then
        return nil
    end

    for _, Card in SurfaceGui:GetChildren() do
        local Title = Find_Card_Title_Label(Card)

        if Title and string.find(Title.Text, OfferLabel, 1, true) then
            return Title
        end
    end

    return nil
end

local function Update_Skip_Time_Display(Plot: Instance, OwnerEntity: number?)
    local Now = os.clock()

    if
        type(LastSkipTimePreviewUpdateAt[Plot]) == "number"
        and Now - LastSkipTimePreviewUpdateAt[Plot] < SKIP_TIME_PREVIEW_UPDATE_INTERVAL
    then
        return
    end

    LastSkipTimePreviewUpdateAt[Plot] = Now

    for _, Offer in
        {
            { Label = "Skip 5m", Seconds = 60 * 5 },
            { Label = "Skip 10m", Seconds = 60 * 10 },
        }
    do
        local Label = Find_Skip_Time_Title_Label(Plot, Offer.Label)

        if not Label then
            continue
        end

        local Value = if OwnerEntity
            then SkipTimeRewards.Calculate_Player_Production_Value(OwnerEntity, Offer.Seconds)
            else 0
        local Text = `{Offer.Label} ({Format_Skip_Time_Value(Value)})`

        if Label.Text ~= Text then
            Label.Text = Text
        end
    end
end

local function Get_Player_Entity(Player: Player): number?
    if not Player or not Player:IsDescendantOf(Players) then
        return nil
    end

    local Entity = Registry.Get("Players", Player)

    if not Entity or not World:contains(Entity) then
        return nil
    end

    return Entity
end

local function Get_Plot_Model(PlotEntity: number?): Model?
    if not PlotEntity or not World:contains(PlotEntity) then
        return nil
    end

    local Plot = World:get(PlotEntity, Components.Renderable)

    if Plot and Plot:IsA("Model") then
        return Plot
    end

    return nil
end

local function Find_Owned_Plot_Entity(PlayerEntity: number): number?
    for PlotNumber = 1, 6 do
        local PlotEntity = Registry.Get("Plots", PlotNumber)

        if
            PlotEntity
            and World:contains(PlotEntity)
            and World:target(PlotEntity, Components.Relationships.Owner) == PlayerEntity
            and Get_Plot_Model(PlotEntity)
        then
            return PlotEntity
        end
    end

    return nil
end

local function Get_Player_Plot(PlayerEntity: number): Model?
    local PlotEntity = World:target(PlayerEntity, Components.Relationships.Plot)
    local Plot = Get_Plot_Model(PlotEntity)

    if Plot then
        return Plot
    end

    local OwnedPlotEntity = Find_Owned_Plot_Entity(PlayerEntity)

    if OwnedPlotEntity then
        if PlotEntity and PlotEntity ~= OwnedPlotEntity and World:contains(PlotEntity) then
            World:remove(PlayerEntity, Pair(Components.Relationships.Plot, PlotEntity))
        end

        World:add(PlayerEntity, Pair(Components.Relationships.Plot, OwnedPlotEntity))
        return Get_Plot_Model(OwnedPlotEntity)
    end

    return nil
end

local function Get_Plot_Owner_Entity(Plot: Instance): number?
    local PlotNumber = tonumber(Plot.Name)

    if not PlotNumber then
        return nil
    end

    local PlotEntity = Registry.Get("Plots", PlotNumber)

    if not PlotEntity or not World:contains(PlotEntity) then
        return nil
    end

    local OwnerEntity = World:target(PlotEntity, Components.Relationships.Owner)

    if not OwnerEntity or not World:contains(OwnerEntity) then
        return nil
    end

    return OwnerEntity
end

local function Get_Player_Areas(PlayerEntity: number?): { [string]: boolean }
    if not PlayerEntity or not World:contains(PlayerEntity) then
        return {}
    end

    return Normalize_Plot_Areas(World:get(PlayerEntity, Components.PlotAreas))
end

local function Set_Player_Areas(PlayerEntity: number, PlotAreas: { [string]: boolean }): { [string]: boolean }
    local Normalized = Normalize_Plot_Areas(PlotAreas)

    World:set(PlayerEntity, Components.PlotAreas, Normalized)

    return Normalized
end

local function Get_Area_States(Plot: Instance): { [string]: boolean }
    local PlotAreas = Get_Player_Areas(Get_Plot_Owner_Entity(Plot))

    return {
        Start = true,
        LeftFront = PlotAreas.LeftFront == true,
        RightFront = PlotAreas.RightFront == true,
        CenterBack = PlotAreas.CenterBack == true,
        LeftBack = PlotAreas.LeftBack == true,
        RightBack = PlotAreas.RightBack == true,
    }
end

local function Sync_Plot_Area_Attributes(Plot: Instance, PlotAreas: { [string]: boolean })
    for _, AreaName in AREA_KEYS do
        Plot:SetAttribute(`{AreaName}Unlocked`, PlotAreas[AreaName] == true)
    end

    for UpgradeName, UpgradeConfig in UPGRADES do
        Plot:SetAttribute(`{UpgradeName}ZoneUnlocked`, PlotAreas[UpgradeConfig.TargetArea] == true)
    end
end

local function Build_Visible_Zone_Set(Plot: Instance): { [string]: boolean }
    local Areas = Get_Area_States(Plot)
    local VisibleZones = {}

    VisibleZones.Zone_01 = true

    if Areas.LeftFront then
        VisibleZones.Zone_05 = true
        VisibleZones.Zone_06 = true

        if not Areas.LeftBack then
            VisibleZones.Zone_08 = true
        end
    else
        VisibleZones.Zone_12 = true
    end

    if Areas.RightFront then
        VisibleZones.Zone_17 = true
        VisibleZones.Zone_13 = true

        if not Areas.RightBack then
            VisibleZones.Zone_20 = true
        end
    else
        VisibleZones.Zone_02 = true
    end

    if Areas.CenterBack then
        VisibleZones.Zone_22 = true

        if not Areas.LeftBack then
            VisibleZones.Zone_14 = true
        end

        if not Areas.RightBack then
            VisibleZones.Zone_15 = true
        end
    else
        VisibleZones.Zone_04 = true
    end

    if Areas.LeftBack then
        VisibleZones.Zone_09 = true
        VisibleZones.Zone_21 = true

        if not Areas.LeftFront then
            VisibleZones.Zone_18 = true
        end

        if not Areas.CenterBack then
            VisibleZones.Zone_10 = true
        end
    end

    if Areas.RightBack then
        VisibleZones.Zone_16 = true
        VisibleZones.Zone_23 = true

        if not Areas.RightFront then
            VisibleZones.Zone_19 = true
        end

        if not Areas.CenterBack then
            VisibleZones.Zone_11 = true
        end
    end

    return VisibleZones
end

local function Is_Upgrade_Target_Unlocked(Plot: Instance, UpgradeConfig): boolean
    local TargetArea = UpgradeConfig.TargetArea

    if TargetArea then
        return Get_Area_States(Plot)[TargetArea] == true
    end

    return false
end

local function Is_Upgrade_Blocking_Zone_Visible(Plot: Instance, UpgradeConfig): boolean
    return Build_Visible_Zone_Set(Plot)[UpgradeConfig.BlockingZone] == true
end

local function Apply_Zone_Visibility(Plot: Instance, Animate: boolean?)
    local Zones = Plot:FindFirstChild("Zones")

    if not Zones then
        return
    end

    local VisibleZones = Build_Visible_Zone_Set(Plot)

    for _, Zone in Zones:GetChildren() do
        if not Zone:IsA("Model") then
            continue
        end

        Set_Zone_Visible(Zone, VisibleZones[Zone.Name] == true, Animate)
    end
end

local function Apply_Plot_Areas(Plot: Instance, PlotAreas: { [string]: boolean }, Animate: boolean?)
    local Normalized = Normalize_Plot_Areas(PlotAreas)

    Sync_Plot_Area_Attributes(Plot, Normalized)
    LastAreaSignatures[Plot] = Get_Area_Signature(Normalized)
    Apply_Zone_Visibility(Plot, Animate)
end

local function Get_Plot_Owner(Plot: Instance): Player?
    local OwnerEntity = Get_Plot_Owner_Entity(Plot)

    if not OwnerEntity or not World:contains(OwnerEntity) then
        return nil
    end

    return World:get(OwnerEntity, Components.Player)
end

local function Can_Use_Prompt(Player: Player, Plot: Instance): boolean
    local Owner = Get_Plot_Owner(Plot)

    return Owner == Player
end

local function Sync_Plot_Owner_Attribute(Plot: Instance, OwnerEntity: number?)
    local Owner = if OwnerEntity and World:contains(OwnerEntity) then World:get(OwnerEntity, Components.Player) else nil

    if Owner then
        Plot:SetAttribute("OwnerUserId", Owner.UserId)
    else
        Plot:SetAttribute("OwnerUserId", nil)
    end
end

local function Try_Unlock_Area(Player: Player, Plot: Instance, UpgradeConfig)
    local TargetArea = UpgradeConfig.TargetArea

    if Is_Upgrade_Target_Unlocked(Plot, UpgradeConfig) then
        return
    end

    if not Can_Use_Prompt(Player, Plot) then
        return
    end

    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity or not TargetArea then
        return
    end

    local PlotAreas = Get_Player_Areas(PlayerEntity)
    local Price = Get_Next_Area_Price(PlotAreas)
    local Cash = World:get(PlayerEntity, Components.Cash) or 0

    if Cash < Price then
        SkipTimeRewards.PromptShortfall(Player, PlayerEntity, Cash, Price)
        Network.Notification.Fire(Player, {
            Text = `Not enough cash. Need {Format_Price(Price)}.`,
            Duration = 3,
            Type = "Error",
        })
        return
    end

    PlotAreas[TargetArea] = true
    PlotAreas = Set_Player_Areas(PlayerEntity, PlotAreas)
    ProgressionFunnels.Log_Plot_Areas(PlayerEntity, PlotAreas)
    World:set(PlayerEntity, Components.Cash, Cash - Price)

    Network.Notification.Fire(Player, {
        Text = "Area unlocked!",
        Duration = 3,
        Type = "Success",
    })
    Network.BuyEffect.FireAll({
        PlayerUserId = Player.UserId,
    })
    Apply_Plot_Areas(Plot, PlotAreas, true)
end

local function Get_Or_Create_Prompt_Folder(Plot: Instance): Folder
    local Folder = Plot:FindFirstChild(PROMPT_FOLDER_NAME)

    if Folder and Folder:IsA("Folder") then
        return Folder
    end

    Folder = Instance.new("Folder")
    Folder.Name = PROMPT_FOLDER_NAME
    Folder.Parent = Plot

    return Folder
end

local function Get_Prompt_CFrame(Plot: Instance, ZoneName: string): CFrame
    local Zone = Get_Zone(Plot, ZoneName)

    if Zone then
        local Pivot = Zone:GetPivot()

        return CFrame.new(Pivot.Position + Vector3.new(0, 3, 0))
    end

    local Spawn = Plot:FindFirstChild("Spawn")

    if Spawn and Spawn:IsA("BasePart") then
        return Spawn.CFrame
    end

    return CFrame.new()
end

local function Get_Or_Create_Prompt_Attachment(PromptPart: BasePart): Attachment
    local Attachment = PromptPart:FindFirstChild(PROMPT_ATTACHMENT_NAME)

    if Attachment and Attachment:IsA("Attachment") then
        return Attachment
    end

    if Attachment then
        Attachment:Destroy()
    end

    Attachment = Instance.new("Attachment")
    Attachment.Name = PROMPT_ATTACHMENT_NAME
    Attachment.Parent = PromptPart

    return Attachment
end

local function Remove_Server_Prompts(PromptPart: BasePart)
    for _, Descendant in PromptPart:GetDescendants() do
        if Descendant:IsA("ProximityPrompt") then
            Descendant:Destroy()
        end
    end
end

local function Remove_All_Server_Upgrade_Prompts(Plot: Instance)
    local PromptFolder = Plot:FindFirstChild(PROMPT_FOLDER_NAME)

    if not PromptFolder then
        return
    end

    for _, Descendant in PromptFolder:GetDescendants() do
        if Descendant:IsA("ProximityPrompt") then
            Descendant:Destroy()
        end
    end
end

local function Configure_Prompt(Plot: Instance, UpgradeName: string, UpgradeConfig)
    local PromptFolder = Get_Or_Create_Prompt_Folder(Plot)
    local PromptPart = PromptFolder:FindFirstChild(UpgradeConfig.PromptName)

    if not PromptPart or not PromptPart:IsA("BasePart") then
        if PromptPart then
            PromptPart:Destroy()
        end

        PromptPart = Instance.new("Part")
        PromptPart.Name = UpgradeConfig.PromptName
        PromptPart.Parent = PromptFolder
    end

    PromptPart.Anchored = true
    PromptPart.CanCollide = false
    PromptPart.CanTouch = false
    PromptPart.CanQuery = false
    PromptPart.Transparency = 1
    PromptPart.Size = PROMPT_PART_SIZE
    PromptPart.CFrame = Get_Prompt_CFrame(Plot, UpgradeConfig.BlockingZone)
    local Attachment = Get_Or_Create_Prompt_Attachment(PromptPart)

    Attachment:SetAttribute("UpgradeName", UpgradeName)
    Attachment:SetAttribute("ClientEnabled", false)
    Attachment:SetAttribute("ActionText", PROMPT_ACTION_TEXT)
    Attachment:SetAttribute("ObjectText", "")
    Attachment:SetAttribute("HoldDuration", 0.15)
    Attachment:SetAttribute("MaxActivationDistance", PROMPT_MAX_DISTANCE)
    Attachment:SetAttribute("RequiresLineOfSight", false)

    Remove_Server_Prompts(PromptPart)
end

local function Set_Upgrade_Prompt_Enabled(Plot: Instance, UpgradeName: string, UpgradeConfig)
    local PromptFolder = Plot:FindFirstChild(PROMPT_FOLDER_NAME)
    local PromptPart = PromptFolder and PromptFolder:FindFirstChild(UpgradeConfig.PromptName)
    local Attachment = PromptPart and PromptPart:FindFirstChild(PROMPT_ATTACHMENT_NAME)

    if PromptPart and PromptPart:IsA("BasePart") then
        Remove_Server_Prompts(PromptPart)
    end

    if Attachment and Attachment:IsA("Attachment") then
        local OwnerEntity = Get_Plot_Owner_Entity(Plot)
        local PlotAreas = Get_Player_Areas(OwnerEntity)
        local ClientEnabled = OwnerEntity ~= nil
            and not Is_Upgrade_Target_Unlocked(Plot, UpgradeConfig)
            and Is_Upgrade_Blocking_Zone_Visible(Plot, UpgradeConfig)

        Attachment:SetAttribute("UpgradeName", UpgradeName)
        Attachment:SetAttribute("ClientEnabled", ClientEnabled)
        Attachment:SetAttribute("ActionText", PROMPT_ACTION_TEXT)
        Attachment:SetAttribute("ObjectText", Format_Price(Get_Next_Area_Price(PlotAreas)))
        Attachment:SetAttribute("HoldDuration", 0.15)
        Attachment:SetAttribute("MaxActivationDistance", PROMPT_MAX_DISTANCE)
        Attachment:SetAttribute("RequiresLineOfSight", false)
    end
end

local function Set_Upgrade_Prompts_Enabled(Plot: Instance)
    for UpgradeName, UpgradeConfig in UPGRADES do
        Set_Upgrade_Prompt_Enabled(Plot, UpgradeName, UpgradeConfig)
    end
end

local function Cleanup_Stale_Prompts(Plot: Instance)
    local PromptFolder = Plot:FindFirstChild(PROMPT_FOLDER_NAME)

    if not PromptFolder then
        return
    end

    local ValidPromptNames = {}

    for _, UpgradeConfig in UPGRADES do
        ValidPromptNames[UpgradeConfig.PromptName] = true
    end

    for _, Child in PromptFolder:GetChildren() do
        if ValidPromptNames[Child.Name] then
            continue
        end

        Child:Destroy()
    end
end

local function Reset_Plot_Upgrades(Plot: Instance)
    Apply_Plot_Areas(Plot, {}, false)
end

local function Configure_Plot(Plot: Instance)
    if ConfiguredPlots[Plot] then
        return
    end

    local Zones = Plot:FindFirstChild("Zones")

    if not Zones then
        return
    end

    ConfiguredPlots[Plot] = true

    Apply_Plot_Areas(Plot, Get_Player_Areas(Get_Plot_Owner_Entity(Plot)), false)

    for UpgradeName, UpgradeConfig in UPGRADES do
        Configure_Prompt(Plot, UpgradeName, UpgradeConfig)
    end

    Cleanup_Stale_Prompts(Plot)
end

local function Step_Plot(Plot: Instance)
    Configure_Plot(Plot)

    if not ConfiguredPlots[Plot] then
        return
    end

    local OwnerEntity = Get_Plot_Owner_Entity(Plot)
    Sync_Plot_Owner_Attribute(Plot, OwnerEntity)

    if OwnerEntity == nil then
        if LastAreaSignatures[Plot] ~= Get_Area_Signature({}) then
            Reset_Plot_Upgrades(Plot)
        end
    else
        local PlotAreas = Get_Player_Areas(OwnerEntity)
        local AreaSignature = Get_Area_Signature(PlotAreas)

        if LastAreaSignatures[Plot] ~= AreaSignature then
            Apply_Plot_Areas(Plot, PlotAreas, false)
        end
    end

    Remove_All_Server_Upgrade_Prompts(Plot)
    Set_Upgrade_Prompts_Enabled(Plot)
    Update_Skip_Time_Display(Plot, OwnerEntity)
end

local function Configure_Plots()
    for _, Plot in Plots:GetChildren() do
        Step_Plot(Plot)
    end
end

local function Process_Plot_Unlock_Requests()
    for _, Player, UpgradeName in Network.RequestPlotAreaUnlock.Iter() do
        if not RemoteCooldowns.Allow(Player, "RequestPlotAreaUnlock") then
            continue
        end

        if type(UpgradeName) ~= "string" then
            continue
        end

        local UpgradeConfig = UPGRADES[UpgradeName]

        if not UpgradeConfig then
            continue
        end

        local PlayerEntity = Get_Player_Entity(Player)

        if not PlayerEntity then
            continue
        end

        local Plot = Get_Player_Plot(PlayerEntity)

        if not Plot then
            continue
        end

        Try_Unlock_Area(Player, Plot, UpgradeConfig)
    end
end

local function Apply_Player_Plot_Areas(PlayerEntity: number, Animate: boolean?)
    local Plot = Get_Player_Plot(PlayerEntity)

    if not Plot then
        return
    end

    Apply_Plot_Areas(Plot, Get_Player_Areas(PlayerEntity), Animate)
    Set_Upgrade_Prompts_Enabled(Plot)
end

local function Reset_Player_Areas(Player: Player): string
    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return `{Player.Name} does not have loaded player data yet.`
    end

    Set_Player_Areas(PlayerEntity, {})
    Apply_Player_Plot_Areas(PlayerEntity, false)

    return `Reset {Player.Name}'s plot areas.`
end

local function Unlock_Player_Areas(Player: Player): string
    local PlayerEntity = Get_Player_Entity(Player)

    if not PlayerEntity then
        return `{Player.Name} does not have loaded player data yet.`
    end

    local PlotAreas = {}

    for _, AreaName in AREA_KEYS do
        PlotAreas[AreaName] = true
    end

    Set_Player_Areas(PlayerEntity, PlotAreas)
    ProgressionFunnels.Log_Plot_Areas(PlayerEntity, PlotAreas)
    Apply_Player_Plot_Areas(PlayerEntity, true)

    return `Unlocked all plot areas for {Player.Name}.`
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        Configure_Plots()
        Process_Plot_Unlock_Requests()
    end,
    Reset_Player_Areas = Reset_Player_Areas,
    Unlock_Player_Areas = Unlock_Player_Areas,
}
