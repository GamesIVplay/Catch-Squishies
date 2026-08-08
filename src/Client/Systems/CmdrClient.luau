local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Phases = require(ReplicatedStorage.Shared.Phases)

local Initialized = false

local function Initialize()
    if Initialized then
        return
    end

    Initialized = true

    local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))

    Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
    Cmdr:SetPlaceName("Catch Squishies")
end

return {
    name = script.Name,
    phase = Phases.InitPhases.PostInit,
    system = function()
        task.spawn(Initialize)
    end,
    runConditions = {},
}
