local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Planck = require(ReplicatedStorage.Packages.Planck)
local PlanckRunService = require(ReplicatedStorage.Packages.PlanckRunService)

local Phases = {
    Runservice = PlanckRunService.Phases,
    InitPhases = {
        PreInit = Planck.Phase.new("PreInit"),
        Init = Planck.Phase.new("Init"),
        PostInit = Planck.Phase.new("PostInit"),
    },
}

return table.freeze(Phases)
