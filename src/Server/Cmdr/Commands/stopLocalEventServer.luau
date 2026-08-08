local ServerScriptService = game:GetService("ServerScriptService")

local EventService = require(ServerScriptService.Server.Modules.EventService)

return function(_, EventName: string?): string
    local _, Message = EventService.StopEvent(EventName)

    return Message
end
