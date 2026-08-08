local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Start = require(ReplicatedStorage.Shared.Start)

local Systems = {}
local Systems_Folder = script.Parent:FindFirstChild("Systems")

if Systems_Folder then
    for _, ModuleScript in Systems_Folder:GetChildren() do
        if not ModuleScript:IsA("ModuleScript") then
            continue
        end

        table.insert(Systems, require(ModuleScript))
    end
end

Start(Systems)
