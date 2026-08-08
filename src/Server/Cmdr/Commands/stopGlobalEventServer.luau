local ServerScriptService = game:GetService("ServerScriptService")

local EventService = require(ServerScriptService.Server.Modules.EventService)

return function(_, EventName: string?): string
    local _, Message = EventService.PublishStopGlobal(EventName)

    return Message
end
