local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CmdrUtil = require(ServerScriptService.Server.Cmdr.Util)
local Phases = require(ReplicatedStorage.Shared.Phases)

local DidSubscribe = false

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = function()
        if DidSubscribe then
            return
        end

        DidSubscribe = true
        CmdrUtil.Subscribe_Global_Squishy_Grants()
    end,
    runConditions = {},
}
