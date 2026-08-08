local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Network = require(ServerScriptService.Network)

local Components = require(ReplicatedStorage.Shared.Components)
local Events = require(ReplicatedStorage.Shared.Modules.Events)
local World = require(ReplicatedStorage.Shared.World)

local EventService = {}

local START_GLOBAL_EVENT_TOPIC = "CatchSquishies_StartGlobalEvent"
local STOP_GLOBAL_EVENT_TOPIC = "CatchSquishies_StopGlobalEvent"
local DEFAULT_SOURCE = "Local"
local NATURAL_SOURCE = "Natural"
local GLOBAL_SOURCE = "Global"

local DidSubscribe = false
local ProcessedMessageIds: { [string]: number } = {}
local NaturalRng = Random.new()

local function Get_Now(): number
    return workspace:GetServerTimeNow()
end

local function Copy_Active_Events(ActiveEvents: any): { [string]: any }
    local Result = {}

    if type(ActiveEvents) ~= "table" then
        return Result
    end

    for Key, Entry in ActiveEvents do
        if type(Entry) ~= "table" then
            continue
        end

        local EventName = Events.Normalize(Entry.Name or Key)

        if not EventName then
            continue
        end

        Result[EventName] = {
            Name = EventName,
            StartedAt = if type(Entry.StartedAt) == "number" then Entry.StartedAt else 0,
            EndsAt = if type(Entry.EndsAt) == "number" then Entry.EndsAt else 0,
            Source = if type(Entry.Source) == "string" and Entry.Source ~= "" then Entry.Source else DEFAULT_SOURCE,
        }
    end

    return Result
end

local function Get_State(): any
    local State = World:get(Components.Singletons.EventState, Components.Singletons.EventState)

    if type(State) ~= "table" then
        State = {
            NextEventAt = Events.GetNextEventAt(Get_Now()),
            ActiveEvents = {},
        }
        World:set(Components.Singletons.EventState, Components.Singletons.EventState, State)
    end

    if type(State.NextEventAt) ~= "number" or State.NextEventAt <= 0 then
        State.NextEventAt = Events.GetNextEventAt(Get_Now())
    end

    if type(State.ActiveEvents) ~= "table" then
        State.ActiveEvents = {}
    end

    return State
end

local function Set_State(State: any)
    World:set(Components.Singletons.EventState, Components.Singletons.EventState, {
        NextEventAt = if type(State.NextEventAt) == "number"
            then State.NextEventAt
            else Events.GetNextEventAt(Get_Now()),
        ActiveEvents = Copy_Active_Events(State.ActiveEvents),
    })
end

local function Notify_All(Text: string, NotificationType: string?)
    Network.Notification.FireAll({
        Text = Text,
        Type = NotificationType or "Info",
        Duration = 5,
    })
end

local function Cleanup_Processed_Message_Ids()
    local Now = os.clock()

    for MessageId, SeenAt in ProcessedMessageIds do
        if Now - SeenAt > 120 then
            ProcessedMessageIds[MessageId] = nil
        end
    end
end

local function Was_Message_Processed(MessageId: any): boolean
    if type(MessageId) ~= "string" or MessageId == "" then
        return false
    end

    if ProcessedMessageIds[MessageId] then
        return true
    end

    ProcessedMessageIds[MessageId] = os.clock()
    Cleanup_Processed_Message_Ids()

    return false
end

function EventService.GetState(): any
    local State = Get_State()

    return {
        NextEventAt = State.NextEventAt,
        ActiveEvents = Copy_Active_Events(State.ActiveEvents),
    }
end

function EventService.GetActiveEvents(): { [string]: any }
    EventService.CleanupExpired()

    return Copy_Active_Events(Get_State().ActiveEvents)
end

function EventService.StartEvent(
    EventName: any,
    Duration: number?,
    Source: string?,
    ExecutorName: string?
): (boolean, string)
    local NormalizedEventName = Events.Normalize(EventName)

    if not NormalizedEventName then
        return false, `Unknown event "{tostring(EventName)}".`
    end

    local Now = Get_Now()
    local SafeDuration = math.max(
        1,
        math.floor(if type(Duration) == "number" and Duration == Duration then Duration else Events.DurationSeconds)
    )
    local State = Get_State()
    local ActiveEvents = Copy_Active_Events(State.ActiveEvents)
    local EventSource = if type(Source) == "string" and Source ~= "" then Source else DEFAULT_SOURCE

    if EventSource == NATURAL_SOURCE then
        for ActiveName, ActiveEvent in ActiveEvents do
            if ActiveEvent.Source == NATURAL_SOURCE then
                ActiveEvents[ActiveName] = nil
            end
        end
    end

    ActiveEvents[NormalizedEventName] = {
        Name = NormalizedEventName,
        StartedAt = Now,
        EndsAt = Now + SafeDuration,
        Source = EventSource,
    }

    Set_State({
        NextEventAt = State.NextEventAt,
        ActiveEvents = ActiveEvents,
    })

    local DisplayName = Events.GetDisplayName(NormalizedEventName)
    local NotificationText = if EventSource == GLOBAL_SOURCE
            and type(ExecutorName) == "string"
            and ExecutorName ~= ""
        then `{ExecutorName} started a global {DisplayName} Event!`
        else `A {DisplayName} Event started!`
    Notify_All(NotificationText, "Announcement")

    return true, `{DisplayName} event started for {SafeDuration}s.`
end

function EventService.StopEvent(EventName: any?): (boolean, string)
    local State = Get_State()
    local ActiveEvents = Copy_Active_Events(State.ActiveEvents)
    local Removed = 0

    if EventName == nil or EventName == "" then
        for ActiveName in ActiveEvents do
            ActiveEvents[ActiveName] = nil
            Removed += 1
        end
    else
        local NormalizedEventName = Events.Normalize(EventName)

        if not NormalizedEventName then
            return false, `Unknown event "{tostring(EventName)}".`
        end

        if ActiveEvents[NormalizedEventName] then
            ActiveEvents[NormalizedEventName] = nil
            Removed = 1
        end
    end

    if Removed > 0 then
        Set_State({
            NextEventAt = State.NextEventAt,
            ActiveEvents = ActiveEvents,
        })
    end

    return true, if Removed > 0 then `Stopped {Removed} active event(s).` else "No active events matched."
end

function EventService.CleanupExpired(): boolean
    local State = Get_State()
    local ActiveEvents = Copy_Active_Events(State.ActiveEvents)
    local Now = Get_Now()
    local Changed = false

    for EventName, ActiveEvent in ActiveEvents do
        if type(ActiveEvent.EndsAt) ~= "number" or ActiveEvent.EndsAt <= Now then
            ActiveEvents[EventName] = nil
            Changed = true
        end
    end

    if Changed then
        Set_State({
            NextEventAt = State.NextEventAt,
            ActiveEvents = ActiveEvents,
        })
    end

    return Changed
end

function EventService.StartNaturalIfDue(): boolean
    local State = Get_State()
    local Now = Get_Now()
    local NextEventAt = State.NextEventAt

    if type(NextEventAt) ~= "number" or NextEventAt <= 0 then
        NextEventAt = Events.GetNextEventAt(Now)
    end

    if Now < NextEventAt then
        return false
    end

    repeat
        NextEventAt += Events.IntervalSeconds
    until NextEventAt > Now

    Set_State({
        NextEventAt = NextEventAt,
        ActiveEvents = State.ActiveEvents,
    })

    EventService.StartEvent(Events.RollNatural(NaturalRng), Events.DurationSeconds, NATURAL_SOURCE)

    return true
end

local function Handle_Global_Start(Data: any)
    if type(Data) ~= "table" or Was_Message_Processed(Data.MessageId) then
        return
    end

    EventService.StartEvent(Data.EventName, Data.Duration, GLOBAL_SOURCE, Data.Executor)
end

local function Handle_Global_Stop(Data: any)
    if type(Data) ~= "table" or Was_Message_Processed(Data.MessageId) then
        return
    end

    EventService.StopEvent(Data.EventName)
end

function EventService.Subscribe()
    if DidSubscribe then
        return
    end

    DidSubscribe = true

    task.spawn(function()
        pcall(function()
            MessagingService:SubscribeAsync(START_GLOBAL_EVENT_TOPIC, function(Message)
                Handle_Global_Start(Message.Data)
            end)
        end)
    end)

    task.spawn(function()
        pcall(function()
            MessagingService:SubscribeAsync(STOP_GLOBAL_EVENT_TOPIC, function(Message)
                Handle_Global_Stop(Message.Data)
            end)
        end)
    end)
end

function EventService.PublishStartGlobal(EventName: any, Duration: number?, ExecutorName: string?): (boolean, string)
    local NormalizedEventName = Events.Normalize(EventName)

    if not NormalizedEventName then
        return false, `Unknown event "{tostring(EventName)}".`
    end

    local Payload = {
        MessageId = HttpService:GenerateGUID(false),
        EventName = NormalizedEventName,
        Duration = Duration or Events.DurationSeconds,
        Executor = ExecutorName or "",
    }

    local Success, Error = pcall(function()
        MessagingService:PublishAsync(START_GLOBAL_EVENT_TOPIC, Payload)
    end)

    if not Success then
        return false, `Failed to publish global event: {Error}`
    end

    Handle_Global_Start(Payload)

    return true, `Published global {Events.GetDisplayName(NormalizedEventName)} event.`
end

function EventService.PublishStopGlobal(EventName: any?): (boolean, string)
    local NormalizedEventName = if EventName == nil or EventName == "" then nil else Events.Normalize(EventName)

    if EventName ~= nil and EventName ~= "" and not NormalizedEventName then
        return false, `Unknown event "{tostring(EventName)}".`
    end

    local Payload = {
        MessageId = HttpService:GenerateGUID(false),
        EventName = NormalizedEventName or "",
    }

    local Success, Error = pcall(function()
        MessagingService:PublishAsync(STOP_GLOBAL_EVENT_TOPIC, Payload)
    end)

    if not Success then
        return false, `Failed to publish global event stop: {Error}`
    end

    Handle_Global_Stop(Payload)

    return true, "Published global event stop."
end

function EventService.Step()
    EventService.Subscribe()
    EventService.CleanupExpired()
    EventService.StartNaturalIfDue()
end

return table.freeze(EventService)
