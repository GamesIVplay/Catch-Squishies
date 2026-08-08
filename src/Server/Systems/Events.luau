local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventService = require(script.Parent.Parent.Modules.EventService)
local Events = require(ReplicatedStorage.Shared.Modules.Events)
local Phases = require(ReplicatedStorage.Shared.Phases)

local WORKSPACE_EVENTS_FOLDER_NAME = "Events"

local AppliedSignature = ""

local function Get_Workspace_Events_Folder(): Folder
    local Folder = workspace:FindFirstChild(WORKSPACE_EVENTS_FOLDER_NAME)

    if Folder and Folder:IsA("Folder") then
        return Folder
    end

    Folder = Instance.new("Folder")
    Folder.Name = WORKSPACE_EVENTS_FOLDER_NAME
    Folder.Parent = workspace

    return Folder
end

local function Get_Event_Template(EventName: string): Instance?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local EventsFolder = Assets and Assets:FindFirstChild("Events")

    return EventsFolder and EventsFolder:FindFirstChild(EventName)
end

local function Get_Active_Signature(ActiveEvents: { [string]: any }): string
    local Names = {}

    for EventName in ActiveEvents do
        table.insert(Names, EventName)
    end

    table.sort(Names)

    return table.concat(Names, ",")
end

local function Sync_Workspace_Event_Visuals()
    local ActiveEvents = EventService.GetActiveEvents()
    local Signature = Get_Active_Signature(ActiveEvents)

    if Signature == AppliedSignature then
        return
    end

    AppliedSignature = Signature

    local Folder = Get_Workspace_Events_Folder()

    for _, Child in Folder:GetChildren() do
        if not ActiveEvents[Child.Name] then
            Child:Destroy()
        end
    end

    for EventName in ActiveEvents do
        if Folder:FindFirstChild(EventName) or not Events.IsEvent(EventName) then
            continue
        end

        local Template = Get_Event_Template(EventName)

        if not Template then
            continue
        end

        local Clone = Template:Clone()
        Clone.Name = EventName
        Clone.Parent = Folder
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = function()
        EventService.Step()
        Sync_Workspace_Event_Visuals()
    end,
    runConditions = {},
}
