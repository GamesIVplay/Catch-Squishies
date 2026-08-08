local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(ReplicatedStorage.Shared.Components)
local Phases = require(ReplicatedStorage.Shared.Phases)
local World = require(ReplicatedStorage.Shared.World)

local Leaderstats_Query = World:query(Components.Player, Components.Cash):cached()

local LEADERSTATS_NAME = "leaderstats"
local CASH_NAME = "💵 Cash"

local function Get_Or_Create_Leaderstats(Player: Player): Folder
    local Leaderstats = Player:FindFirstChild(LEADERSTATS_NAME)

    if not Leaderstats or not Leaderstats:IsA("Folder") then
        Leaderstats = Instance.new("Folder")
        Leaderstats.Name = LEADERSTATS_NAME
        Leaderstats.Parent = Player
    end

    return Leaderstats
end

local function Get_Or_Create_Cash(Leaderstats: Folder): IntValue
    local Cash = Leaderstats:FindFirstChild(CASH_NAME)

    if not Cash or not Cash:IsA("IntValue") then
        if Cash then
            Cash:Destroy()
        end

        Cash = Instance.new("IntValue")
        Cash.Name = CASH_NAME
        Cash.Parent = Leaderstats
    end

    return Cash
end

return {
    name = script.Name,
    phase = Phases.Runservice.PostUpdate,
    system = function()
        for _, Player: Player, Cash: number in Leaderstats_Query:iter() do
            local Leaderstats = Get_Or_Create_Leaderstats(Player)
            local CashInstance = Get_Or_Create_Cash(Leaderstats)
            local RoundedCash = math.floor(Cash)

            if CashInstance.Value ~= RoundedCash then
                CashInstance.Value = RoundedCash
            end
        end
    end,
    runConditions = {},
}
