local ServerScriptService = game:GetService("ServerScriptService")

local EventService = require(ServerScriptService.Server.Modules.EventService)

return function(_, EventName: string, Duration: number?): string
    local _, Message = EventService.StartEvent(EventName, Duration, "Local")

    return Message
end
