local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Plots = workspace:WaitForChild("Plots")

local Jecs = require(ReplicatedStorage.Packages.Jecs)
local Pair = Jecs.pair

local Components = require(ReplicatedStorage.Shared.Components)
local Phases = require(ReplicatedStorage.Shared.Phases)
local Registry = require(ReplicatedStorage.Shared.Registry)
local World = require(ReplicatedStorage.Shared.World)

local Util = require(ReplicatedStorage.Shared.Modules.Util)

local function Create_Plot_Entities()
    for _, Model: Model in Plots:GetChildren() do
        local Plot_Number = tonumber(Model.Name)

        local Entity = World:entity()
        Registry.Define("Plots", Plot_Number, Entity)

        World:set(Entity, Components.Renderable, Model)

        World:add(Entity, Components.Tags.Plot)
        World:add(Entity, Components.Tags.Networked)
    end
end

Create_Plot_Entities()

local Plots_Without_Owner = World:query(Components.Renderable)
    :with(Components.Tags.Plot)
    :without(Pair(Components.Relationships.Owner, Jecs.Wildcard))
    :cached()

local function Cleanup_Plots()
    for _Plot_Entity: Jecs.Entity, Plot_Model: Model in Plots_Without_Owner:iter() do
        if Plot_Model:HasTag("Cleaned") then
            continue
        end

        local OwnerSign = Plot_Model:FindFirstChild("OwnerSign")
        local Title: TextLabel, Avatar: ImageLabel =
            OwnerSign:FindFirstChild("Title", true), OwnerSign:FindFirstChild("Avatar", true)

        Title.Text = ""
        Title.Visible = false

        Avatar.Image = ""
        Avatar.Visible = false

        Plot_Model:AddTag("Cleaned")
    end
end

local Players_Without_Plot = World:query(Components.Player, Components.Renderable)
    :without(Pair(Components.Relationships.Plot, Jecs.Wildcard))
    :cached()

local function Assign_Plots()
    for Player_Entity, Player: Player, Character: Model in Players_Without_Plot:iter() do
        for Plot_Number = 1, 6 do
            local Plot_Entity = Registry.Get("Plots", Plot_Number)

            if World:target(Plot_Entity, Components.Relationships.Owner) ~= nil then
                continue
            end

            local Plot_Model = World:get(Plot_Entity, Components.Renderable) :: Model

            Plot_Model:RemoveTag("Cleaned")

            task.spawn(function()
                local OwnerSign = Plot_Model:FindFirstChild("OwnerSign")
                local Title: TextLabel, Avatar: ImageLabel =
                    OwnerSign:FindFirstChild("Title", true), OwnerSign:FindFirstChild("Avatar", true)

                local Info = Util.Get_Player_Info(Player.UserId)

                Title.Text = Info.Name .. "'s Plot"
                Avatar.Image = Info.Image

                Title.Visible = true
                Avatar.Visible = true
            end)

            local Spawn = Plot_Model:FindFirstChild("Spawn") :: Part
            Character:PivotTo(Spawn.CFrame)

            World:add(Player_Entity, Pair(Components.Relationships.Plot, Plot_Entity))

            World:add(Plot_Entity, Pair(Components.Relationships.Owner, Player_Entity))

            -- Network.DataChanged.Plot_Assigned.Fire(Player, Plot_Model)

            break
        end
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.PreUpdate,
    system = function()
        Cleanup_Plots()

        Assign_Plots()
    end,
}
