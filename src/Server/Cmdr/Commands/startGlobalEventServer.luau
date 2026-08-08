local ServerScriptService = game:GetService("ServerScriptService")

local EventService = require(ServerScriptService.Server.Modules.EventService)

return function(Context, EventName: string, Duration: number?): string
    local Executor = Context.Executor
    local ExecutorName = if typeof(Executor) == "Instance" and Executor:IsA("Player") then Executor.Name else ""
    local _, Message = EventService.PublishStartGlobal(EventName, Duration, ExecutorName)

    return Message
end
